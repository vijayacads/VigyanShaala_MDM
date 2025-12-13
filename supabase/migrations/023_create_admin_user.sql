-- Migration 023: Create admin user for dashboard login
-- Username: Digital_Delivery
-- Password: VS_Digital_Delivery

-- IMPORTANT: This script should be run in Supabase SQL Editor
-- Supabase Auth requires email format, so we'll use: Digital_Delivery@vigyanshaala.org
-- The login page will accept "Digital_Delivery" as username and match it to this email

-- Method 1: Using Supabase Dashboard (EASIEST - Recommended)
-- 1. Go to Supabase Dashboard > Authentication > Users
-- 2. Click "Add User" > "Create new user"
-- 3. Email: Digital_Delivery@vigyanshaala.org
-- 4. Password: VS_Digital_Delivery
-- 5. Check "Auto Confirm User"
-- 6. Click "Create User"
-- 7. Then run the UPDATE query below to set admin role

-- Method 2: Using SQL (requires service_role or admin access)
-- Note: Direct INSERT into auth.users requires elevated privileges
-- The following uses Supabase's auth extension functions

-- Create user using auth.users table (if you have service_role access)
DO $$
DECLARE
  user_id uuid;
BEGIN
  -- Generate a UUID for the user
  user_id := gen_random_uuid();
  
  -- Insert into auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    user_id,
    'authenticated',
    'authenticated',
    'Digital_Delivery@vigyanshaala.org',
    crypt('VS_Digital_Delivery', gen_salt('bf')),
    NOW(),
    NOW(),
    NULL,
    '{"provider":"email","providers":["email"]}',
    '{"role":"admin"}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  ) ON CONFLICT (email) DO UPDATE
  SET raw_user_meta_data = '{"role":"admin"}'::jsonb,
      updated_at = NOW();
END $$;

-- Set admin role in user metadata (run this after creating user via Dashboard or SQL)
UPDATE auth.users 
SET raw_user_meta_data = jsonb_build_object('role', 'admin')
WHERE email = 'Digital_Delivery@vigyanshaala.org';

-- Verify the user was created
SELECT 
  id, 
  email, 
  raw_user_meta_data->>'role' as role,
  email_confirmed_at,
  created_at 
FROM auth.users 
WHERE email = 'Digital_Delivery@vigyanshaala.org';

