-- ============================================================
-- Migration: Add Profile Photo Support
-- Date: 2026-06-12
-- Description: Adds avatar_url to profiles and creates
--              profile-photos storage bucket with RLS.
-- ============================================================

-- 1. Add avatar_url column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Create the storage bucket for profile photos (public access for reading)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  2097152, -- 2MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 3. RLS Policies for profile-photos bucket

-- Anyone can view profile photos (for directory, chat avatars, etc.)
CREATE POLICY "Public read access for profile photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

-- Users can only upload to their own folder: profile-photos/{user_id}/
CREATE POLICY "Users can upload their own profile photo"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'profile-photos'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Users can update (overwrite) their own photos
CREATE POLICY "Users can update their own profile photo"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'profile-photos'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Users can delete their own photos
CREATE POLICY "Users can delete their own profile photo"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'profile-photos'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
