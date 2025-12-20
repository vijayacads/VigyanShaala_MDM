# Scheduled Task Script to Sync Website Blocklist
# This runs periodically to keep blocklist up to date
# Logs errors to Windows Event Log for troubleshooting

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "$scriptDir\blocklist-sync.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    
    if ($Level -eq "ERROR") {
        Write-EventLog -LogName Application -Source "VigyanShaala-MDM" -EventId 1001 -EntryType Error -Message $Message -ErrorAction SilentlyContinue
    }
}

try {
    Write-Log "Starting blocklist sync..."
    
    if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
        Write-Log "ERROR: Supabase credentials not found in environment variables" "ERROR"
        exit 1
    }
    
    # Run the apply script
    & "$scriptDir\apply-website-blocklist.ps1" -SupabaseUrl $SupabaseUrl -SupabaseAnonKey $SupabaseAnonKey
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Blocklist sync completed successfully"
    } else {
        Write-Log "Blocklist sync failed with exit code: $LASTEXITCODE" "ERROR"
        exit $LASTEXITCODE
    }
} catch {
    Write-Log "Blocklist sync error: $_" "ERROR"
    exit 1
}
