# osquery Agent Installation

## Teacher Installation Workflow

1. Download and run the MSI installer
2. After installation, the enrollment wizard will launch automatically
3. Teacher selects their school location from the dropdown
4. Device is enrolled with the selected location_id
5. Geofencing is automatically configured for that location

## Configuration

- `osquery.conf`: osquery configuration with scheduled queries
- `enroll-fleet.ps1`: Enrollment script with location selector GUI

## Environment Variables

Set these before running enrollment:
- `FLEET_SERVER_URL`: FleetDM server URL
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key
- `TEACHER_ID`: (Optional) Teacher user ID from Supabase Auth

## MSI Packaging

Use WiX Toolset to create MSI installer that:
1. Installs osquery
2. Runs `enroll-fleet.ps1` post-install
3. Configures osquery service




