# Render Deployment Guide

## Option 1: Web Service (Recommended)

1. Go to Render Dashboard → New → Web Service
2. Connect your GitHub repository: `vijayacads/VigyanShaala_MDM`
3. Configure:
   - **Name**: `vigyanshaala-mdm-dashboard`
   - **Root Directory**: `dashboard`
   - **Environment**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`
   - **Port**: `3000` (auto-detected)

4. Add Environment Variables:
   - `VITE_SUPABASE_URL` - Your Supabase project URL
   - `VITE_SUPABASE_ANON_KEY` - Your Supabase anonymous key
   - `NODE_ENV` - `production`
   - `PORT` - `3000`

5. Click "Create Web Service"

## Option 2: Static Site (Simpler, but no server-side routing)

1. Go to Render Dashboard → New → Static Site
2. Connect your GitHub repository
3. Configure:
   - **Name**: `vigyanshaala-mdm-dashboard`
   - **Root Directory**: `dashboard`
   - **Build Command**: `npm install && npm run build`
   - **Publish Directory**: `dist`

4. Add Environment Variables (for build-time):
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`

Note: Static sites don't support server-side routing. Use Option 1 if you need that.

## Option 3: Using Dockerfile

If you prefer Docker:

1. Go to Render Dashboard → New → Web Service
2. Connect repository
3. Render will auto-detect the Dockerfile in `dashboard/` directory
4. Add environment variables as above

## Troubleshooting

- **Build fails**: Check that all dependencies are in `package.json`
- **Blank page**: Verify environment variables are set correctly
- **404 on refresh**: Use Web Service (Option 1) instead of Static Site




