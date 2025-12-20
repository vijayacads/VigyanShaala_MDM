# One-line cache test command - copy everything after the # comment
# $u="https://ujmcjezpmyvpiasfrwhm.supabase.co";$k="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ";$h=$env:COMPUTERNAME.Trim().ToUpper();$hdr=@{"apikey"=$k;"Authorization"="Bearer $k";"Content-Type"="application/json";"Prefer"="return=representation"};$cmd=@{"device_hostname"=$h;"command_type"="clear_cache";"status"="pending"}|ConvertTo-Json;$r=Invoke-RestMethod -Uri "$u/rest/v1/device_commands" -Method POST -Headers $hdr -Body $cmd;Write-Host "Command created: $($r.id)" -ForegroundColor Green;powershell.exe -ExecutionPolicy Bypass -Command "& 'C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM\osquery-agent\execute-commands.ps1' -SupabaseUrl '$u' -SupabaseKey '$k'";Write-Host "Cache clear executed!" -ForegroundColor Green




