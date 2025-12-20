# Fix device to use NEW Supabase project
# Run this on the device as Administrator

$NewSupabaseUrl = "https://thqinhphunrflwlshdmx.supabase.co"
$NewSupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"

Write-Host "Setting system environment variables..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("SUPABASE_URL", $NewSupabaseUrl, "Machine")
[Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $NewSupabaseKey, "Machine")

Write-Host "Restarting listener task..." -ForegroundColor Yellow
Stop-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"

Write-Host "Waiting 5 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Checking logs..." -ForegroundColor Yellow
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 10 | Select-String "Connecting to"

Write-Host "Done! Should now show: $NewSupabaseUrl" -ForegroundColor Green


