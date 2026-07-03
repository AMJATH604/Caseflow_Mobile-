-- Add last_seen_at column to profiles for tracking user online status
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT now();

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at ON profiles(last_seen_at);

-- Update RLS policy to allow users to update their own last_seen_at
-- (the existing update policy should already cover this since it allows
--  users to update their own profile row)
