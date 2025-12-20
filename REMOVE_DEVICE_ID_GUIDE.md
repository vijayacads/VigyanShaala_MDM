# Removing Device ID Column - Complete Guide

## Summary

Device ID column has been removed from:
✅ Database schema (migration created)
✅ Frontend components (AddDevice, AppInventory, DeviceMap, GeofenceAlerts)
✅ Enrollment script (enroll-device.ps1)

## Database Migration

Run this migration in Supabase SQL Editor:
```
supabase/migrations/008_remove_device_id.sql
```

**What it does:**
1. Updates child tables (geofence_alerts, software_inventory, web_activity) to use TEXT for device_id (now stores hostname)
2. Removes device ID sequence
3. Makes hostname the primary key of devices table
4. Updates all foreign key constraints to reference hostname
5. Removes the old id column

## Frontend Changes

All components now use `hostname` as the unique identifier instead of `id`:

### AddDevice.tsx
- Removed `id` from Device interface
- Changed `selectedDeviceId` to `selectedDeviceHostname`
- Update queries use `.eq('hostname', hostname)` instead of `.eq('id', id)`

### AppInventory.tsx
- Removed `id` from Device interface
- Removed `id` from SELECT queries
- Added `getRowId={(params) => params.data.hostname}` to AgGridReact

### DeviceMap.tsx
- Removed `id` from Device interface
- Removed `id` from SELECT queries
- Uses `device.hostname` as React key

### GeofenceAlerts.tsx
- Changed `device_id` type from `number` to `string` (now stores hostname)

### App.tsx
- Removed `id` from Device interface

## Enrollment Script Changes

### enroll-device.ps1
- Removed device ID from success message
- No longer displays device ID after enrollment
- Only shows hostname and inventory code

## Important Notes

⚠️ **Before running migration:**
1. Backup your database
2. Ensure all hostnames are unique (migration handles this)
3. Test on a copy first if possible

⚠️ **After migration:**
- Device identification is now by hostname
- All foreign keys in child tables now reference hostname (stored as TEXT)
- Primary key of devices table is now hostname (must be unique)

## Rollback (if needed)

If you need to rollback:
1. Restore from backup
2. Or manually recreate id column and sequence
3. Revert frontend changes

## Testing Checklist

- [ ] Run migration in Supabase
- [ ] Verify devices table has hostname as primary key
- [ ] Check that child tables have TEXT device_id referencing hostname
- [ ] Test device enrollment from installer
- [ ] Test device editing in dashboard
- [ ] Verify device appears in inventory table
- [ ] Check geofence alerts still work
- [ ] Verify map displays devices correctly




