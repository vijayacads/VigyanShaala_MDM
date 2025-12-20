# Supabase Setup Instructions

## 1. Database Tables Setup

Run these migrations in order in your Supabase SQL Editor:

1. `001_locations.sql` - Creates locations table with 5 sample locations
2. `002_devices.sql` - Creates devices and geofence_alerts tables
3. `003_software_web_activity.sql` - Creates software inventory and web activity tables
4. `004_seed_dummy_devices.sql` - Seeds 5 dummy computers with software and activity data

### Quick Setup

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run each migration file in order
4. Verify tables are created in **Table Editor**

## 2. Row Level Security (RLS)

All tables have RLS enabled. For testing, you may need to temporarily disable RLS or create test users:

### Option A: Disable RLS for Testing (Not Recommended for Production)

```sql
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE locations DISABLE ROW LEVEL SECURITY;
ALTER TABLE software_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity DISABLE ROW LEVEL SECURITY;
```

### Option B: Create Test Admin User

1. Go to **Authentication** → **Users**
2. Create a new user
3. Update user metadata:
```sql
UPDATE auth.users 
SET raw_user_meta_data = jsonb_build_object('role', 'admin')
WHERE email = 'your-test-email@example.com';
```

## 3. Get API Credentials

1. Go to **Settings** → **API**
2. Copy:
   - **Project URL** → Use as `VITE_SUPABASE_URL`
   - **anon public** key → Use as `VITE_SUPABASE_ANON_KEY`

## 4. Configure Dashboard

Create `.env` file in `dashboard/` directory:

```
VITE_SUPABASE_URL=your_project_url_here
VITE_SUPABASE_ANON_KEY=your_anon_key_here
```

## 5. Verify Data

After running migrations, check:

- **Locations**: Should have 5 locations
- **Devices**: Should have 5 devices (PC-LAB-001 to PC-LAB-005)
- **Software Inventory**: Should have software entries for each device
- **Web Activity**: Should have web activity logs

## Troubleshooting

- **RLS blocking queries**: See Option A or B above
- **Tables not found**: Verify migrations ran successfully
- **No data showing**: Check browser console for errors, verify API credentials



