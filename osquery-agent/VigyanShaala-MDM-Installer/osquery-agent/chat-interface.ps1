# Chat Interface for Windows Devices
# Beautiful UI with VigyanShaala branding and tabs for Chat and Broadcast Messages

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

# VigyanShaala Brand Colors
$PrimaryBlue = [System.Drawing.Color]::FromArgb(44, 72, 105)   # #2c4869
$PrimaryGreen = [System.Drawing.Color]::FromArgb(105, 171, 74)  # #69ab4a
$PrimaryYellow = [System.Drawing.Color]::FromArgb(255, 204, 41) # #ffcc29
$SecondaryCyan = [System.Drawing.Color]::FromArgb(145, 216, 247) # #91d8f7
$SecondaryLightGreen = [System.Drawing.Color]::FromArgb(157, 211, 175) # #9dd3af
$SecondaryOrange = [System.Drawing.Color]::FromArgb(245, 134, 52) # #f58634

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "VigyanShaala MDM - Chat & Messages"
$form.Size = New-Object System.Drawing.Size(700, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Header Panel with Logo and Title
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(700, 80)
$headerPanel.BackColor = $PrimaryBlue
$form.Controls.Add($headerPanel)

# Try to load and display logo
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logoPath = Join-Path $scriptDir "Logo.png"
if (-not (Test-Path $logoPath)) {
    $logoPath = "$env:ProgramFiles\osquery\Logo.png"
}
if (Test-Path $logoPath) {
    try {
        $logo = [System.Drawing.Image]::FromFile($logoPath)
        $logoPictureBox = New-Object System.Windows.Forms.PictureBox
        $logoPictureBox.Location = New-Object System.Drawing.Point(10, 10)
        $logoPictureBox.Size = New-Object System.Drawing.Size(60, 60)
        $logoPictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $logoPictureBox.Image = $logo
        $headerPanel.Controls.Add($logoPictureBox)
    } catch {
        Write-Warning "Could not load logo: $_"
    }
}

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "VigyanShaala MDM"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Location = New-Object System.Drawing.Point(80, 15)
$titleLabel.Size = New-Object System.Drawing.Size(300, 30)
$titleLabel.AutoSize = $false
$headerPanel.Controls.Add($titleLabel)

# Device Label
$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Text = "Device: $DeviceHostname"
$deviceLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$deviceLabel.ForeColor = $SecondaryCyan
$deviceLabel.Location = New-Object System.Drawing.Point(80, 45)
$deviceLabel.Size = New-Object System.Drawing.Size(300, 20)
$deviceLabel.AutoSize = $false
$headerPanel.Controls.Add($deviceLabel)

# Tab Panel
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 90)
$tabControl.Size = New-Object System.Drawing.Size(680, 450)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($tabControl)

# Chat Tab
$chatTab = New-Object System.Windows.Forms.TabPage
$chatTab.Text = "💬 Chat"
$chatTab.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($chatTab)

# Broadcast Messages Tab
$broadcastTab = New-Object System.Windows.Forms.TabPage
$broadcastTab.Text = "📢 Broadcast Messages"
$broadcastTab.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($broadcastTab)

# Chat Tab Content
$chatMessageBox = New-Object System.Windows.Forms.RichTextBox
$chatMessageBox.Location = New-Object System.Drawing.Point(10, 10)
$chatMessageBox.Size = New-Object System.Drawing.Size(660, 350)
$chatMessageBox.ReadOnly = $true
$chatMessageBox.BackColor = [System.Drawing.Color]::White
$chatMessageBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chatMessageBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$chatTab.Controls.Add($chatMessageBox)

$chatInputBox = New-Object System.Windows.Forms.TextBox
$chatInputBox.Location = New-Object System.Drawing.Point(10, 370)
$chatInputBox.Size = New-Object System.Drawing.Size(550, 25)
$chatInputBox.Multiline = $false
$chatInputBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chatInputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$chatTab.Controls.Add($chatInputBox)

$chatSendButton = New-Object System.Windows.Forms.Button
$chatSendButton.Location = New-Object System.Drawing.Point(570, 368)
$chatSendButton.Size = New-Object System.Drawing.Size(100, 30)
$chatSendButton.Text = "Send"
$chatSendButton.BackColor = $PrimaryGreen
$chatSendButton.ForeColor = [System.Drawing.Color]::White
$chatSendButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$chatSendButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$chatTab.Controls.Add($chatSendButton)

# Broadcast Tab Content
$broadcastMessageBox = New-Object System.Windows.Forms.RichTextBox
$broadcastMessageBox.Location = New-Object System.Drawing.Point(10, 10)
$broadcastMessageBox.Size = New-Object System.Drawing.Size(660, 390)
$broadcastMessageBox.ReadOnly = $true
$broadcastMessageBox.BackColor = [System.Drawing.Color]::White
$broadcastMessageBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$broadcastMessageBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$broadcastTab.Controls.Add($broadcastMessageBox)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 550)
$statusLabel.Size = New-Object System.Drawing.Size(680, 20)
$statusLabel.Text = "Connected"
$statusLabel.ForeColor = $PrimaryGreen
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($statusLabel)

# Function to format message
function Format-Message {
    param(
        [string]$Sender,
        [string]$Message,
        [string]$Time,
        [bool]$IsBroadcast = $false
    )
    
    $prefix = if ($IsBroadcast) { "📢 [BROADCAST]" } else { "" }
    
    $formatted = "[$Time] $prefix $Sender`: $Message`r`n"
    return $formatted
}

# Function to load chat messages
function Load-ChatMessages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    
    try {
        $url = "$SupabaseUrl/rest/v1/chat_messages?device_hostname=eq.$DeviceHostname&order=timestamp.asc"
        $messages = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $chatMessageBox.Clear()
        foreach ($msg in $messages) {
            $sender = if ($msg.sender -eq "center") { "Support" } else { "You" }
            $time = [DateTime]::Parse($msg.timestamp).ToLocalTime().ToString("HH:mm:ss")
            $formatted = Format-Message -Sender $sender -Message $msg.message -Time $time
            $chatMessageBox.AppendText($formatted)
        }
        $chatMessageBox.SelectionStart = $chatMessageBox.Text.Length
        $chatMessageBox.ScrollToCaret()
    } catch {
        $statusLabel.Text = "Error loading messages: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# Function to load broadcast messages
function Load-BroadcastMessages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    
    try {
        $url = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$DeviceHostname&command_type=eq.broadcast_message&order=created_at.desc&limit=50"
        $messages = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $broadcastMessageBox.Clear()
        if ($messages -and $messages.Count -gt 0) {
            foreach ($msg in $messages) {
                if ($msg.message) {
                    $time = [DateTime]::Parse($msg.created_at).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
                    $status = $msg.status
                    $statusColor = switch ($status) {
                        "pending" { "⏳" }
                        "dismissed" { "✓" }
                        "expired" { "⏰" }
                        default { "•" }
                    }
                    $formatted = "[$time] $statusColor $($msg.message)`r`n"
                    $broadcastMessageBox.AppendText($formatted)
                }
            }
        } else {
            $broadcastMessageBox.AppendText("No broadcast messages yet.`r`n")
        }
        $broadcastMessageBox.SelectionStart = $broadcastMessageBox.Text.Length
        $broadcastMessageBox.ScrollToCaret()
    } catch {
        $statusLabel.Text = "Error loading broadcast messages: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# Function to send chat message
function Send-ChatMessage {
    if ([string]::IsNullOrWhiteSpace($chatInputBox.Text)) {
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
        message = $chatInputBox.Text.Trim()
    } | ConvertTo-Json
    
    try {
        $url = "$SupabaseUrl/rest/v1/chat_messages"
        Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body | Out-Null
        $chatInputBox.Clear()
        Load-ChatMessages
        $statusLabel.Text = "Message sent"
        $statusLabel.ForeColor = $PrimaryGreen
    } catch {
        $statusLabel.Text = "Error sending message: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# Event handlers
$chatSendButton.Add_Click({ Send-ChatMessage })
$chatInputBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Send-ChatMessage
    }
})

# Load initial messages
Load-ChatMessages
Load-BroadcastMessages

# Poll for new messages every 5 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    Load-ChatMessages
    Load-BroadcastMessages
})
$timer.Start()

# Show form
$form.Add_FormClosing({
    $timer.Stop()
})

[System.Windows.Forms.Application]::Run($form)
