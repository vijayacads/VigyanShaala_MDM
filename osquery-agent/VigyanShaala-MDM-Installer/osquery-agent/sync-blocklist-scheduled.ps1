# Scheduled Task Script to Sync Website Blocklist
# This runs periodically to keep blocklist up to date

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run the apply script
& "$scriptDir\apply-website-blocklist.ps1" -SupabaseUrl $SupabaseUrl -SupabaseAnonKey $SupabaseAnonKey

