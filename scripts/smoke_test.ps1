# Smoke test: auth + threads + messages + length + RLS isolation
$ErrorActionPreference = 'Stop'

$base = 'https://hwfgytocskiovcqyxpwf.supabase.co'
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw'

function Sign-In([string]$email, [string]$password) {
  $auth = Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" -Headers @{
    apikey = $anon
    'Content-Type' = 'application/json'
  } -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  return $auth
}

Write-Host '1) Sign in learner'
$learner = Sign-In 'learner@deskline.app' 'DemoChat123!'
$learnerHeaders = @{
  apikey = $anon
  Authorization = "Bearer $($learner.access_token)"
  'Content-Type' = 'application/json'
  Prefer = 'return=representation'
}
Write-Host "   OK user=$($learner.user.id)"

Write-Host '2) Sign in mentor'
$mentor = Sign-In 'mentor@deskline.app' 'DemoChat123!'
$mentorHeaders = @{
  apikey = $anon
  Authorization = "Bearer $($mentor.access_token)"
  'Content-Type' = 'application/json'
  Prefer = 'return=representation'
}
Write-Host "   OK user=$($mentor.user.id)"

Write-Host '3) Learner lists threads'
$threads = Invoke-RestMethod -Uri "$base/rest/v1/threads?select=id,title&order=updated_at.desc" -Headers $learnerHeaders
if ($threads.Count -lt 1) { throw 'Learner should see at least one thread' }
$threadId = $threads[0].id
Write-Host "   OK threads=$($threads.Count) first=$threadId"

Write-Host '4) Mentor sees the same thread'
$mThreads = Invoke-RestMethod -Uri "$base/rest/v1/threads?select=id&id=eq.$threadId" -Headers $mentorHeaders
if ($mThreads.Count -ne 1) { throw 'Mentor missing seeded thread' }
Write-Host '   OK'

Write-Host '5) Load history'
$history = Invoke-RestMethod -Uri "$base/rest/v1/messages?select=id,body,sender_id&thread_id=eq.$threadId&order=created_at.asc" -Headers $learnerHeaders
Write-Host "   OK messages=$($history.Count)"

Write-Host '6) Learner sends a message'
$bodyText = "Smoke ping $(Get-Date -Format o)"
$sent = Invoke-RestMethod -Method Post -Uri "$base/rest/v1/messages" -Headers $learnerHeaders -Body (@{
  thread_id = $threadId
  sender_id = $learner.user.id
  body = $bodyText
} | ConvertTo-Json)
if ($sent[0].body -ne $bodyText) { throw 'Insert body mismatch' }
Write-Host "   OK id=$($sent[0].id)"

Write-Host '7) Mentor reads the new message'
$seen = Invoke-RestMethod -Uri "$base/rest/v1/messages?select=id,body&id=eq.$($sent[0].id)" -Headers $mentorHeaders
if ($seen.Count -ne 1) { throw 'Mentor cannot read learner message' }
Write-Host '   OK'

Write-Host '8) Reject over-long body'
$tooLong = 'x' * 501
try {
  Invoke-RestMethod -Method Post -Uri "$base/rest/v1/messages" -Headers $learnerHeaders -Body (@{
    thread_id = $threadId
    sender_id = $learner.user.id
    body = $tooLong
  } | ConvertTo-Json) | Out-Null
  throw 'Expected length check to fail'
} catch {
  if ($_.Exception.Message -match 'Expected length') { throw }
  Write-Host '   OK length rejected'
}

Write-Host '9) Stranger signup cannot read seeded thread'
$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$strangerEmail = "stranger+$stamp@deskline.app"
$signup = Invoke-RestMethod -Method Post -Uri "$base/auth/v1/signup" -Headers @{
  apikey = $anon
  'Content-Type' = 'application/json'
} -Body (@{ email = $strangerEmail; password = 'StrangerChat123!' } | ConvertTo-Json)
$token = $signup.access_token
if (-not $token) {
  $login = Sign-In $strangerEmail 'StrangerChat123!'
  $token = $login.access_token
}
$strangerHeaders = @{
  apikey = $anon
  Authorization = "Bearer $token"
}
$isolated = Invoke-RestMethod -Uri "$base/rest/v1/threads?select=id&id=eq.$threadId" -Headers $strangerHeaders
if ($isolated.Count -ne 0) { throw 'RLS failed: stranger saw private thread' }
$isolatedMsgs = Invoke-RestMethod -Uri "$base/rest/v1/messages?select=id&thread_id=eq.$threadId" -Headers $strangerHeaders
if ($isolatedMsgs.Count -ne 0) { throw 'RLS failed: stranger saw private messages' }
Write-Host '   OK stranger isolated'

Write-Host 'SMOKE TEST PASSED'
