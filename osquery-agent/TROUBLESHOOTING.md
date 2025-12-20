# Troubleshooting Guide

## When Stuck: Search Online for Solutions

**Always search online for solutions when encountering issues.** The osquery ecosystem is actively maintained and many issues have been solved by the community.

### Recommended Resources:
1. **Official osquery documentation**: https://osquery.readthedocs.io/
2. **osquery GitHub Issues**: https://github.com/osquery/osquery/issues
3. **FleetDM Documentation**: https://fleetdm.com/docs (for table schemas and examples)
4. **osquery Slack Community**: https://osquery.slack.com

### Common Issues and Solutions:

#### Battery Data Not Showing
- **Issue**: Battery table returns empty or doesn't exist
- **Solution**: 
  - Check osquery version: `osqueryi.exe --version`
  - Battery table requires osquery v5.12.1+ on Windows
  - If using older version, the script will automatically fallback to WMI
  - Update to latest stable version (currently 5.20.0) for best support

#### Query Syntax Errors
- **Issue**: "no such table" or "no such column" errors
- **Solution**:
  - Check table schema: `osqueryi.exe ".schema table_name"`
  - Verify column names match osquery documentation
  - Search for table-specific examples online

#### Data Not Sending to Supabase
- **Issue**: Edge function not receiving data
- **Solution**:
  - Check `send-osquery-data.ps1` debug output
  - Verify environment variables are set correctly
  - Check Supabase Edge Function logs
  - Test with manual trigger: `.\trigger-osquery-queries.ps1`

### Version Information

**Current Recommended Version**: osquery 5.20.0 (December 2025)
- Latest stable release with Windows battery table support (v5.12.1+)
- Download from: https://osquery.io/downloads

**Battery Table Support**:
- Windows: Available in osquery v5.12.1+
- macOS: Fully supported
- Linux: Limited/not available

### Best Practices

1. **Always use latest stable osquery version** for best compatibility
2. **Test queries interactively** using `osqueryi.exe` before adding to config
3. **Check table schemas** when columns don't match expectations
4. **Search GitHub issues** for similar problems before creating new issues
5. **Use WMI fallback** for battery data on older osquery versions




