import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";
import { env } from "./env";

/**
 * The one Supabase client for the web app — same project, same RLS, same
 * data as the mobile app. Typed from the live schema
 * (`supabase gen types typescript`), so a renamed column is a compile error
 * here rather than a blank screen in production.
 */
export const supabase = createClient<Database>(env.supabaseUrl, env.supabaseKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true, // password-reset links land with a session in the URL
  },
});

export type Tables<T extends keyof Database["public"]["Tables"]> = Database["public"]["Tables"][T]["Row"];
