# Running Dashboard Locally for Quick Verification

## Quick Start (Development Mode)

1. **Navigate to dashboard folder:**
   ```bash
   cd dashboard
   ```

2. **Install dependencies (if not already done):**
   ```bash
   npm install
   ```

3. **Start development server:**
   ```bash
   npm run dev
   ```

4. **Open browser:**
   - The app will be available at `http://localhost:3000`
   - Changes will hot-reload automatically

## Development vs Production Build

### Development Mode (`npm run dev`)
- ✅ Fast startup
- ✅ Hot module replacement (instant updates)
- ✅ Source maps for debugging
- ✅ No minification (easier to debug)
- ⚠️ Slower runtime performance
- ⚠️ Larger bundle size

**Use this for:**
- Quick verification of changes
- Testing UI/UX
- Debugging issues
- Development work

### Production Build (`npm run build`)
- ✅ Optimized and minified
- ✅ Smaller bundle size
- ✅ Better performance
- ⚠️ Takes longer to build
- ⚠️ No hot reload

**Use this for:**
- Final testing before deployment
- Verifying production build works
- Performance testing

## Preview Production Build Locally

After running `npm run build`, you can preview the production build:

```bash
npm run preview
```

This serves the built files from `dist/` folder at `http://localhost:4173`

## Troubleshooting Build Errors

If you get CSS import errors:
- Make sure `@import` statements are at the very top of CSS files
- Check that all CSS variable references are correct
- Verify branding.css is imported before it's used

## Environment Variables

Make sure you have your Supabase credentials configured:
- Check `dashboard/supabase.config.ts`
- Or set environment variables:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_ANON_KEY`




