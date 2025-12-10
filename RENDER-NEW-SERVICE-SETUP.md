# Render New Service Setup - Exact Values

## Step-by-Step Configuration

### 1. Basic Settings

**Name:**
```
vigyanshaala-mdm-dashboard
```

**Region:**
```
Choose closest to you (e.g., Singapore, Oregon, etc.)
```

**Branch:**
```
main
```

**Root Directory:**
```
dashboard
```
⚠️ **CRITICAL:** This must be `dashboard` (not empty, not `/dashboard`)

---

### 2. Environment

**Environment:**
```
Node
```
⚠️ **NOT Docker!** Select "Node" from dropdown

---

### 3. Build & Deploy

**Build Command:**
```
npm install && npm run build
```

**Start Command:**
```
npm start
```

**Auto-Deploy:**
```
Yes
```
(Deploys automatically on every git push)

---

### 4. Environment Variables

Click "Environment" tab and add these **4 variables**:

| Key | Value |
|-----|-------|
| `VITE_SUPABASE_URL` | `your_supabase_project_url` |
| `VITE_SUPABASE_ANON_KEY` | `your_supabase_anon_key` |
| `NODE_ENV` | `production` |
| `PORT` | `3000` |

**How to get Supabase values:**
1. Go to your Supabase project dashboard
2. Settings → API
3. Copy "Project URL" → paste as `VITE_SUPABASE_URL`
4. Copy "anon public" key → paste as `VITE_SUPABASE_ANON_KEY`

---

### 5. Advanced Settings (Optional)

**Instance Type:**
```
Free (or Starter if you have paid plan)
```

**Health Check Path:**
```
Leave empty (or use `/`)
```

---

## Summary - Copy & Paste Values

```
Name: vigyanshaala-mdm-dashboard
Root Directory: dashboard
Environment: Node
Build Command: npm install && npm run build
Start Command: npm start
```

**Environment Variables:**
- `VITE_SUPABASE_URL` = (your Supabase URL)
- `VITE_SUPABASE_ANON_KEY` = (your Supabase key)
- `NODE_ENV` = production
- `PORT` = 3000

---

## After Creating Service

1. Click **"Create Web Service"**
2. Render will start building
3. Watch the build logs - you should see:
   ```
   ==> Installing dependencies
   npm install
   ==> Building application
   npm run build
   ==> Starting application
   npm start
   ```
4. Wait 2-3 minutes for build to complete
5. Your app will be live at: `https://vigyanshaala-mdm-dashboard.onrender.com`

---

## Troubleshooting

**If build fails:**
- Check Root Directory is exactly `dashboard` (no slash, no spaces)
- Verify Environment is `Node` not `Docker`
- Check build logs for specific error

**If you see Docker errors:**
- Make sure Environment is set to `Node`
- Root Directory must be `dashboard`

**If app shows blank page:**
- Check environment variables are set correctly
- Verify Supabase URL and key are correct
- Check browser console for errors

---

## Quick Checklist

- [ ] Name: `vigyanshaala-mdm-dashboard`
- [ ] Root Directory: `dashboard`
- [ ] Environment: `Node` (NOT Docker)
- [ ] Build Command: `npm install && npm run build`
- [ ] Start Command: `npm start`
- [ ] Added 4 environment variables
- [ ] Auto-Deploy: Yes

