# Prevent Uninstallation and Settings Changes
# This script locks down osquery and prevents students from modifying or removing it
# Run this as Administrator after osquery installation

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

$osqueryPath = "C:\Program Files\osquery"
$osqueryService = "osqueryd"

Write-Host "Locking down osquery installation..."

# 1. Remove permissions for non-administrators
Write-Host "Setting folder permissions..."
$acl = Get-Acl $osqueryPath
$acl.SetAccessRuleProtection($true, $false)  # Remove inherited permissions

# Remove all access for Users group
$usersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Users",
    "ReadAndExecute",
    "ContainerInherit,ObjectInherit",
    "None",
    "Deny"
)
$acl.AddAccessRule($usersRule)

# Keep full control for Administrators
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($adminRule)

Set-Acl -Path $osqueryPath -AclObject $acl

# 2. Prevent service stop/start by non-admins
Write-Host "Configuring service permissions..."
sc.exe sdset $osqueryService "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPLORC;;;SO)(A;;CCLCSWRPLORC;;;LS)(A;;CCLCSWRPLORC;;;SU)"

# 3. Lock osquery.conf - make it read-only and restrict access
$configPath = "$osqueryPath\osquery.conf"
if (Test-Path $configPath) {
    Write-Host "Locking configuration file..."
    $configAcl = Get-Acl $configPath
    $configAcl.SetAccessRuleProtection($true, $false)
    
    $configUsersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Users",
        "Read",
        "Allow"
    )
    $configAcl.AddAccessRule($configUsersRule)
    
    $configAdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Administrators",
        "FullControl",
        "Allow"
    )
    $configAcl.AddAccessRule($configAdminRule)
    
    Set-Acl -Path $configPath -AclObject $configAcl
    Set-ItemProperty -Path $configPath -Name IsReadOnly -Value $true
}

# 4. Prevent uninstallation via registry (if installed via MSI)
Write-Host "Locking registry keys..."
$uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*osquery*"
$uninstallKeys = Get-ItemProperty -Path $uninstallKey -ErrorAction SilentlyContinue

foreach ($key in $uninstallKeys) {
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($key.PSChildName)"
    # Remove "Uninstall" value to hide from Programs and Features
    Remove-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $keyPath -Name "QuietUninstallString" -ErrorAction SilentlyContinue
}

# 5. Create Group Policy to prevent uninstallation (if domain-joined)
Write-Host "Creating Group Policy restrictions..."
$gpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
if (-not (Test-Path $gpoPath)) {
    New-Item -Path $gpoPath -Force | Out-Null
}

# Prevent users from installing/uninstalling software
Set-ItemProperty -Path $gpoPath -Name "DisableMSI" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $gpoPath -Name "DisableUserInstalls" -Value 1 -Type DWord -ErrorAction SilentlyContinue

# 6. Block access to osquery.exe directly (optional - may break functionality)
# Uncomment if you want to prevent direct execution
# $osqueryExe = "$osqueryPath\osquery.exe"
# if (Test-Path $osqueryExe) {
#     $exeAcl = Get-Acl $osqueryExe
#     $exeAcl.SetAccessRuleProtection($true, $false)
#     $exeUsersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
#         "Users",
#         "ReadAndExecute",
#         "Allow"
#     )
#     $exeAcl.AddAccessRule($exeUsersRule)
#     Set-Acl -Path $osqueryExe -AclObject $exeAcl
# }

# 7. Create scheduled task to re-enable service if stopped
Write-Host "Creating watchdog task..."
$taskName = "OsqueryWatchdog"
$taskAction = New-ScheduledTaskAction -Execute "sc.exe" -Argument "start $osqueryService"
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null

Write-Host "`nLockdown complete!"
Write-Host "`nProtection measures applied:"
Write-Host "  - Folder permissions restricted"
Write-Host "  - Service permissions locked"
Write-Host "  - Configuration file protected"
Write-Host "  - Uninstall registry keys removed"
Write-Host "  - Watchdog task created (auto-restart if stopped)"
Write-Host "`nNote: Students cannot uninstall or modify osquery without admin rights."

