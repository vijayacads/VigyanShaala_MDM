# Test Tamper Detection Script
# Simulates various tampering scenarios to test MDM bypass detection
# Run as Administrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("stop-task", "stop-service", "block-network", "restore-all", "check-status")]
    [string]$TestType = "check-status"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tamper Detection Test Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

$hostname = $env:COMPUTERNAME
Write-Host "Device: $hostname" -ForegroundColor White
Write-Host ""

switch ($TestType) {
    "stop-task" {
        Write-Host "TEST: Stopping scheduled task (simulates user disabling MDM)..." -ForegroundColor Yellow
        Write-Host ""
        
        $taskName = "VigyanShaala-MDM-SendOsqueryData"
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop
                Write-Host "✓ Task stopped: $taskName" -ForegroundColor Green
                Write-Host ""
                Write-Host "WHAT TO EXPECT:" -ForegroundColor Cyan
                Write-Host "  - Device will stop sending data to server" -ForegroundColor White
                Write-Host "  - After 10-15 minutes, device should appear offline in dashboard" -ForegroundColor White
                Write-Host "  - Tamper event should be created in tamper_events table" -ForegroundColor White
                Write-Host ""
                Write-Host "TO RESTORE: Run with -TestType restore-all" -ForegroundColor Yellow
            } else {
                Write-Host "✗ Task not found: $taskName" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ Error: $_" -ForegroundColor Red
        }
    }
    
    "stop-service" {
        Write-Host "TEST: Stopping osquery service (simulates user disabling osquery)..." -ForegroundColor Yellow
        Write-Host ""
        
        $serviceName = "osqueryd"
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $serviceName -ErrorAction Stop
                Write-Host "✓ Service stopped: $serviceName" -ForegroundColor Green
                Write-Host ""
                Write-Host "WHAT TO EXPECT:" -ForegroundColor Cyan
                Write-Host "  - osquery will stop collecting data" -ForegroundColor White
                Write-Host "  - Device will stop sending data to server" -ForegroundColor White
                Write-Host "  - After 10-15 minutes, device should appear offline" -ForegroundColor White
                Write-Host "  - Tamper event should be created" -ForegroundColor White
                Write-Host ""
                Write-Host "TO RESTORE: Run with -TestType restore-all" -ForegroundColor Yellow
            } else {
                Write-Host "✗ Service not found: $serviceName" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ Error: $_" -ForegroundColor Red
        }
    }
    
    "block-network" {
        Write-Host "TEST: Blocking network access to Supabase (simulates firewall block)..." -ForegroundColor Yellow
        Write-Host ""
        
        $supabaseUrl = $env:SUPABASE_URL
        if (-not $supabaseUrl) {
            Write-Host "ERROR: SUPABASE_URL environment variable not set" -ForegroundColor Red
            Write-Host "Please set it first: `$env:SUPABASE_URL = 'https://your-project.supabase.co'" -ForegroundColor Yellow
            exit 1
        }
        
        # Extract domain from URL
        $domain = ([System.Uri]$supabaseUrl).Host
        
        try {
            # Check if rule already exists
            $existingRule = Get-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" -ErrorAction SilentlyContinue
            if ($existingRule) {
                Write-Host "⚠ Firewall rule already exists. Removing old rule..." -ForegroundColor Yellow
                Remove-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" -ErrorAction SilentlyContinue
            }
            
            # Create blocking rule
            New-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" `
                -Direction Outbound `
                -RemoteAddress $domain `
                -Action Block `
                -Enabled True | Out-Null
            
            Write-Host "✓ Network blocked: $domain" -ForegroundColor Green
            Write-Host ""
            Write-Host "WHAT TO EXPECT:" -ForegroundColor Cyan
            Write-Host "  - Device cannot connect to Supabase" -ForegroundColor White
            Write-Host "  - Device will stop sending data to server" -ForegroundColor White
            Write-Host "  - After 10-15 minutes, device should appear offline" -ForegroundColor White
            Write-Host "  - Tamper event should be created" -ForegroundColor White
            Write-Host ""
            Write-Host "TO RESTORE: Run with -TestType restore-all" -ForegroundColor Yellow
        } catch {
            Write-Host "✗ Error: $_" -ForegroundColor Red
            Write-Host "  Make sure you're running as Administrator" -ForegroundColor Yellow
        }
    }
    
    "restore-all" {
        Write-Host "RESTORING: Restoring all MDM components..." -ForegroundColor Yellow
        Write-Host ""
        
        # Restore scheduled task
        $taskName = "VigyanShaala-MDM-SendOsqueryData"
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                Write-Host "✓ Task started: $taskName" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Could not start task: $_" -ForegroundColor Yellow
        }
        
        # Restore service
        $serviceName = "osqueryd"
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Start-Service -Name $serviceName -ErrorAction SilentlyContinue
                Write-Host "✓ Service started: $serviceName" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Could not start service: $_" -ForegroundColor Yellow
        }
        
        # Remove firewall rule
        try {
            $rule = Get-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" -ErrorAction SilentlyContinue
            if ($rule) {
                Remove-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" -ErrorAction Stop
                Write-Host "✓ Firewall rule removed" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Could not remove firewall rule: $_" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "✓ All components restored!" -ForegroundColor Green
        Write-Host "  Device should start sending data again within 5-10 minutes" -ForegroundColor White
    }
    
    "check-status" {
        Write-Host "CURRENT STATUS:" -ForegroundColor Cyan
        Write-Host ""
        
        # Check scheduled tasks
        Write-Host "Scheduled Tasks:" -ForegroundColor Yellow
        $tasks = Get-ScheduledTask -TaskName "VigyanShaala-MDM-*" -ErrorAction SilentlyContinue
        if ($tasks) {
            foreach ($task in $tasks) {
                $info = Get-ScheduledTaskInfo -TaskName $task.TaskName
                $status = if ($task.State -eq "Running") { "✓ RUNNING" } 
                         elseif ($task.State -eq "Ready") { "⚠ READY (not running)" }
                         else { "✗ $($task.State)" }
                $color = if ($task.State -eq "Running") { "Green" } else { "Yellow" }
                Write-Host "  $($task.TaskName): " -NoNewline
                Write-Host $status -ForegroundColor $color
                if ($info.LastRunTime) {
                    Write-Host "    Last Run: $($info.LastRunTime)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  ✗ No MDM tasks found" -ForegroundColor Red
        }
        Write-Host ""
        
        # Check service
        Write-Host "Services:" -ForegroundColor Yellow
        $service = Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.Status -eq "Running") { "✓ RUNNING" } else { "✗ $($service.Status)" }
            $color = if ($service.Status -eq "Running") { "Green" } else { "Red" }
            Write-Host "  osqueryd: " -NoNewline
            Write-Host $status -ForegroundColor $color
        } else {
            Write-Host "  ✗ osqueryd service not found" -ForegroundColor Red
        }
        Write-Host ""
        
        # Check firewall rules
        Write-Host "Firewall Rules:" -ForegroundColor Yellow
        $rule = Get-NetFirewallRule -DisplayName "MDM-Test-Block-Supabase" -ErrorAction SilentlyContinue
        if ($rule) {
            Write-Host "  ✗ BLOCKING RULE ACTIVE: MDM-Test-Block-Supabase" -ForegroundColor Red
            Write-Host "    Network access to Supabase is blocked!" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ No blocking rules found" -ForegroundColor Green
        }
        Write-Host ""
        
        Write-Host "USAGE:" -ForegroundColor Cyan
        Write-Host "  .\test-tamper-detection.ps1 -TestType stop-task      # Stop scheduled task" -ForegroundColor White
        Write-Host "  .\test-tamper-detection.ps1 -TestType stop-service    # Stop osquery service" -ForegroundColor White
        Write-Host "  .\test-tamper-detection.ps1 -TestType block-network  # Block network access" -ForegroundColor White
        Write-Host "  .\test-tamper-detection.ps1 -TestType restore-all    # Restore everything" -ForegroundColor White
        Write-Host "  .\test-tamper-detection.ps1 -TestType check-status    # Check current status" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

