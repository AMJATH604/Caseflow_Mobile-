import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.600.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.600.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID") || "";
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID") || "";
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY") || "";
const R2_BUCKET_NAME = Deno.env.get("R2_BUCKET_NAME") || "caseflow-storage";

// ─── Authorization model ────────────────────────────────────────────
//
// R2 has no RLS, so this function is the ONLY access-control boundary for
// the bucket. Authenticating the caller is not enough: without an ownership
// check, any logged-in user can pass any key and get a signed URL for
// another advocate's case documents.
//
// Reads and deletes are authorized by *ownership lookup*, not by key shape:
// we ask the database, through an RLS-scoped client carrying the caller's
// own JWT, whether a row referencing this object is visible to them. That
// deliberately also covers the legacy flat keys (`legal-documents/<ts>_<name>`)
// that predate namespacing, so no stored object has to be migrated.
//
// Uploads are constrained by key shape instead, because there is no row to
// look up yet — a new private object must land under the caller's own prefix.
//
// NOTE: the read/delete path inherits its strength from RLS on `documents`.
// If RLS there is missing or looser than intended, this check weakens with
// it. Confirming server-side RLS on the live schema is tracked separately.

/** Object prefixes holding shared reference content every advocate may read. */
const PUBLIC_READ_PREFIXES = ["bare_acts/", "legal_templates/"];

/** Private user content lives here, namespaced per user. */
const PRIVATE_PREFIX = "legal-documents";

function isPublicReadKey(key: string): boolean {
  return PUBLIC_READ_PREFIXES.some((prefix) => key.startsWith(prefix));
}

/**
 * Rejects keys that could escape their intended prefix.
 *
 * A signed URL is minted for whatever key we hand the S3 client, so a key
 * containing `..` or a leading slash must never reach it.
 */
function isWellFormedKey(key: string): boolean {
  if (typeof key !== "string") return false;
  if (key.length === 0 || key.length > 1024) return false;
  if (key.startsWith("/") || key.includes("//")) return false;
  if (key.split("/").some((seg) => seg === "." || seg === "..")) return false;
  // Control characters and backslashes have no place in an object key.
  // deno-lint-ignore no-control-regex
  if (/[\x00-\x1F\x7F\\]/.test(key)) return false;
  return true;
}

function forbidden(message: string): Response {
  return new Response(JSON.stringify({ error: "Forbidden", message }), {
    status: 403,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * True when a row referencing this object is visible to the calling user.
 *
 * `supabase` must be a client carrying the caller's JWT so RLS applies —
 * passing a service-role client here would defeat the entire check.
 */
/**
 * True when the caller holds the `admin` role.
 *
 * Shared reference libraries (statutes, templates) are app-wide content, so
 * they are managed by administrators rather than by whoever is logged in —
 * otherwise any user could overwrite a statute PDF that every advocate then
 * downloads and relies on.
 *
 * Fails closed. If `has_role` is missing or the query errors, nobody is
 * treated as an admin, so a misconfigured deployment refuses library writes
 * instead of silently accepting them.
 */
async function callerIsAdmin(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
): Promise<boolean> {
  const { data, error } = await supabase.rpc("has_role", {
    _user_id: userId,
    _role: "admin",
  });

  if (error) {
    console.error("r2-storage: has_role check failed:", error.message);
    return false;
  }
  return data === true;
}

async function callerCanReachObject(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  key: string,
): Promise<boolean> {
  const ref = `r2://${key}`;

  // Case documents: `documents.file_url` stores the `r2://` reference.
  const { data: doc, error: docErr } = await supabase
    .from("documents")
    .select("id")
    .eq("file_url", ref)
    .limit(1);

  if (docErr) {
    console.error("r2-storage: ownership lookup failed:", docErr.message);
    return false;
  }
  return Array.isArray(doc) && doc.length > 0;
}

function getR2Client() {
  if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
    throw new Error("Cloudflare R2 credentials (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY) are not configured.");
  }

  return new S3Client({
    region: "auto",
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY_ID,
      secretAccessKey: R2_SECRET_ACCESS_KEY,
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    
    // Auth Check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized user" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { action, key, contentType } = body;

    if (!key) {
      return new Response(JSON.stringify({ error: "Object key is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!isWellFormedKey(key)) {
      return new Response(
        JSON.stringify({ error: "Invalid object key" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Authorization ────────────────────────────────────────────────
    // Being logged in is not authorization. Every action below must first
    // establish that this specific object is the caller's to touch.
    const publicRead = isPublicReadKey(key);

    if (action === "get-upload-url") {
      if (publicRead) {
        // Shared libraries are app-wide content: administrators publish them.
        if (!(await callerIsAdmin(supabase, user.id))) {
          return forbidden(
            "Only administrators may publish shared reference content.",
          );
        }
      } else {
        // No row exists yet to prove ownership of a not-yet-uploaded object,
        // so the key shape carries it: a private upload must land under the
        // caller's own prefix, which is what stops one user overwriting
        // another's document by guessing its key.
        const requiredPrefix = `${PRIVATE_PREFIX}/${user.id}/`;
        if (!key.startsWith(requiredPrefix)) {
          return forbidden(
            `Uploads must be namespaced under "${requiredPrefix}".`,
          );
        }
      }
    } else if (action === "get-download-url") {
      // Shared libraries are readable by any authenticated user; anything
      // else must be provably reachable by this caller under RLS.
      if (!publicRead && !(await callerCanReachObject(supabase, key))) {
        return forbidden("You do not have access to this object.");
      }
    } else if (action === "delete-object") {
      // Deletion is irreversible, so it takes the same permission as
      // publishing: admins curate the shared libraries, everyone else may
      // only remove objects the database says are theirs.
      if (publicRead) {
        if (!(await callerIsAdmin(supabase, user.id))) {
          return forbidden(
            "Only administrators may delete shared reference content.",
          );
        }
      } else if (!(await callerCanReachObject(supabase, key))) {
        return forbidden("You do not have access to this object.");
      }
    }

    const s3Client = getR2Client();

    if (action === "get-upload-url") {
      const command = new PutObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: key,
        ContentType: contentType || "application/octet-stream",
      });
      const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
      return new Response(JSON.stringify({ uploadUrl, key, bucket: R2_BUCKET_NAME }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else if (action === "get-download-url") {
      const command = new GetObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: key,
      });
      const downloadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
      return new Response(JSON.stringify({ downloadUrl, key }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else if (action === "delete-object") {
      const command = new DeleteObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: key,
      });
      await s3Client.send(command);
      return new Response(JSON.stringify({ success: true, key }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else {
      return new Response(JSON.stringify({ error: `Invalid action: ${action}` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (err: any) {
    console.error("r2-storage edge function error:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
