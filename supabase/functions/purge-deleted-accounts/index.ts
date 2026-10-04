// Supabase Edge Function: purge-deleted-accounts
//
// Runs daily from pg_cron (02:30 IST, migration 20261007_account_deletion).
// Deletes every account whose 30-day grace period is over:
//
//   1. lists the account's files (public.account_deletion_files),
//   2. runs public.purge_account — one transaction that hands records made
//      inside another advocate's firm back to that firm, deletes the user's
//      own data and finally the login,
//   3. then removes the files through the Storage API. Files go last so a
//      failed purge never leaves rows pointing at missing documents; a failed
//      file removal only leaves orphaned objects, which are logged.
//
// Deploy with verify_jwt false: pg_net sends no Authorization header, and
// verifyWebhookAuth (fails closed) is the gate.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { requireSecretKey } from "../_shared/keys.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, requireSecretKey(), {
    auth: { persistSession: false },
  });

  const { data: due, error: dueError } = await supabase.rpc("accounts_due_for_deletion");
  if (dueError) {
    console.error("[purge] could not list accounts:", dueError.message);
    return json({ error: dueError.message }, 500);
  }

  const results: { user: string; result: string; files?: number; fileErrors?: number }[] = [];

  for (const userId of (due ?? []) as string[]) {
    try {
      const { data: files, error: filesError } = await supabase.rpc("account_deletion_files", { p_user: userId });
      if (filesError) throw new Error(`files: ${filesError.message}`);

      const { data: outcome, error: purgeError } = await supabase.rpc("purge_account", { p_user: userId });
      if (purgeError) throw new Error(`purge: ${purgeError.message}`);
      if (outcome !== "deleted") {
        results.push({ user: userId, result: String(outcome) });
        continue;
      }

      // Group by bucket; the Storage API removes up to 1,000 paths per call.
      const byBucket = new Map<string, string[]>();
      for (const f of (files ?? []) as { bucket: string; path: string }[]) {
        byBucket.set(f.bucket, [...(byBucket.get(f.bucket) ?? []), f.path]);
      }
      let removed = 0;
      let fileErrors = 0;
      for (const [bucket, paths] of byBucket) {
        for (let i = 0; i < paths.length; i += 1000) {
          const chunk = paths.slice(i, i + 1000);
          const { error } = await supabase.storage.from(bucket).remove(chunk);
          if (error) {
            fileErrors += chunk.length;
            console.error(`[purge] ${userId}: could not remove ${chunk.length} file(s) from ${bucket}:`, error.message);
          } else {
            removed += chunk.length;
          }
        }
      }
      results.push({ user: userId, result: "deleted", files: removed, fileErrors });
    } catch (e) {
      console.error(`[purge] ${userId}:`, e instanceof Error ? e.message : e);
      results.push({ user: userId, result: "error" });
    }
  }

  console.log("[purge] done", JSON.stringify(results));
  return json({ processed: results.length, results });
});
