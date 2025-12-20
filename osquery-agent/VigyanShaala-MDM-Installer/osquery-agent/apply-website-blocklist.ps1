# Apply Website Blocklist to All Browsers via Windows Hosts File + Browser Policies
# This script fetches the blocklist from Supabase and applies it system-wide

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges to modify registry and hosts file"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Error "Supabase credentials not found. Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables."
    exit 1
}

# Browser policy registry paths
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$mdmMarkerStart = "# VigyanShaala-MDM Blocklist Start"
$mdmMarkerEnd = "# VigyanShaala-MDM Blocklist End"

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
    
    # ============================================
    # OPTION 1: Browser-specific policies (Chrome & Edge)
    # ============================================
    
    # Chrome policy
    if (-not (Test-Path $chromePolicyPath)) {
        New-Item -Path $chromePolicyPath -Force | Out-Null
    }
    if ($domains.Count -gt 0) {
        Set-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -Value $domains -Type MultiString -Force
        Write-Host "Applied blocklist to Chrome via registry policy" -ForegroundColor Green
    } else {
        Remove-ItemProperty -Path $chromePolicyPath -Name "URLBlocklist" -ErrorAction SilentlyContinue
    }
    
    # Edge policy (Chromium-based, same format as Chrome)
    if (-not (Test-Path $edgePolicyPath)) {
        New-Item -Path $edgePolicyPath -Force | Out-Null
    }
    if ($domains.Count -gt 0) {
        Set-ItemProperty -Path $edgePolicyPath -Name "URLBlocklist" -Value $domains -Type MultiString -Force
        Write-Host "Applied blocklist to Edge via registry policy" -ForegroundColor Green
    } else {
        Remove-ItemProperty -Path $edgePolicyPath -Name "URLBlocklist" -ErrorAction SilentlyContinue
    }
    
    # ============================================
    # OPTION 2: Windows Hosts File (blocks ALL browsers and apps)
    # ============================================
    
    Write-Host "Updating Windows Hosts file..." -ForegroundColor Cyan
    
    # Read existing hosts file (excluding our MDM entries)
    $existingHosts = @()
    if (Test-Path $hostsFile) {
        $allLines = Get-Content $hostsFile -ErrorAction SilentlyContinue
        $insideMdmSection = $false
        
        foreach ($line in $allLines) {
            if ($line -eq $mdmMarkerStart) {
                $insideMdmSection = $true
                continue
            }
            if ($line -eq $mdmMarkerEnd) {
                $insideMdmSection = $false
                continue
            }
            if (-not $insideMdmSection) {
                $existingHosts += $line
            }
        }
    }
    
    # Build new hosts entries
    $hostsEntries = @()
    if ($domains.Count -gt 0) {
        $hostsEntries += ""
        $hostsEntries += $mdmMarkerStart
        $hostsEntries += "# Auto-managed by VigyanShaala MDM - Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $hostsEntries += "# Do not edit manually - Changes will be overwritten"
        $hostsEntries += ""
        
        foreach ($domain in $domains) {
            # Clean domain: remove wildcards, protocols, paths
            $cleanDomain = $domain -replace '^\*\.', '' -replace '^https?://', '' -replace '/.*$', '' -replace '^www\.', ''
            
            if ($cleanDomain -and $cleanDomain -match '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                # Add main domain
                $hostsEntries += "0.0.0.0 $cleanDomain"
                # Also block www subdomain if not already www
                if (-not $cleanDomain.StartsWith("www.")) {
                    $hostsEntries += "0.0.0.0 www.$cleanDomain"
                }
            }
        }
        
        $hostsEntries += $mdmMarkerEnd
    }
    
    # Write combined hosts file
    $allHosts = $existingHosts + $hostsEntries
    $allHosts | Set-Content $hostsFile -Encoding ASCII -Force
    
    Write-Host "Updated Windows Hosts file - blocks all browsers and applications" -ForegroundColor Green
    
    # Flush DNS cache for immediate effect
    Write-Host "Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    
    Write-Host ""
    Write-Host "Blocklist applied successfully!" -ForegroundColor Green
    Write-Host "Blocking active in:" -ForegroundColor Cyan
    Write-Host "  - Chrome (via registry policy)" -ForegroundColor White
    Write-Host "  - Edge (via registry policy)" -ForegroundColor White
    Write-Host "  - Firefox, Opera, Safari (via hosts file)" -ForegroundColor White
    Write-Host "  - All other browsers and applications (via hosts file)" -ForegroundColor White
    Write-Host ""
    Write-Host "Changes take effect immediately - no browser restart needed!" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to apply blocklist: $_"
    exit 1
}

