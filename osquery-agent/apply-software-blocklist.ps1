# Apply Software Blocklist - Monitor and Remove Blocked Software
# This script checks for blocked software and uninstalls it

param(
    [Parameter(Mandatory=$false)]
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Error "Supabase credentials not found. Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables."
    exit 1
}

try {
    Write-Host "Fetching software blocklist from server..." -ForegroundColor Cyan
    
    $headers = @{
        "apikey" = $SupabaseAnonKey
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $SupabaseAnonKey"
    }
    
    # Fetch active software blocklist
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/software_blocklist?is_active=eq.true&select=name_pattern,path_pattern" `
        -Method GET -Headers $headers
    
    $blocklist = @()
    if ($response) {
        $blocklist = $response
    }
    
    Write-Host "Found $($blocklist.Count) blocked software patterns" -ForegroundColor Green
    
    if ($blocklist.Count -eq 0) {
        Write-Host "No blocked software configured. Exiting." -ForegroundColor Yellow
        exit 0
    }
    
    # Get all installed programs
    Write-Host "Scanning installed software..." -ForegroundColor Cyan
    $installedPrograms = Get-WmiObject -Class Win32_Product | Select-Object Name, Version, InstallLocation, IdentifyingNumber
    
    $blockedFound = @()
    $uninstalledCount = 0
    
    # Check each installed program against blocklist
    foreach ($program in $installedPrograms) {
        if (-not $program.Name) { continue }
        
        $matched = $false
        $matchedPattern = $null
        
        foreach ($blockPattern in $blocklist) {
            $namePattern = $blockPattern.name_pattern
            $pathPattern = $blockPattern.path_pattern
            
            # Check name pattern (supports wildcards)
            $nameMatch = $false
            if ($namePattern -match '\*') {
                # Wildcard match
                $regexPattern = $namePattern -replace '\*', '.*'
                $nameMatch = $program.Name -match $regexPattern
            } else {
                # Exact or contains match (case-insensitive)
                $nameMatch = $program.Name -like "*$namePattern*"
            }
            
            # Check path pattern if specified
            $pathMatch = $true
            if ($pathPattern -and $program.InstallLocation) {
                if ($pathPattern -match '\*') {
                    $regexPattern = $pathPattern -replace '\*', '.*'
                    $pathMatch = $program.InstallLocation -match $regexPattern
                } else {
                    $pathMatch = $program.InstallLocation -like "*$pathPattern*"
                }
            }
            
            if ($nameMatch -and $pathMatch) {
                $matched = $true
                $matchedPattern = $namePattern
                break
            }
        }
        
        if ($matched) {
            $blockedFound += $program
            Write-Host "Blocked software found: $($program.Name) (matches pattern: $matchedPattern)" -ForegroundColor Yellow
            
            # Attempt to uninstall
            try {
                Write-Host "  Attempting to uninstall $($program.Name)..." -ForegroundColor Cyan
                $uninstallResult = $program.Uninstall()
                
                if ($uninstallResult.ReturnValue -eq 0) {
                    Write-Host "  Successfully uninstalled $($program.Name)" -ForegroundColor Green
                    $uninstalledCount++
                } else {
                    Write-Warning "  Failed to uninstall $($program.Name) - Return code: $($uninstallResult.ReturnValue)"
                    
                    # Try alternative method using msiexec if we have a GUID
                    if ($program.IdentifyingNumber) {
                        Write-Host "  Trying alternative uninstall method..." -ForegroundColor Cyan
                        $msiUninstall = Start-Process -FilePath "msiexec.exe" `
                            -ArgumentList "/x $($program.IdentifyingNumber) /qn /norestart" `
                            -Wait -PassThru -WindowStyle Hidden
                        
                        if ($msiUninstall.ExitCode -eq 0) {
                            Write-Host "  Successfully uninstalled via msiexec" -ForegroundColor Green
                            $uninstalledCount++
                        }
                    }
                }
            } catch {
                Write-Warning "  Error uninstalling $($program.Name): $_"
            }
        }
    }
    
    Write-Host ""
    if ($blockedFound.Count -eq 0) {
        Write-Host "No blocked software detected on this system." -ForegroundColor Green
    } else {
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "  Blocked software found: $($blockedFound.Count)" -ForegroundColor Yellow
        Write-Host "  Successfully uninstalled: $uninstalledCount" -ForegroundColor Green
        
        if ($uninstalledCount -lt $blockedFound.Count) {
            Write-Host "  Failed to uninstall: $($blockedFound.Count - $uninstalledCount)" -ForegroundColor Red
            Write-Host "  Some software may require manual removal or reboot." -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Error "Failed to apply software blocklist: $_"
    exit 1
}

