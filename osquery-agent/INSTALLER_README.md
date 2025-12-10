# OSQuery Agent Installer

This directory contains the software that needs to be installed on every computer (Windows laptop) to enable MDM monitoring.

## Components

1. **osquery**: Core agent that collects system information
2. **osquery.conf**: Configuration file with scheduled queries
3. **enroll-fleet.ps1**: Enrollment script with location selector
4. **install-osquery.ps1**: Installation automation script
5. **prevent-uninstall.ps1**: Security script to prevent unauthorized removal

## Installation Methods

### Method 1: Automated Installation Script (Recommended)

**Prerequisites:**
- Windows PowerShell (Run as Administrator)
- Download osquery MSI from https://osquery.io/downloads (or use the download script)

**Steps:**

1. Download osquery MSI:
   ```powershell
   # Place osquery-5.11.0.msi in this directory
   ```

2. Configure environment variables in `install-osquery.ps1` or pass as parameters:
   ```powershell
   .\install-osquery.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseKey "xxx" -FleetUrl "https://fleet.example.com"
   ```

3. Run installation:
   ```powershell
   .\install-osquery.ps1
   ```

### Method 2: Manual Installation

1. **Install osquery:**
   - Download osquery MSI from https://osquery.io/downloads
   - Run the MSI installer
   - Default installation path: `C:\Program Files\osquery`

2. **Copy configuration:**
   ```powershell
   Copy-Item osquery.conf "C:\Program Files\osquery\osquery.conf" -Force
   ```

3. **Set environment variables:**
   ```powershell
   [Environment]::SetEnvironmentVariable("SUPABASE_URL", "https://xxx.supabase.co", "Machine")
   [Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", "xxx", "Machine")
   [Environment]::SetEnvironmentVariable("FLEET_SERVER_URL", "https://fleet.example.com", "Machine")
   ```

4. **Run enrollment:**
   ```powershell
   .\enroll-fleet.ps1
   ```

5. **Start osquery service:**
   ```powershell
   Start-Service osqueryd
   ```

### Method 3: MSI Package (Advanced)

For enterprise deployment, create an MSI package using WiX Toolset:

1. Use `installer-setup.ps1` to prepare files
2. Create WiX project that:
   - Installs osquery MSI
   - Copies configuration files
   - Sets environment variables
   - Runs enrollment script post-install
   - Installs osqueryd service

## Configuration

### Environment Variables Required

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key
- `FLEET_SERVER_URL`: (Optional) FleetDM server URL if using Fleet

### Enrollment Flow

1. Teacher runs installer (or it auto-launches after installation)
2. Location selector GUI appears
3. Teacher selects their school location
4. Device is registered in Supabase with `location_id`
5. Geofencing is automatically configured

## Post-Installation

### Verify Installation

```powershell
# Check service status
Get-Service osqueryd

# Check logs
Get-Content "C:\Program Files\osquery\log\osqueryd.results.log" -Tail 50

# Test query
& "C:\Program Files\osquery\osqueryi.exe" --line "SELECT * FROM system_info;"
```

### Security

- `prevent-uninstall.ps1` can be configured to prevent users from uninstalling
- Run as scheduled task or via Group Policy
- Blocks uninstaller execution

## Troubleshooting

**Service won't start:**
- Check Windows Event Viewer for errors
- Verify osquery.conf syntax
- Ensure file paths in config are correct

**Enrollment fails:**
- Verify environment variables are set (Machine level)
- Check network connectivity to Supabase
- Verify Supabase URL and API key are correct

**Location selector doesn't appear:**
- Ensure Supabase connection is working
- Check that locations table has active entries
- Run enroll-fleet.ps1 manually to see error messages

## File Locations

After installation:
- **Binary**: `C:\Program Files\osquery\osqueryd.exe`
- **Config**: `C:\Program Files\osquery\osquery.conf`
- **Logs**: `C:\Program Files\osquery\log\`
- **Enrollment script**: `C:\Program Files\osquery\enroll-fleet.ps1`

## Next Steps

1. Test installation on a single device
2. Verify device appears in dashboard
3. Test location-based filtering
4. Create MSI package for mass deployment
5. Set up Group Policy for automatic deployment
