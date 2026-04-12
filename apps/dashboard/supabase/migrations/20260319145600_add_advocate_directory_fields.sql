-- Migration: Add National Advocate Directory fields to profiles table

-- Add new professional fields
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS mobile_number TEXT,
ADD COLUMN IF NOT EXISTS registration_number TEXT,
ADD COLUMN IF NOT EXISTS practice_state TEXT,
ADD COLUMN IF NOT EXISTS practice_district TEXT,
ADD COLUMN IF NOT EXISTS office_address TEXT,
ADD COLUMN IF NOT EXISTS is_public_directory_enabled BOOLEAN DEFAULT true;

-- Update RLS policies (We already have "Users can update own profile" from the initial setup, 
-- but let's ensure the new fields are covered. Since the existing policy is just FOR UPDATE USING (auth.uid() = id), 
-- it automatically applies to all new columns. No new policies needed for update!)

-- However, for the directory to work, ALL users need to be able to SELECT profiles
-- where is_public_directory_enabled = true.
-- Currently, the policy is "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
-- This means users can't see EACH OTHER. We MUST add a policy to allow viewing public profiles.

DROP POLICY IF EXISTS "Anyone can view public profiles" ON public.profiles;

CREATE POLICY "Anyone can view public profiles" 
ON public.profiles 
FOR SELECT 
USING (
  auth.uid() = id OR is_public_directory_enabled = true
);
