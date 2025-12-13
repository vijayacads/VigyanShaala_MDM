# Chat Interface for Windows Devices
# Provides a simple GUI chat interface for communicating with support center

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided"
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MDM Chat Support - $DeviceHostname"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Message display area
$messageBox = New-Object System.Windows.Forms.RichTextBox
$messageBox.Location = New-Object System.Drawing.Point(10, 10)
$messageBox.Size = New-Object System.Drawing.Size(570, 350)
$messageBox.ReadOnly = $true
$messageBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($messageBox)

# Input text box
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = New-Object System.Drawing.Point(10, 370)
$inputBox.Size = New-Object System.Drawing.Size(480, 20)
$inputBox.Multiline = $false
$form.Controls.Add($inputBox)

# Send button
$sendButton = New-Object System.Windows.Forms.Button
$sendButton.Location = New-Object System.Drawing.Point(500, 368)
$sendButton.Size = New-Object System.Drawing.Size(80, 25)
$sendButton.Text = "Send"
$form.Controls.Add($sendButton)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 400)
$statusLabel.Size = New-Object System.Drawing.Size(570, 20)
$statusLabel.Text = "Connected"
$form.Controls.Add($statusLabel)

# Function to load messages
function Load-Messages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    
    try {
        $url = "$SupabaseUrl/rest/v1/chat_messages?device_hostname=eq.$DeviceHostname&order=timestamp.asc"
        $messages = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $messageBox.Clear()
        foreach ($msg in $messages) {
            $sender = if ($msg.sender -eq "center") { "Support" } else { "Device" }
            $time = [DateTime]::Parse($msg.timestamp).ToLocalTime().ToString("HH:mm:ss")
            $messageBox.AppendText("[$time] $sender`: $($msg.message)`r`n")
        }
        $messageBox.SelectionStart = $messageBox.Text.Length
        $messageBox.ScrollToCaret()
    } catch {
        $statusLabel.Text = "Error loading messages: $_"
    }
}

# Function to send message
function Send-Message {
    if ([string]::IsNullOrWhiteSpace($inputBox.Text)) {
        return
    }
    
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        device_hostname = $DeviceHostname
        sender = "device"
        message = $inputBox.Text.Trim()
    } | ConvertTo-Json
    
    try {
        $url = "$SupabaseUrl/rest/v1/chat_messages"
        Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body | Out-Null
        $inputBox.Clear()
        Load-Messages
        $statusLabel.Text = "Message sent"
    } catch {
        $statusLabel.Text = "Error sending message: $_"
    }
}

# Send button click handler
$sendButton.Add_Click({ Send-Message })

# Enter key handler
$inputBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Send-Message
    }
})

# Load initial messages
Load-Messages

# Poll for new messages every 5 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({ Load-Messages })
$timer.Start()

# Show form
$form.Add_FormClosing({
    $timer.Stop()
})

[System.Windows.Forms.Application]::Run($form)

