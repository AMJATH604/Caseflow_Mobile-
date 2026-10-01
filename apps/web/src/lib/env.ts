// Connection settings. Both values are public by design: the publishable key
// is protected by row-level security, exactly as on the mobile app.
//
// An empty variable is treated as absent. The mobile app learned this the
// hard way — a CI build given a blank key shipped with no key at all and
// every request came back 401 (see apps/mobile/lib/utils/env_config.dart).

const PROD_URL = "https://asrjqsnyezvcakvkokcl.supabase.co";
const PROD_PUBLISHABLE_KEY = "sb_publishable_g8UbCM_UoYqvLn8DbGIBCA_QGG3U9nT";

const nonEmpty = (v: string | undefined) => (v && v.trim() !== "" ? v.trim() : undefined);

export const env = {
  supabaseUrl: nonEmpty(import.meta.env.VITE_SUPABASE_URL) ?? PROD_URL,
  supabaseKey: nonEmpty(import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY) ?? PROD_PUBLISHABLE_KEY,
} as const;
