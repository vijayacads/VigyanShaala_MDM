# FleetDM Enrollment Script with Location Selection
# This script is run after osquery MSI installation
# Teacher selects location from dropdown, device is enrolled with location_id

param(
    [string]$FleetServerUrl = $env:FLEET_SERVER_URL,
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Function to get device information
function Get-DeviceInfo {
    $hostname = $env:COMPUTERNAME
    $serial = (Get-WmiObject Win32_BIOS).SerialNumber
    $osVersion = (Get-WmiObject Win32_OperatingSystem).Version
    
    return @{
        hostname = $hostname
        serial_number = $serial
        os_version = $osVersion
    }
}

# Function to fetch locations from Supabase
function Get-Locations {
    try {
        $headers = @{
            "apikey" = $SupabaseAnonKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/locations?is_active=eq.true&select=id,name,latitude,longitude,radius_meters" `
            -Method GET -Headers $headers
        
        return $response
    }
    catch {
        Write-Error "Failed to fetch locations: $_"
        return @()
    }
}

# Function to show location selection GUI
function Show-LocationSelector {
    $locations = Get-Locations
    
    if ($locations.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No locations available. Please contact administrator.",
            "Enrollment Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Device Enrollment - Select Location"
    $form.Size = New-Object System.Drawing.Size(500, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(450, 30)
    $label.Text = "Please select your school location:"
    $form.Controls.Add($label)
    
    # Dropdown
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(20, 60)
    $comboBox.Size = New-Object System.Drawing.Size(450, 30)
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    
    foreach ($location in $locations) {
        $displayText = "$($location.name) (Radius: $($location.radius_meters)m)"
        $comboBox.Items.Add($displayText) | Out-Null
        # Store location data in Tag
        $comboBox.Tag = $locations
    }
    
    $form.Controls.Add($comboBox)
    
    # OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(200, 120)
    $okButton.Size = New-Object System.Drawing.Size(100, 30)
    $okButton.Text = "Enroll"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)
    
    # Cancel Button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(310, 120)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $comboBox.SelectedIndex -ge 0) {
        $selectedIndex = $comboBox.SelectedIndex
        return $locations[$selectedIndex]
    }
    
    return $null
}

# Function to enroll device to FleetDM
function Enroll-ToFleetDM {
    param($deviceInfo, $locationId)
    
    # Generate unique UUID for device
    $deviceUuid = [guid]::NewGuid().ToString()
    
    # Enroll to FleetDM (simplified - actual enrollment depends on FleetDM API)
    Write-Host "Enrolling device to FleetDM..."
    # TODO: Implement actual FleetDM enrollment API call
    
    return $deviceUuid
}

# Function to register device in Supabase
function Register-DeviceInSupabase {
    param($deviceInfo, $locationId, $fleetUuid, $teacherId)
    
    try {
        $headers = @{
            "apikey" = $SupabaseAnonKey
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $SupabaseAnonKey"
        }
        
        $body = @{
            hostname = $deviceInfo.hostname
            serial_number = $deviceInfo.serial_number
            fleet_uuid = $fleetUuid
            location_id = $locationId
            assigned_teacher_id = $teacherId
            os_version = $deviceInfo.os_version
            compliance_status = "unknown"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices" `
            -Method POST -Headers $headers -Body $body
        
        Write-Host "Device registered successfully in Supabase"
        return $response
    }
    catch {
        Write-Error "Failed to register device: $_"
        return $null
    }
}

# Main enrollment flow
Write-Host "Starting device enrollment..."

# Get device info
$deviceInfo = Get-DeviceInfo
Write-Host "Device: $($deviceInfo.hostname) (Serial: $($deviceInfo.serial_number))"

# Show location selector
$selectedLocation = Show-LocationSelector

if ($null -eq $selectedLocation) {
    Write-Host "Enrollment cancelled by user"
    exit 1
}

Write-Host "Selected location: $($selectedLocation.name) (ID: $($selectedLocation.id))"

# Get teacher ID (optional - can be passed as parameter or from environment)
$teacherId = $env:TEACHER_ID
if ([string]::IsNullOrEmpty($teacherId)) {
    # Try to get from current user context
    $teacherId = $null  # Will be set by admin later if needed
}

# Enroll to FleetDM
$fleetUuid = Enroll-ToFleetDM -deviceInfo $deviceInfo -locationId $selectedLocation.id

# Register in Supabase
$device = Register-DeviceInSupabase -deviceInfo $deviceInfo -locationId $selectedLocation.id -fleetUuid $fleetUuid -teacherId $teacherId

if ($device) {
    [System.Windows.Forms.MessageBox]::Show(
        "Device enrolled successfully!`nLocation: $($selectedLocation.name)`nDevice ID: $($device.id)",
        "Enrollment Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    Write-Host "Enrollment complete. Device ID: $($device.id)"
    exit 0
}
else {
    [System.Windows.Forms.MessageBox]::Show(
        "Enrollment failed. Please contact administrator.",
        "Enrollment Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

