# Battery Data Note

## Current Status

**Battery data is missing due to osquery version:**
- Current version: osquery 5.11.0
- Battery table requires: osquery 5.12.1+
- WMI fallback: Working, but data may not be in recent log entries

## Solution

The WMI fallback in `trigger-osquery-queries.ps1` writes battery data to the log, but:
1. It may be outside the last 100-200 lines that `send-osquery-data.ps1` reads
2. The scheduled task runs osquery queries, not the trigger script

## Options

### Option 1: Upgrade osquery (Recommended)
- Upgrade to osquery 5.20.0 (latest stable)
- Battery table will work natively
- No WMI fallback needed

### Option 2: Increase log reading window
- Already increased from 100 to 200 lines
- May need to increase further if log is very large

### Option 3: Add battery query to osquery.conf
- Add a scheduled query that uses WMI via osquery's `powershell_events` table
- More complex but ensures battery data is in osquery log

## Current Workaround

Battery data will be `null` in the database until:
1. osquery is upgraded to 5.12.1+, OR
2. WMI battery data is captured in the log reading window

The system will still work - battery will just show as `null` in the dashboard.




