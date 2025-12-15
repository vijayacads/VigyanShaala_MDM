# Alternative Toast Test - Try different methods

param(
    [string]$Title = "VigyanShaala MDM Test",
    [string]$Message = "This is a test toast notification"
)

Write-Host ""
Write-Host "Testing different toast notification methods..." -ForegroundColor Cyan
Write-Host ""

# Method 1: Windows.UI.Notifications (Modern Toast)
Write-Host "Method 1: Windows.UI.Notifications API" -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $escapedTitle = $Title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
    $escapedMessage = $Message -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'

    $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$escapedTitle</text>
            <text>$escapedMessage</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VigyanShaala MDM")
    $notifier.Show($toast)
    
    Write-Host "  Toast shown via Windows.UI.Notifications" -ForegroundColor Green
    Write-Host "  Check notification center (bottom right corner)" -ForegroundColor Gray
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Method 2: msg.exe (Simple popup)
Write-Host ""
Write-Host "Method 2: msg.exe (Simple popup)" -ForegroundColor Yellow
try {
    msg.exe * "$Title - $Message" 2>$null
    Write-Host "  Popup shown via msg.exe" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Method 3: PowerShell Popup
Write-Host ""
Write-Host "Method 3: PowerShell Popup" -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    Write-Host "  Popup shown via MessageBox" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Method 4: BurntToast (if available)
Write-Host ""
Write-Host "Method 4: BurntToast module (if installed)" -ForegroundColor Yellow
try {
    if (Get-Module -ListAvailable -Name BurntToast) {
        Import-Module BurntToast
        New-BurntToastNotification -Text $Title, $Message
        Write-Host "  Toast shown via BurntToast" -ForegroundColor Green
    } else {
        Write-Host "  BurntToast module not installed" -ForegroundColor Gray
        Write-Host "  Install with: Install-Module -Name BurntToast" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Which method worked? Check your screen and notification center." -ForegroundColor Cyan
Write-Host ""

