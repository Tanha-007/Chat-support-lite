# Create demo auth users (through public signup) and apply supabase/seed.sql.
# Requires SUPABASE_ACCESS_TOKEN for the SQL step.
$ErrorActionPreference = 'Stop'

$base = 'https://hwfgytocskiovcqyxpwf.supabase.co'
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw'
$password = 'DemoChat123!'

$accounts = @(
  @{ email = 'learner@deskline.app'; name = 'Ava Brooks' },
  @{ email = 'mentor@deskline.app'; name = 'Noah Kim' },
  @{ email = 'iris@deskline.app'; name = 'Iris Chen' },
  @{ email = 'moderator@deskline.app'; name = 'Sam Ortiz' },
  @{ email = 'qa.mentor@deskline.app'; name = 'QA Mentor' }
)

foreach ($a in $accounts) {
  try {
    Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" -Headers @{
      apikey = $anon; 'Content-Type' = 'application/json'
    } -Body (@{ email = $a.email; password = $password } | ConvertTo-Json) | Out-Null
    Write-Host "exists   $($a.email)"
  } catch {
    Invoke-RestMethod -Method Post -Uri "$base/auth/v1/signup" -Headers @{
      apikey = $anon; 'Content-Type' = 'application/json'
    } -Body (@{ email = $a.email; password = $password; data = @{ display_name = $a.name } } | ConvertTo-Json) | Out-Null
    Write-Host "created  $($a.email)"
  }
}

& "$PSScriptRoot\run_sql.ps1" -File "$PSScriptRoot\..\supabase\seed.sql"
