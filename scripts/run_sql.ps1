# Run a SQL file against the hosted project through the Supabase Management API.
# Usage:
#   $env:SUPABASE_ACCESS_TOKEN = 'sbp_...'
#   powershell -File scripts/run_sql.ps1 supabase/migrations/20260924100000_conversations_moderation.sql
param(
  [Parameter(Mandatory = $true)][string]$File,
  [string]$ProjectRef = 'hwfgytocskiovcqyxpwf'
)
$ErrorActionPreference = 'Stop'

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw 'Set SUPABASE_ACCESS_TOKEN to a personal access token first.'
}

$sql = [System.IO.File]::ReadAllText((Resolve-Path $File))
$result = Invoke-RestMethod -Method Post `
  -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" `
  -Headers @{ Authorization = "Bearer $env:SUPABASE_ACCESS_TOKEN"; 'Content-Type' = 'application/json' } `
  -Body (@{ query = $sql } | ConvertTo-Json -Depth 3)

Write-Host "Applied $File"
if ($result) { $result | ConvertTo-Json -Depth 6 }
