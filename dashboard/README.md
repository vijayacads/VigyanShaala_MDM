# MDM Dashboard

React dashboard for VigyanShaala MDM system with multi-location support.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file with Supabase credentials:
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. Run development server:
```bash
npm run dev
```

## Features

- Location-based filtering (100+ locations)
- Real-time device map with geofence visualization
- Device inventory table (AG Grid)
- Geofence alerts management
- Real-time updates via Supabase subscriptions

## Deployment

Build for production:
```bash
npm run build
```

Deploy to Vercel or similar platform.




