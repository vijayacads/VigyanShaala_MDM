# Device Control Local Testing

Quick test scripts to test device control features locally without waiting for scheduled tasks.

## Quick Test (Recommended)

```powershell
cd test-device-control
.\quick-test.ps1
```

This will:
1. Create a `clear_cache` command
2. Immediately run the command processor
3. Show the result

## Test Different Commands

```powershell
# Test Clear Cache (safe)
.\quick-test.ps1 -CommandType "clear_cache"

# Test Buzz (you'll hear beeps)
.\quick-test.ps1 -CommandType "buzz"

# Test Lock (will lock your screen!)
.\test-lock.ps1
```

## Custom Test

```powershell
.\quick-test.ps1 -CommandType "buzz" -DeviceHostname "YOUR-PC-NAME"
```

## What to Check

- ✓ Command created successfully
- ✓ Script executed without errors
- ✓ Status changed to "completed" or "failed"
- ✓ If failed, check error message

## Troubleshooting

If command stays "pending":
- Check if execute-commands.ps1 exists at `C:\Program Files\osquery\`
- Check if script has correct Supabase credentials
- Check RLS policies allow anon access to device_commands table

