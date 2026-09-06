// Supabase Edge Function: pdf-proxy
// Proxies iLovePDF API calls to keep the secret key server-side.
//
// Deploy: supabase functions deploy pdf-proxy
// Set secrets:
//   supabase secrets set ILOVEPDF_PUBLIC_KEY=your_public_key
//   supabase secrets set ILOVEPDF_SECRET_KEY=your_secret_key
//
// Supports: compress, merge, split, watermark, officetopdf, imagetopdf

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ILOVEPDF_PUBLIC_KEY = Deno.env.get("ILOVEPDF_PUBLIC_KEY")!;
const ILOVEPDF_SECRET_KEY = Deno.env.get("ILOVEPDF_SECRET_KEY")!;

/**
 * Hosts the `forward` action is permitted to reach.
 *
 * iLovePDF hands back a per-task worker hostname (api7g.ilovepdf.com and
 * friends), so the whole zone has to be allowed rather than a single host.
 */
const ALLOWED_FORWARD_HOST_SUFFIX = ".ilovepdf.com";
const ALLOWED_FORWARD_HOST = "ilovepdf.com";

/**
 * True only for an https URL inside the iLovePDF zone.
 *
 * Without this the `forward` action is a server-side request forgery
 * primitive: it fetches whatever URL the caller supplies and returns the
 * response body, which would let any signed-in user reach cloud metadata
 * endpoints and other services routable from the edge runtime.
 */
function isAllowedForwardTarget(rawUrl: unknown): boolean {
  if (typeof rawUrl !== "string" || rawUrl.length === 0) return false;

  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return false;
  }

  if (parsed.protocol !== "https:") return false;

  const host = parsed.hostname.toLowerCase();
  return host === ALLOWED_FORWARD_HOST || host.endsWith(ALLOWED_FORWARD_HOST_SUFFIX);
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify authentication
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { action } = body; // 'start', 'upload', 'process', 'download'

    if (!action) {
      return new Response(
        JSON.stringify({ error: "Missing 'action' parameter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 1: Start a task
    if (action === "start") {
      const { tool } = body; // 'compress', 'merge', 'officetopdf', etc.
      const authResponse = await fetch("https://api.ilovepdf.com/v1/auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          public_key: ILOVEPDF_PUBLIC_KEY,
          secret_key: ILOVEPDF_SECRET_KEY,
        }),
      });

      if (!authResponse.ok) {
        return new Response(
          JSON.stringify({ error: "iLovePDF authentication failed" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { token } = await authResponse.json();

      // Start task
      const startResponse = await fetch(`https://api.ilovepdf.com/v1/start/${tool}`, {
        method: "GET",
        headers: { Authorization: `Bearer ${token}` },
      });

      const startData = await startResponse.json();

      return new Response(
        JSON.stringify({ token, ...startData }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 2: Forward upload/process/download with the provided token
    if (action === "forward") {
      const { token, url, method, payload } = body;

      if (!isAllowedForwardTarget(url)) {
        console.error(`pdf-proxy: blocked forward to disallowed target: ${url}`);
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "The forward action may only target https://*.ilovepdf.com.",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const fetchOptions: RequestInit = {
        method: method || "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      };

      if (payload) {
        fetchOptions.body = JSON.stringify(payload);
      }

      const response = await fetch(url, fetchOptions);

      // Check if response is a file (PDF download)
      const contentType = response.headers.get("content-type") || "";
      if (contentType.includes("application/pdf") || contentType.includes("octet-stream")) {
        const fileData = await response.arrayBuffer();
        return new Response(fileData, {
          headers: {
            ...corsHeaders,
            "Content-Type": contentType,
            "Content-Disposition": response.headers.get("content-disposition") || "attachment",
          },
        });
      }

      const data = await response.json();
      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", (error as any).message);
    return new Response(
      JSON.stringify({ error: (error as any).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
