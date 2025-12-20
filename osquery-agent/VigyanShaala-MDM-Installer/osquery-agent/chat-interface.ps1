# Chat Interface for Windows Devices
# Beautiful UI with VigyanShaala branding and tabs for Chat and Broadcast Messages
# Emojis removed for PowerShell compatibility across all versions

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
$LightBg = [System.Drawing.Color]::FromArgb(248, 250, 252) # #f8fafc
$White = [System.Drawing.Color]::White

# Create main form - Larger and more spacious
$form = New-Object System.Windows.Forms.Form
$form.Text = "VigyanShaala MDM - Chat & Messages"
$form.Size = New-Object System.Drawing.Size(800, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $LightBg
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Enhanced Header Panel with Gradient Effect
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(800, 100)
$headerPanel.BackColor = $PrimaryBlue
$form.Controls.Add($headerPanel)

# Try to load and display logo - Larger and better positioned
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logoPath = Join-Path $scriptDir "Logo.png"
if (-not (Test-Path $logoPath)) {
    $logoPath = "$env:ProgramFiles\osquery\Logo.png"
}
if (-not (Test-Path $logoPath)) {
    $logoPath = ".\Logo.png"
}

if (Test-Path $logoPath) {
    try {
        $logo = [System.Drawing.Image]::FromFile($logoPath)
        $logoPictureBox = New-Object System.Windows.Forms.PictureBox
        $logoPictureBox.Location = New-Object System.Drawing.Point(15, 10)
        $logoPictureBox.Size = New-Object System.Drawing.Size(80, 80)
        $logoPictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $logoPictureBox.Image = $logo
        $logoPictureBox.BackColor = [System.Drawing.Color]::Transparent
        $headerPanel.Controls.Add($logoPictureBox)
    } catch {
        Write-Warning "Could not load logo: $_"
    }
}

# Title Label - More prominent
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "VigyanShaala MDM"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $White
$titleLabel.Location = New-Object System.Drawing.Point(105, 15)
$titleLabel.Size = New-Object System.Drawing.Size(400, 35)
$titleLabel.AutoSize = $false
$headerPanel.Controls.Add($titleLabel)

# Device Label - Colorful accent
$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Text = "Device: $DeviceHostname"
$deviceLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$deviceLabel.ForeColor = $PrimaryYellow
$deviceLabel.Location = New-Object System.Drawing.Point(105, 55)
$deviceLabel.Size = New-Object System.Drawing.Size(400, 25)
$deviceLabel.AutoSize = $false
$headerPanel.Controls.Add($deviceLabel)

# Tab Panel - Enhanced styling
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(15, 115)
$tabControl.Size = New-Object System.Drawing.Size(770, 540)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$tabControl.Appearance = [System.Windows.Forms.TabAppearance]::Buttons
$form.Controls.Add($tabControl)

# Chat Tab
$chatTab = New-Object System.Windows.Forms.TabPage
$chatTab.Text = "Chat"
$chatTab.BackColor = $White
$chatTab.Padding = New-Object System.Windows.Forms.Padding(10)
$tabControl.TabPages.Add($chatTab)

# Broadcast Messages Tab
$broadcastTab = New-Object System.Windows.Forms.TabPage
$broadcastTab.Text = "Broadcast Messages"
$broadcastTab.BackColor = $White
$broadcastTab.Padding = New-Object System.Windows.Forms.Padding(10)
$tabControl.TabPages.Add($broadcastTab)

# Chat Tab Content - Enhanced styling
$chatMessageBox = New-Object System.Windows.Forms.RichTextBox
$chatMessageBox.Location = New-Object System.Drawing.Point(15, 15)
$chatMessageBox.Size = New-Object System.Drawing.Size(740, 420)
$chatMessageBox.ReadOnly = $true
$chatMessageBox.BackColor = $White
$chatMessageBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$chatMessageBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$chatMessageBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$chatTab.Controls.Add($chatMessageBox)

# Input container with gradient-like background
$inputPanel = New-Object System.Windows.Forms.Panel
$inputPanel.Location = New-Object System.Drawing.Point(15, 445)
$inputPanel.Size = New-Object System.Drawing.Size(740, 60)
$inputPanel.BackColor = $SecondaryLightGreen
$chatTab.Controls.Add($inputPanel)

$chatInputBox = New-Object System.Windows.Forms.TextBox
$chatInputBox.Location = New-Object System.Drawing.Point(10, 15)
$chatInputBox.Size = New-Object System.Drawing.Size(600, 30)
$chatInputBox.Multiline = $false
$chatInputBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$chatInputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$chatInputBox.BackColor = $White
$inputPanel.Controls.Add($chatInputBox)

$chatSendButton = New-Object System.Windows.Forms.Button
$chatSendButton.Location = New-Object System.Drawing.Point(620, 10)
$chatSendButton.Size = New-Object System.Drawing.Size(110, 40)
$chatSendButton.Text = "Send"
$chatSendButton.BackColor = $PrimaryGreen
$chatSendButton.ForeColor = $White
$chatSendButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$chatSendButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$chatSendButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$inputPanel.Controls.Add($chatSendButton)

# Broadcast Tab Content - Enhanced styling
$broadcastMessageBox = New-Object System.Windows.Forms.RichTextBox
$broadcastMessageBox.Location = New-Object System.Drawing.Point(15, 15)
$broadcastMessageBox.Size = New-Object System.Drawing.Size(740, 490)
$broadcastMessageBox.ReadOnly = $true
$broadcastMessageBox.BackColor = $White
$broadcastMessageBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$broadcastMessageBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$broadcastMessageBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$broadcastTab.Controls.Add($broadcastMessageBox)

# Status label - Colorful and prominent
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(15, 665)
$statusLabel.Size = New-Object System.Drawing.Size(770, 25)
$statusLabel.Text = "Connected"
$statusLabel.ForeColor = $PrimaryGreen
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statusLabel.BackColor = $LightBg
$form.Controls.Add($statusLabel)

# Function to format message - Enhanced with colors
function Format-Message {
    param(
        [string]$Sender,
        [string]$Message,
        [string]$Time,
        [bool]$IsBroadcast = $false
    )
    
    $prefix = if ($IsBroadcast) { "[BROADCAST]" } else { "" }
    $senderLabel = if ($Sender -eq "Support") { "[Support]" } else { "[You]" }
    
    $formatted = "[$Time] $prefix $senderLabel $Sender`: $Message`r`n"
    return $formatted
}

# Function to load chat messages
function Load-ChatMessages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    
    try {
        # Build URL with proper escaping for PowerShell compatibility
        $baseUrl = "$SupabaseUrl/rest/v1/chat_messages"
        $queryParams = "device_hostname=eq.$DeviceHostname" + "&" + "order=timestamp.asc"
        $url = "$baseUrl" + "?" + $queryParams
        $messages = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $chatMessageBox.Clear()
        if ($messages -and $messages.Count -gt 0) {
            foreach ($msg in $messages) {
                $sender = if ($msg.sender -eq "center") { "Support" } else { "You" }
                $time = [DateTime]::Parse($msg.timestamp).ToLocalTime().ToString("HH:mm:ss")
                $formatted = Format-Message -Sender $sender -Message $msg.message -Time $time
                $chatMessageBox.AppendText($formatted)
            }
        } else {
            $chatMessageBox.AppendText("No messages yet. Start a conversation!`r`n")
            $chatMessageBox.SelectionColor = $PrimaryBlue
        }
        $chatMessageBox.SelectionStart = $chatMessageBox.Text.Length
        $chatMessageBox.ScrollToCaret()
        $statusLabel.Text = "Connected - Ready to chat"
        $statusLabel.ForeColor = $PrimaryGreen
    } catch {
        $statusLabel.Text = "Error loading messages: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    }
}

# Function to load broadcast messages - Enhanced with colorful status icons
function Load-BroadcastMessages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
    }
    
    try {
        # Build URL with proper escaping for PowerShell compatibility
        $baseUrl = "$SupabaseUrl/rest/v1/device_commands"
        $queryParams = "device_hostname=eq.$DeviceHostname" + "&" + "command_type=eq.broadcast_message" + "&" + "order=created_at.desc" + "&" + "limit=50"
        $url = "$baseUrl" + "?" + $queryParams
        $messages = Invoke-RestMethod -Uri $url -Method GET -Headers $headers
        
        $broadcastMessageBox.Clear()
        if ($messages -and $messages.Count -gt 0) {
            foreach ($msg in $messages) {
                if ($msg.message) {
                    $time = [DateTime]::Parse($msg.created_at).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
                    $status = $msg.status
                    $statusText = switch ($status) {
                        "pending" { "[PENDING]" }
                        "dismissed" { "[DISMISSED]" }
                        "expired" { "[EXPIRED]" }
                        default { "[NEW]" }
                    }
                    $formatted = "[$time] $statusText $($msg.message)`r`n"
                    $broadcastMessageBox.AppendText($formatted)
                }
            }
        } else {
            $broadcastMessageBox.AppendText("No broadcast messages yet.`r`n")
            $broadcastMessageBox.SelectionColor = $PrimaryBlue
        }
        $broadcastMessageBox.SelectionStart = $broadcastMessageBox.Text.Length
        $broadcastMessageBox.ScrollToCaret()
    } catch {
        $statusLabel.Text = "Error loading broadcast messages: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
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
        $statusLabel.Text = "Message sent successfully"
        $statusLabel.ForeColor = $PrimaryGreen
    } catch {
        $statusLabel.Text = "Error sending message: $_"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    }
}

# Event handlers
$chatSendButton.Add_Click({ Send-ChatMessage })
$chatInputBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Send-ChatMessage
    }
})

# Add hover effects to button
$chatSendButton.Add_MouseEnter({
    $chatSendButton.BackColor = [System.Drawing.Color]::FromArgb(85, 150, 60)
})
$chatSendButton.Add_MouseLeave({
    $chatSendButton.BackColor = $PrimaryGreen
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
