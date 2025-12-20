# Device Installation Instructions for Teachers

## Quick Start

1. **Download the installer package** (ZIP file) from the dashboard
2. **Extract** all files to a folder on your computer
3. **Edit** `INSTALL.bat` and add your Supabase credentials:
   - Replace `YOUR_PROJECT` with your Supabase project name
   - Replace `YOUR_ANON_KEY_HERE` with your Supabase anon key
4. **Right-click** on `INSTALL.bat` and select **"Run as Administrator"**
5. **Follow the prompts**:
   - The installer will download and install osquery (if needed)
   - A form will appear asking for device information
   - Fill in all required fields (marked with *)
   - Click "Register Device"
6. **Done!** Your device will appear in the dashboard

## Required Information

When the enrollment form appears, you'll need to provide:

- **Device Inventory Code** * (e.g., INV-001, LAPTOP-01)
- **Device Name/Hostname** * (auto-filled, can edit)
- **Serial Number** (auto-filled, can edit)
- **Host Location** * (e.g., "Computer Lab", "Classroom 101")
- **City/Town/Village** (e.g., "Pune", "Mumbai")
- **Laptop Model** (auto-filled, can edit)
- **OS Version** (auto-filled, can edit)
- **Latitude** * (e.g., 18.5204 - use Google Maps to find)
- **Longitude** * (e.g., 73.8567 - use Google Maps to find)
- **School Location** * (select from dropdown)

## Finding Latitude and Longitude

1. Open Google Maps in your browser
2. Search for your school location
3. Right-click on the location on the map
4. The first number is Latitude, second is Longitude
5. Copy these numbers into the form

Example:
- If you see: `18.5204, 73.8567`
- Latitude: `18.5204`
- Longitude: `73.8567`

## Troubleshooting

### "osquery MSI not found"
- The installer will try to download it automatically
- If that fails, download manually from: https://osquery.io/downloads
- Save as `osquery-5.11.0.msi` in the installer folder

### "Configuration error: Supabase credentials not found"
- Edit `INSTALL.bat` and ensure SUPABASE_URL and SUPABASE_KEY are set correctly
- Make sure there are no extra spaces

### "Failed to load locations"
- Check your internet connection
- Verify Supabase credentials are correct
- Contact administrator if problem persists

### "Enrollment failed"
- Check your internet connection
- Verify all required fields are filled
- Ensure coordinates are valid numbers
- Contact administrator if problem persists

## Support

For issues or questions, contact your system administrator.




