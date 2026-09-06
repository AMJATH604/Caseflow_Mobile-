-- App Configuration table for force update and remote config
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Set minimum required version
INSERT INTO app_config (key, value) VALUES ('min_version', '2.1.0')
ON CONFLICT (key) DO NOTHING;

-- Play Store URL for update redirect
INSERT INTO app_config (key, value) VALUES ('play_store_url', 'https://play.google.com/store/apps/details?id=com.caseflow.app')
ON CONFLICT (key) DO NOTHING;

-- Allow public read access (no auth needed for version check)
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to app_config"
  ON app_config FOR SELECT
  USING (true);
