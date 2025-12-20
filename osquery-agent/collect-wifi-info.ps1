# Collect WiFi Network Information for Location Tracking
# This script collects the currently connected WiFi SSID and signal strength

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "json"
)

function Get-WiFiInfo {
    try {
        # Get currently connected WiFi network using netsh
        $wifiOutput = netsh wlan show interfaces 2>$null
        
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wifiOutput)) {
            return @{
                ssid = $null
                signal_strength = $null
                status = "not_connected"
            }
        }
        
        # Parse SSID from output
        $ssid = $null
        $signal = $null
        
        foreach ($line in $wifiOutput) {
            if ($line -match "^\s*SSID\s*:\s*(.+)$") {
                $ssid = $matches[1].Trim()
            }
            if ($line -match "^\s*Signal\s*:\s*(\d+)%") {
                $signal = [int]$matches[1]
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($ssid) -or $ssid -eq "") {
            return @{
                ssid = $null
                signal_strength = $null
                status = "not_connected"
            }
        }
        
        return @{
            ssid = $ssid
            signal_strength = $signal
            status = "connected"
        }
    }
    catch {
        return @{
            ssid = $null
            signal_strength = $null
            status = "error"
            error = $_.Exception.Message
        }
    }
}

$wifiInfo = Get-WiFiInfo

if ($OutputFormat -eq "json") {
    $wifiInfo | ConvertTo-Json -Compress
} else {
    Write-Output $wifiInfo
}




