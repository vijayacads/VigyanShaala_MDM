# VigyanShaala MDM

Complete MDM solution for 10,000+ devices across 100+ locations using FleetDM + osquery + Supabase.

## Architecture

- **FleetDM**: Device management server (osquery orchestration)
- **osquery**: Agent installed on Windows laptops
- **Supabase**: Database, Edge Functions, Realtime
- **React Dashboard**: Admin interface with location-based filtering

## Quick Start

### 1. Database Setup

Run migrations in Supabase:
```bash
supabase migration up
```

Or manually run:
- `supabase/migrations/001_locations.sql`
- `supabase/migrations/002_devices.sql`
- `supabase/migrations/003_software_web_activity.sql`

### 2. Edge Functions

Deploy to Supabase:
```bash
supabase functions deploy geofence-alert
supabase functions deploy fetch-osquery-data
```

### 3. osquery Agent

1. Build MSI installer with `osquery-agent/enroll-fleet.ps1`
2. Teachers run MSI and select location from dropdown
3. Device enrolled with location_id

### 4. Dashboard

```bash
cd dashboard
npm install
cp .env.example .env
# Add Supabase credentials
npm run dev
```

## Key Features

- **Multi-Location Support**: 100+ locations with individual geofences
- **Teacher Installation**: GUI-based location selection during enrollment
- **Location-Based Geofencing**: Each device checked against its assigned location
- **Real-Time Dashboard**: Live updates via Supabase Realtime
- **RLS Security**: Teachers see only their location's devices

## Project Structure

```
├── supabase/
│   ├── migrations/          # Database schema
│   └── functions/          # Edge Functions
├── osquery-agent/          # Enrollment scripts
└── dashboard/              # React admin panel
```

## Geofencing Logic

1. Device enrolled with `location_id`
2. osquery sends GPS every 5 minutes
3. Edge Function checks distance to location center
4. Alert created if outside `radius_meters`
5. Dashboard shows violations in real-time
