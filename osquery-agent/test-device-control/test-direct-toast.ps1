# Direct Toast Test - Shows toast notification immediately
# This bypasses the user-session agent and shows toast directly

param(
    [string]$Title = "VigyanShaala MDM Test",
    [string]$Message = "This is a test toast notification"
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Direct Toast Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Title: $Title" -ForegroundColor Yellow
Write-Host "Message: $Message" -ForegroundColor Yellow
Write-Host "Showing toast notification now..." -ForegroundColor Yellow
Write-Host ""

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    # Escape XML special characters
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
    
    Write-Host "Toast notification shown!" -ForegroundColor Green
    Write-Host "Check your Windows notification center (bottom right)" -ForegroundColor Gray
} catch {
    Write-Host "Failed to show toast: $_" -ForegroundColor Red
    Write-Host "Trying fallback method..." -ForegroundColor Yellow
    
    # Fallback to msg.exe
    try {
        msg.exe * "$Title - $Message" 2>$null
        Write-Host "Fallback message shown" -ForegroundColor Green
    } catch {
        Write-Host "Fallback also failed" -ForegroundColor Red
    }
}

Write-Host ""




