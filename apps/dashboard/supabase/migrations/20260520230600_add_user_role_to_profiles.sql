-- Add user_role column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_role TEXT NOT NULL DEFAULT 'advocate';

-- Update the handle_new_user function to copy user_role from raw_user_meta_data
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id, full_name, email, mobile_number, registration_number,
    practice_state, practice_district, office_address,
    is_public_directory_enabled, subscription_tier, updated_at,
    user_role
  ) VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'mobile_number',
    new.raw_user_meta_data->>'registration_number',
    new.raw_user_meta_data->>'practice_state',
    new.raw_user_meta_data->>'practice_district',
    new.raw_user_meta_data->>'office_address',
    COALESCE((new.raw_user_meta_data->>'is_public_directory_enabled')::boolean, true),
    'free',
    now(),
    COALESCE(new.raw_user_meta_data->>'user_role', 'advocate')
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    email = EXCLUDED.email,
    mobile_number = COALESCE(EXCLUDED.mobile_number, profiles.mobile_number),
    registration_number = COALESCE(EXCLUDED.registration_number, profiles.registration_number),
    practice_state = COALESCE(EXCLUDED.practice_state, profiles.practice_state),
    practice_district = COALESCE(EXCLUDED.practice_district, profiles.practice_district),
    office_address = COALESCE(EXCLUDED.office_address, profiles.office_address),
    user_role = COALESCE(EXCLUDED.user_role, profiles.user_role),
    updated_at = now();
  RETURN new;
END;
$function$;
