-- Migration 023: Create admin user for dashboard login
-- Username: Digital_Delivery
-- Password: VS_Digital_Delivery
-- Email: Digital_Delivery@vigyanshaala.org

-- RECOMMENDED METHOD: Use Supabase Dashboard
-- 1. Go to Supabase Dashboard > Authentication > Users
-- 2. Click "Add User" > "Create new user"
-- 3. Email: Digital_Delivery@vigyanshaala.org
-- 4. Password: VS_Digital_Delivery
-- 5. Check "Auto Confirm User"
-- 6. Click "Create User"
-- 7. Then run the UPDATE query below to set admin role

-- Set admin role in user metadata (run this after creating user via Dashboard)
UPDATE auth.users 
SET raw_user_meta_data = jsonb_build_object('role', 'admin')
WHERE email = 'Digital_Delivery@vigyanshaala.org';

-- Verify the user exists and has admin role
SELECT 
  id, 
  email, 
  raw_user_meta_data->>'role' as role,
  email_confirmed_at,
  created_at 
FROM auth.users 
WHERE email = 'Digital_Delivery@vigyanshaala.org';




