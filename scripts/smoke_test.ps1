# End to end backend test against the hosted project. Uses only the public anon key
# and the demo accounts. Creates two throwaway learners per run and talks to the
# unlisted "QA Mentor" so demo inboxes stay clean.
#
#   powershell -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
$ErrorActionPreference = 'Stop'

$base = 'https://hwfgytocskiovcqyxpwf.supabase.co'
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw'
$demoPassword = 'DemoChat123!'

$script:passed = 0
$script:failed = @()

function Check([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) {
    $script:passed++
    Write-Host "  PASS  $name" -ForegroundColor Green
  } else {
    $script:failed += $name
    Write-Host "  FAIL  $name  $detail" -ForegroundColor Red
  }
}

function Api([string]$method, [string]$path, $token, $body = $null) {
  $headers = @{ apikey = $anon; 'Content-Type' = 'application/json'; Prefer = 'return=representation' }
  if ($token) { $headers.Authorization = "Bearer $token" }
  $params = @{ Method = $method; Uri = "$base$path"; Headers = $headers }
  if ($null -ne $body) {
    $json = $body | ConvertTo-Json -Depth 6 -Compress
    $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
  }
  try {
    $data = Invoke-RestMethod @params
    return [pscustomobject]@{ ok = $true; data = $data; code = $null; hint = $null; message = $null }
  } catch {
    $raw = $_.ErrorDetails.Message
    if (-not $raw -and $_.Exception.Response) {
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $raw = $reader.ReadToEnd()
      } catch {}
    }
    $err = $null
    try { $err = $raw | ConvertFrom-Json } catch {}
    return [pscustomobject]@{
      ok = $false; data = $null
      code = $err.code; hint = $err.hint
      message = if ($err.message) { $err.message } elseif ($err.msg) { $err.msg } else { $raw }
    }
  }
}

function Rpc([string]$fn, $token, $params = @{}) { Api 'Post' "/rest/v1/rpc/$fn" $token $params }

function SignIn([string]$email, [string]$password) {
  $r = Api 'Post' '/auth/v1/token?grant_type=password' $null @{ email = $email; password = $password }
  if (-not $r.ok) { throw "Sign in failed for ${email}: $($r.message)" }
  return $r.data
}

function SignUp([string]$email, [string]$password, [string]$name) {
  $r = Api 'Post' '/auth/v1/signup' $null @{ email = $email; password = $password; data = @{ display_name = $name } }
  if (-not $r.ok) { throw "Sign up failed for ${email}: $($r.message)" }
  if ($r.data.access_token) { return $r.data }
  return SignIn $email $password
}

# The leading comma stops PowerShell from unwrapping one element arrays.
function Rows($r) { if ($null -eq $r.data) { return ,@() } return ,@($r.data) }

$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

Write-Host "`n[1] Demo accounts sign in"
$ava = SignIn 'learner@deskline.app' $demoPassword
$noah = SignIn 'mentor@deskline.app' $demoPassword
$sam = SignIn 'moderator@deskline.app' $demoPassword
$qa = SignIn 'qa.mentor@deskline.app' $demoPassword
Check 'learner, mentor, moderator, QA mentor sign in' ($ava.access_token -and $noah.access_token -and $sam.access_token -and $qa.access_token)

Write-Host "`n[2] Sign up creates a learner profile"
$learnerName = "Test Learner $stamp"
$lr = SignUp "smoke.learner+$stamp@deskline.app" 'SmokeTest123!' $learnerName
$L = $lr.access_token; $Lid = $lr.user.id
$me = Rows (Api 'Get' "/rest/v1/profiles?select=id,display_name,role&id=eq.$Lid" $L)
Check 'profile row exists after signup' ($me.Count -eq 1)
Check 'display name comes from signup form' ($me[0].display_name -eq $learnerName)
Check 'new accounts are learners' ($me[0].role -eq 'learner')

Write-Host "`n[3] Profile edits and role lockdown"
$r = Api 'Patch' "/rest/v1/profiles?id=eq.$Lid" $L @{ role = 'moderator' }
$after = Rows (Api 'Get' "/rest/v1/profiles?select=role&id=eq.$Lid" $L)
Check 'cannot promote own role' ((-not $r.ok) -and $after[0].role -eq 'learner') $r.message
$r = Api 'Patch' "/rest/v1/profiles?id=eq.$Lid" $L @{ muted_until = $null; listed = $false }
Check 'cannot edit moderation columns' (-not $r.ok)
$r = Api 'Patch' "/rest/v1/profiles?id=eq.$Lid" $L @{ display_name = "$learnerName X" }
Check 'can edit own display name' ($r.ok -and (Rows $r)[0].display_name -eq "$learnerName X")
$avaId = $ava.user.id
$r = Api 'Patch' "/rest/v1/profiles?id=eq.$avaId" $L @{ display_name = 'Hacked' }
$avaRow = Rows (Api 'Get' "/rest/v1/profiles?select=display_name&id=eq.$avaId" $L)
Check "cannot edit someone else's profile" ($avaRow[0].display_name -ne 'Hacked')
$r = Api 'Patch' "/rest/v1/profiles?id=eq.$Lid" $L @{ display_name = 'x' }
Check 'display name length enforced' (-not $r.ok)

Write-Host "`n[4] Mentor directory"
$mentors = Rows (Api 'Get' '/rest/v1/profiles?select=id,display_name&role=eq.mentor&listed=eq.true' $L)
$names = $mentors | ForEach-Object { $_.display_name }
Check 'listed mentors visible' (($names -contains 'Noah Kim') -and ($names -contains 'Iris Chen'))
Check 'unlisted QA mentor hidden from directory' (-not ($names -contains 'QA Mentor'))

Write-Host "`n[5] Start a conversation"
$qaId = $qa.user.id
$r = Rpc 'start_thread' $L @{ p_mentor = $qaId; p_title = "Smoke $stamp"; p_first_message = 'First question from the smoke test' }
Check 'learner can start a thread' $r.ok $r.message
$threadId = $r.data
$r = Rpc 'start_thread' $L @{ p_mentor = $qaId; p_title = 'ab' }
Check 'topic length enforced' ((-not $r.ok) -and $r.message -match 'Topic')
$r = Rpc 'start_thread' $L @{ p_mentor = $avaId; p_title = 'Not a mentor' }
Check 'cannot start a thread with a non mentor' (-not $r.ok)
$r = Rpc 'start_thread' $noah.access_token @{ p_mentor = $qaId; p_title = 'Mentor tries' }
Check 'mentors cannot start threads' ((-not $r.ok) -and $r.message -match 'Only learners')
$r = Api 'Post' '/rest/v1/threads' $L @{ title = 'Direct insert' }
Check 'direct thread insert blocked' (-not $r.ok)

Write-Host "`n[6] Inbox RPC and unread counts"
$mine = Rows (Rpc 'my_threads' $L)
Check 'learner inbox shows the new thread' (@($mine | Where-Object { $_.id -eq $threadId }).Count -eq 1)
$qaInbox = (Rows (Rpc 'my_threads' $qa.access_token)) | Where-Object { $_.id -eq $threadId }
Check 'mentor inbox shows thread with learner as peer' ($qaInbox.peer_id -eq $Lid)
Check 'mentor has 1 unread' ($qaInbox.unread_count -eq 1) "got $($qaInbox.unread_count)"
Check 'learner has 0 unread for own message' ((($mine | Where-Object { $_.id -eq $threadId }).unread_count) -eq 0)
$r = Rpc 'mark_thread_read' $qa.access_token @{ p_thread = $threadId }
$qaInbox = (Rows (Rpc 'my_threads' $qa.access_token)) | Where-Object { $_.id -eq $threadId }
Check 'mark_thread_read clears unread' ($r.ok -and $qaInbox.unread_count -eq 0)

Write-Host "`n[7] Messaging and history"
$r = Api 'Post' '/rest/v1/messages' $qa.access_token @{ thread_id = $threadId; sender_id = $qaId; body = 'Mentor reply from smoke test' }
Check 'mentor can reply' $r.ok $r.message
$mentorMsgId = (Rows $r)[0].id
$hist = Rows (Api 'Get' "/rest/v1/messages?select=id,body,sender_id&thread_id=eq.$threadId&order=created_at.asc" $L)
Check 'history loads in order' ($hist.Count -eq 2 -and $hist[1].body -eq 'Mentor reply from smoke test')
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $qaId; body = 'Spoofed sender' }
Check 'cannot send as someone else' (-not $r.ok)
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = ('x' * 501) }
Check 'over 500 characters rejected' (-not $r.ok)
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = '     ' }
Check 'blank message rejected' (-not $r.ok)
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = '  padded text  ' }
Check 'body is trimmed server side' ($r.ok -and (Rows $r)[0].body -eq 'padded text')
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = 'padded text' }
Check 'duplicate within 30s rejected' ((-not $r.ok) -and $r.hint -eq 'duplicate') $r.message
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = 'Backdated'; created_at = '2000-01-01T00:00:00Z' }
Check 'client cannot backdate created_at' ($r.ok -and ([datetime](Rows $r)[0].created_at).Year -gt 2000)
$r = Api 'Patch' "/rest/v1/messages?id=eq.$mentorMsgId" $qa.access_token @{ body = 'edited' }
$check = Rows (Api 'Get' "/rest/v1/messages?select=body&id=eq.$mentorMsgId" $qa.access_token)
Check 'messages cannot be edited through the API' ($check[0].body -eq 'Mentor reply from smoke test')
$r = Api 'Delete' "/rest/v1/messages?id=eq.$mentorMsgId" $qa.access_token
$check = Rows (Api 'Get' "/rest/v1/messages?select=id&id=eq.$mentorMsgId" $qa.access_token)
Check 'messages cannot be deleted through the API' ($check.Count -eq 1)

Write-Host "`n[8] Rate limit"
$limited = $false
for ($i = 0; $i -lt 8; $i++) {
  $r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = "burst $i $stamp" }
  if (-not $r.ok -and $r.hint -eq 'rate_limited') { $limited = $true; break }
}
Check 'burst of messages hits the 5 per 10s cap' $limited
Write-Host '      waiting 11s for the window to clear'
Start-Sleep -Seconds 11

Write-Host "`n[9] Thread status"
$r = Rpc 'set_thread_status' $qa.access_token @{ p_thread = $threadId; p_status = 'resolved' }
$st = Rows (Api 'Get' "/rest/v1/threads?select=status&id=eq.$threadId" $L)
Check 'participant can resolve' ($r.ok -and $st[0].status -eq 'resolved')
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = "One more question $stamp" }
$reportTarget = (Rows $r)[0].id
$st = Rows (Api 'Get' "/rest/v1/threads?select=status&id=eq.$threadId" $L)
Check 'new message reopens a resolved thread' ($r.ok -and $st[0].status -eq 'open')

Write-Host "`n[10] RLS isolation with a stranger"
$sr = SignUp "smoke.stranger+$stamp@deskline.app" 'SmokeTest123!' "Stranger $stamp"
$S = $sr.access_token; $Sid = $sr.user.id
Check 'stranger sees no thread' ((Rows (Api 'Get' "/rest/v1/threads?select=id&id=eq.$threadId" $S)).Count -eq 0)
Check 'stranger sees no messages' ((Rows (Api 'Get' "/rest/v1/messages?select=id&thread_id=eq.$threadId" $S)).Count -eq 0)
Check 'stranger sees no participants' ((Rows (Api 'Get' "/rest/v1/thread_participants?select=user_id&thread_id=eq.$threadId" $S)).Count -eq 0)
Check 'stranger inbox is empty' ((Rows (Rpc 'my_threads' $S)).Count -eq 0)
$r = Api 'Post' '/rest/v1/messages' $S @{ thread_id = $threadId; sender_id = $Sid; body = 'let me in' }
Check 'stranger cannot post into the thread' (-not $r.ok)
$r = Api 'Post' '/rest/v1/thread_participants' $S @{ thread_id = $threadId; user_id = $Sid }
Check 'stranger cannot join the thread' (-not $r.ok)
$r = Rpc 'set_thread_status' $S @{ p_thread = $threadId; p_status = 'resolved' }
Check 'stranger cannot change status' (-not $r.ok)
$r = Rpc 'report_message' $S @{ p_message = $reportTarget; p_reason = 'spam' }
Check 'stranger cannot report messages they cannot see' (-not $r.ok)
$r = Rpc 'moderation_stats' $S
Check 'non moderators blocked from moderation RPCs' ((-not $r.ok) -and $r.message -match 'Moderators only')
$avaThreads = Rows (Rpc 'my_threads' $ava.access_token)
$crossRead = Rows (Api 'Get' "/rest/v1/messages?select=id&thread_id=eq.$($avaThreads[0].id)" $L)
Check "learner cannot read another learner's thread" ($crossRead.Count -eq 0)
$anonRead = Api 'Get' '/rest/v1/messages?select=id&limit=1' $null
Check 'anonymous clients read nothing' ((-not $anonRead.ok) -or ((Rows $anonRead).Count -eq 0))

Write-Host "`n[11] Report flow"
$r = Rpc 'report_message' $qa.access_token @{ p_message = $reportTarget; p_reason = 'spam'; p_note = 'Smoke test report' }
Check 'participant can report a message' $r.ok $r.message
$reportId = $r.data
$r = Rpc 'report_message' $qa.access_token @{ p_message = $reportTarget; p_reason = 'spam' }
Check 'same message cannot be reported twice by one person' ((-not $r.ok) -and $r.hint -eq 'duplicate')
$r = Rpc 'report_message' $L @{ p_message = $reportTarget; p_reason = 'spam' }
Check 'cannot report your own message' (-not $r.ok)
$r = Rpc 'report_message' $L @{ p_message = $mentorMsgId; p_reason = 'nonsense' }
Check 'unknown reason rejected' (-not $r.ok)
Check 'reporter can see own report' ((Rows (Api 'Get' "/rest/v1/message_reports?select=id&id=eq.$reportId" $qa.access_token)).Count -eq 1)
Check 'reported user cannot see the report' ((Rows (Api 'Get' "/rest/v1/message_reports?select=id&id=eq.$reportId" $L)).Count -eq 0)

Write-Host "`n[12] Moderation panel"
$SAM = $sam.access_token
$stats = Rpc 'moderation_stats' $SAM
Check 'moderator loads stats' ($stats.ok -and $stats.data.open_reports -ge 1)
$queue = Rows (Rpc 'moderation_queue' $SAM @{ p_status = 'open' })
$item = $queue | Where-Object { $_.report_id -eq $reportId }
Check 'report appears in queue with context' ($item -and @($item.context).Count -ge 2 -and $item.message_body -eq "One more question $stamp")
$r = Rpc 'moderate_report' $L @{ p_report = $reportId; p_action = 'dismiss' }
Check 'learner cannot moderate' (-not $r.ok)
$r = Rpc 'moderate_report' $SAM @{ p_report = $reportId; p_action = 'remove_and_mute' }
Check 'moderator removes and mutes' $r.ok $r.message
$msg = Rows (Api 'Get' "/rest/v1/messages?select=body,hidden_at&id=eq.$reportTarget" $qa.access_token)
Check 'message body replaced for participants' ($msg[0].body -eq 'Removed by a moderator.' -and $msg[0].hidden_at)
$queueAll = (Rows (Rpc 'moderation_queue' $SAM @{ p_status = 'all' })) | Where-Object { $_.report_id -eq $reportId }
Check 'moderator still sees the original text' ($queueAll.message_body -eq "One more question $stamp" -and $queueAll.status -eq 'actioned')
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = "Am I muted $stamp" }
Check 'muted user cannot send' ((-not $r.ok) -and $r.hint -eq 'muted') $r.message
$r = Rpc 'start_thread' $L @{ p_mentor = $qaId; p_title = 'Muted attempt' }
Check 'muted user cannot open threads' (-not $r.ok)
$muted = Rows (Rpc 'muted_users' $SAM)
Check 'muted list includes the user' (@($muted | Where-Object { $_.id -eq $Lid }).Count -eq 1)
$r = Rpc 'unmute_user' $SAM @{ p_user = $Lid }
Check 'moderator can unmute' $r.ok
$r = Api 'Post' '/rest/v1/messages' $L @{ thread_id = $threadId; sender_id = $Lid; body = "Back again $stamp" }
Check 'unmuted user can send again' $r.ok $r.message
$log = Rows (Rpc 'moderation_log' $SAM @{ p_limit = 20 })
$actions = $log | ForEach-Object { $_.action }
Check 'log records remove, mute, unmute' (($actions -contains 'remove_message') -and ($actions -contains 'mute_user') -and ($actions -contains 'unmute_user'))
Check 'learners cannot read the moderation log table' ((Rows (Api 'Get' '/rest/v1/moderation_actions?select=id' $L)).Count -eq 0)

Write-Host ''
Write-Host "Passed: $script:passed   Failed: $($script:failed.Count)"
if ($script:failed.Count -gt 0) {
  Write-Host 'Failures:' -ForegroundColor Red
  $script:failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'SMOKE TEST PASSED' -ForegroundColor Green
