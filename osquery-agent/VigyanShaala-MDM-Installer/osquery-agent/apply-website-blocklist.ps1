# Apply Website Blocklist to Chrome via Windows Registry
# This script fetches the blocklist from Supabase and applies Chrome policies

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges to modify registry"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Error "Supabase credentials not found. Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables."
    exit 1
}

# Chrome policy registry path
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

try {
    Write-Host "Fetching website blocklist from server..." -ForegroundColor Cyan
    
    $headers = @{
        "apikey" = $SupabaseAnonKey
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $SupabaseAnonKey"
    }
    
    # Fetch active blocklist
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/website_blocklist?is_active=eq.true&select=domain_pattern" `
        -Method GET -Headers $headers
    
    $domains = @()
    if ($response) {
        $domains = $response | ForEach-Object { $_.domain_pattern }
    }
    
    Write-Host "Found $($domains.Count) blocked domains" -ForegroundColor Green
    
    # Create Chrome policy registry key if it doesn't exist
    if (-not (Test-Path $chromePolicyPath)) {
        New-Item -Path $chromePolicyPath -Force | Out-Null
        Write-Host "Created Chrome policy registry key" -ForegroundColor Yellow
    }
    
    # Apply URLBlocklist policy
    if ($domains.Count -gt 0) {
        # Convert array to registry format (multi-string value)
        Set-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -Value $domains -Type MultiString -Force
        Write-Host "Applied blocklist with $($domains.Count) domains:" -ForegroundColor Green
        $domains | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    } else {
        # Remove policy if no domains to block
        Remove-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -ErrorAction SilentlyContinue
        Write-Host "No domains to block - removed blocklist policy" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Blocklist applied successfully!" -ForegroundColor Green
    Write-Host "Users will need to restart Chrome for changes to take effect." -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to apply blocklist: $_"
    exit 1
}

