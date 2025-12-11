# Device Enrollment Script with Full Form
# This script collects all device information and registers it in Supabase
# Run after osquery installation

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY
)

# Function to get device information automatically
function Get-DeviceInfo {
    $hostname = $env:COMPUTERNAME
    try {
        $serial = (Get-WmiObject Win32_BIOS).SerialNumber
    } catch {
        $serial = "UNKNOWN"
    }
    
    try {
        $osVersion = (Get-WmiObject Win32_OperatingSystem).Version
    } catch {
        $osVersion = "Unknown"
    }
    
    try {
        $laptopModel = (Get-WmiObject Win32_ComputerSystem).Model
    } catch {
        $laptopModel = ""
    }
    
    return @{
        hostname = $hostname
        serial_number = $serial
        os_version = $osVersion
        laptop_model = $laptopModel
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

# Function to show full device enrollment form
function Show-DeviceEnrollmentForm {
    $deviceInfo = Get-DeviceInfo
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Device Enrollment - VigyanShaala MDM"
    $form.Size = New-Object System.Drawing.Size(600, 650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    $yPos = 20
    $labelHeight = 25
    $inputHeight = 25
    $spacing = 35
    
    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $titleLabel.Size = New-Object System.Drawing.Size(550, 30)
    $titleLabel.Text = "Please enter device information:"
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)
    $yPos += 40
    
    # Device Inventory Code
    $label1 = New-Object System.Windows.Forms.Label
    $label1.Location = New-Object System.Drawing.Point(20, $yPos)
    $label1.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label1.Text = "Device Inventory Code *:"
    $form.Controls.Add($label1)
    
    $txtInventoryCode = New-Object System.Windows.Forms.TextBox
    $txtInventoryCode.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtInventoryCode.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $form.Controls.Add($txtInventoryCode)
    $yPos += $spacing
    
    # Hostname
    $label2 = New-Object System.Windows.Forms.Label
    $label2.Location = New-Object System.Drawing.Point(20, $yPos)
    $label2.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label2.Text = "Device Name/Hostname *:"
    $form.Controls.Add($label2)
    
    $txtHostname = New-Object System.Windows.Forms.TextBox
    $txtHostname.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtHostname.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtHostname.Text = $deviceInfo.hostname
    $form.Controls.Add($txtHostname)
    $yPos += $spacing
    
    # Serial Number
    $label3 = New-Object System.Windows.Forms.Label
    $label3.Location = New-Object System.Drawing.Point(20, $yPos)
    $label3.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label3.Text = "Serial Number:"
    $form.Controls.Add($label3)
    
    $txtSerial = New-Object System.Windows.Forms.TextBox
    $txtSerial.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtSerial.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtSerial.Text = $deviceInfo.serial_number
    $form.Controls.Add($txtSerial)
    $yPos += $spacing
    
    # Host Location (College, Lab, etc.)
    $label4 = New-Object System.Windows.Forms.Label
    $label4.Location = New-Object System.Drawing.Point(20, $yPos)
    $label4.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label4.Text = "Host Location (College, Lab, etc.) *:"
    $form.Controls.Add($label4)
    
    $txtHostLocation = New-Object System.Windows.Forms.TextBox
    $txtHostLocation.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtHostLocation.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtHostLocation.PlaceholderText = "e.g., Computer Lab, Classroom 101"
    $form.Controls.Add($txtHostLocation)
    $yPos += $spacing
    
    # City/Town/Village
    $label5 = New-Object System.Windows.Forms.Label
    $label5.Location = New-Object System.Drawing.Point(20, $yPos)
    $label5.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label5.Text = "City/Town/Village:"
    $form.Controls.Add($label5)
    
    $txtCity = New-Object System.Windows.Forms.TextBox
    $txtCity.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtCity.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtCity.PlaceholderText = "e.g., Pune, Mumbai"
    $form.Controls.Add($txtCity)
    $yPos += $spacing
    
    # Laptop Model
    $label6 = New-Object System.Windows.Forms.Label
    $label6.Location = New-Object System.Drawing.Point(20, $yPos)
    $label6.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label6.Text = "Laptop Model:"
    $form.Controls.Add($label6)
    
    $txtLaptopModel = New-Object System.Windows.Forms.TextBox
    $txtLaptopModel.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtLaptopModel.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtLaptopModel.Text = $deviceInfo.laptop_model
    $form.Controls.Add($txtLaptopModel)
    $yPos += $spacing
    
    # OS Version
    $label7 = New-Object System.Windows.Forms.Label
    $label7.Location = New-Object System.Drawing.Point(20, $yPos)
    $label7.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label7.Text = "OS Version:"
    $form.Controls.Add($label7)
    
    $txtOSVersion = New-Object System.Windows.Forms.TextBox
    $txtOSVersion.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtOSVersion.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtOSVersion.Text = $deviceInfo.os_version
    $form.Controls.Add($txtOSVersion)
    $yPos += $spacing
    
    # Latitude
    $label8 = New-Object System.Windows.Forms.Label
    $label8.Location = New-Object System.Drawing.Point(20, $yPos)
    $label8.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label8.Text = "Latitude * (-90 to 90):"
    $form.Controls.Add($label8)
    
    $txtLatitude = New-Object System.Windows.Forms.TextBox
    $txtLatitude.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtLatitude.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtLatitude.PlaceholderText = "e.g., 18.5204"
    $form.Controls.Add($txtLatitude)
    $yPos += $spacing
    
    # Longitude
    $label9 = New-Object System.Windows.Forms.Label
    $label9.Location = New-Object System.Drawing.Point(20, $yPos)
    $label9.Size = New-Object System.Drawing.Size(260, $labelHeight)
    $label9.Text = "Longitude * (-180 to 180):"
    $form.Controls.Add($label9)
    
    $txtLongitude = New-Object System.Windows.Forms.TextBox
    $txtLongitude.Location = New-Object System.Drawing.Point(280, $yPos)
    $txtLongitude.Size = New-Object System.Drawing.Size(280, $inputHeight)
    $txtLongitude.PlaceholderText = "e.g., 73.8567"
    $form.Controls.Add($txtLongitude)
    $yPos += $spacing
    
    # Note: Location selection removed - matching AddDevice component which doesn't use location_id
    $yPos += 20
    
    # Buttons
    $btnRegister = New-Object System.Windows.Forms.Button
    $btnRegister.Location = New-Object System.Drawing.Point(200, $yPos)
    $btnRegister.Size = New-Object System.Drawing.Size(100, 35)
    $btnRegister.Text = "Register Device"
    $btnRegister.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $form.AcceptButton = $btnRegister
    $form.Controls.Add($btnRegister)
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(310, $yPos)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancel.Text = "Cancel"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)
    
    # Validation and submission
    $result = $null
    $formData = $null
    
    $btnRegister.Add_Click({
        # Validation
        if ([string]::IsNullOrWhiteSpace($txtInventoryCode.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Device Inventory Code is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtHostname.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Device Name/Hostname is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtHostLocation.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Host Location is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtLatitude.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Latitude is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ([string]::IsNullOrWhiteSpace($txtLongitude.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Longitude is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        # Validate coordinates
        $lat = 0
        $lon = 0
        if (-not [double]::TryParse($txtLatitude.Text, [ref]$lat) -or $lat -lt -90 -or $lat -gt 90) {
            [System.Windows.Forms.MessageBox]::Show("Latitude must be a number between -90 and 90.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if (-not [double]::TryParse($txtLongitude.Text, [ref]$lon) -or $lon -lt -180 -or $lon -gt 180) {
            [System.Windows.Forms.MessageBox]::Show("Longitude must be a number between -180 and 180.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Prepare form data - matching AddDevice component exactly (no location_id, no device ID)
        $formData = @{
            device_inventory_code = $txtInventoryCode.Text.Trim()
            hostname = $txtHostname.Text.Trim()
            serial_number = if ([string]::IsNullOrWhiteSpace($txtSerial.Text)) { $null } else { $txtSerial.Text.Trim() }
            host_location = $txtHostLocation.Text.Trim()
            city_town_village = if ([string]::IsNullOrWhiteSpace($txtCity.Text)) { $null } else { $txtCity.Text.Trim() }
            laptop_model = if ([string]::IsNullOrWhiteSpace($txtLaptopModel.Text)) { $null } else { $txtLaptopModel.Text.Trim() }
            os_version = if ([string]::IsNullOrWhiteSpace($txtOSVersion.Text)) { $null } else { $txtOSVersion.Text.Trim() }
            latitude = [double]$txtLatitude.Text
            longitude = [double]$txtLongitude.Text
        }
        
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    
    $dialogResult = $form.ShowDialog()
    
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and $formData) {
        return $formData
    }
    
    return $null
}

# Function to register device in Supabase
function Register-DeviceInSupabase {
    param($deviceData)
    
    try {
        $headers = @{
            "apikey" = $SupabaseAnonKey
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $SupabaseAnonKey"
            "Prefer" = "return=representation"
        }
        
        # Build body exactly matching AddDevice component - NO location_id, NO device ID
        $body = @{
            hostname = $deviceData.hostname
            device_inventory_code = if ([string]::IsNullOrWhiteSpace($deviceData.device_inventory_code)) { $null } else { $deviceData.device_inventory_code }
            serial_number = if ([string]::IsNullOrWhiteSpace($deviceData.serial_number)) { $null } else { $deviceData.serial_number }
            host_location = if ([string]::IsNullOrWhiteSpace($deviceData.host_location)) { $null } else { $deviceData.host_location }
            city_town_village = if ([string]::IsNullOrWhiteSpace($deviceData.city_town_village)) { $null } else { $deviceData.city_town_village }
            laptop_model = if ([string]::IsNullOrWhiteSpace($deviceData.laptop_model)) { $null } else { $deviceData.laptop_model }
            latitude = if ($deviceData.latitude) { [double]$deviceData.latitude } else { $null }
            longitude = if ($deviceData.longitude) { [double]$deviceData.longitude } else { $null }
            os_version = if ([string]::IsNullOrWhiteSpace($deviceData.os_version)) { $null } else { $deviceData.os_version }
            compliance_status = "unknown"
            last_seen = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } | ConvertTo-Json -Depth 10
        
        Write-Host "Registering device in Supabase..." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Device Data:" -ForegroundColor Yellow
        Write-Host "  Hostname: $($deviceData.hostname)" -ForegroundColor White
        Write-Host "  Inventory Code: $($deviceData.device_inventory_code)" -ForegroundColor White
        Write-Host "  Host Location: $($deviceData.host_location)" -ForegroundColor White
        Write-Host ""
        Write-Host "Preparing device registration request..." -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/devices" `
            -Method POST -Headers $headers -Body $body
        
        return $response
    }
    catch {
        $errorDetails = $_.Exception.Message
        $statusCode = $null
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd()
            
            Write-Host "HTTP Status Code: $statusCode" -ForegroundColor Red
            Write-Host "Response Body: $responseBody" -ForegroundColor Red
            Write-Host ""
            
            if ($responseBody) {
                $errorDetails = $responseBody
            }
        }
        
        Write-Error "Failed to register device: $errorDetails"
        return $null
    }
}

# Main enrollment flow
Write-Host "Starting device enrollment..." -ForegroundColor Cyan

# Check environment variables
if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Configuration error: Supabase credentials not found.`n`nPlease ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.`n`nContact administrator for support.",
        "Configuration Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# Show enrollment form
$formData = Show-DeviceEnrollmentForm

if ($null -eq $formData) {
    Write-Host "Enrollment cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host "Registering device in Supabase..." -ForegroundColor Cyan

# Register device
$device = Register-DeviceInSupabase -deviceData $formData

if ($device) {
    $successMessage = "Device enrolled successfully!`n`n" +
                      "Device Name: $($device.hostname)`n" +
                      "Inventory Code: $($device.device_inventory_code)`n`n" +
                      "The device will now appear in the dashboard."
    
    [System.Windows.Forms.MessageBox]::Show(
        $successMessage,
        "Enrollment Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    Write-Host "Device registered successfully!" -ForegroundColor Green
    Write-Host "Device Name: $($device.hostname)" -ForegroundColor Green
    Write-Host "Inventory Code: $($device.device_inventory_code)" -ForegroundColor Green
    exit 0
}
else {
    [System.Windows.Forms.MessageBox]::Show(
        "Enrollment failed. Please check your internet connection and try again.`n`nIf the problem persists, contact administrator.",
        "Enrollment Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

