import { createClient } from '@supabase/supabase-js';

/**
 * Supabase client for BarDesk.
 *
 * The URL and anon key must come from the environment. They used to fall back
 * to hardcoded production values, which meant any build with a missing or
 * misconfigured `.env` — a developer's laptop, a preview deploy, a CI job —
 * silently connected to the live database and operated on real bar-association
 * data while appearing to run locally.
 *
 * The anon key itself is public by design and safe to ship in a bundle; RLS is
 * what protects the data. The problem was never the key's secrecy, it was the
 * silent fallback to production. Failing fast is the fix.
 */
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
// The publishable key (sb_publishable_…) replaces the legacy JWT anon key,
// which is being retired. The old variable name is still read so an existing
// .env keeps building, but it must hold the publishable key.
const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY ' +
      'in your environment (see .env.example) before building BarDesk.',
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
