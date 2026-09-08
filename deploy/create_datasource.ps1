$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"
$sudopw = $pw

function Invoke-Remote {
    param([string]$Command, [int]$TimeoutMs = 30000)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $plink
    $psi.Arguments = "-ssh -pw $pw -batch -hostkey $hostkey $target `"$Command`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit($TimeoutMs)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    if (-not $p.HasExited) { $p.Kill() }
    if ($p.ExitCode -ne 0) {
        Write-Host "  ERROR: $stderr" -ForegroundColor Red
        return $null
    }
    return $stdout
}

function Upload-File {
    param([string]$LocalPath, [string]$RemotePath)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pscp
    $psi.Arguments = "-pw $pw -batch -hostkey $hostkey `"$LocalPath`" ${target}:`"$RemotePath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit(60000)
    if (-not $p.HasExited) { $p.Kill() }
    return ($p.ExitCode -eq 0)
}

# Upload and insert data source
Write-Host "=== Creating Data Source ===" -ForegroundColor Cyan
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\insert_datasource.sql" "/tmp/insert_datasource.sql"
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db '.read /tmp/insert_datasource.sql' 2>&1 && echo 'INSERT_OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Verify
Write-Host "`n--- TBL_DATA_SOURCE ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, agent_id, current_ip, port, base_path, enabled, status FROM TBL_DATA_SOURCE;'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check API
Write-Host "`n--- API /sources ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/sources"
if ($result) { Write-Host $result -ForegroundColor Green }

# Restart collector to trigger immediate collection
Write-Host "`n=== Restarting collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl restart hwview-collector 2>&1 && echo 'Restarted'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Wait for collection tick
Write-Host "`n=== Waiting 10s for first tick ===" -ForegroundColor Cyan
Start-Sleep -Seconds 10

# Check collector logs
Write-Host "`n--- Collector logs (last 20) ---" -ForegroundColor Yellow
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '15 sec ago' --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check if records were collected
Write-Host "`n--- TBL_PRODUCTION_RECORD count ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
if ($result) { Write-Host "Count: $result" -ForegroundColor Green }

Write-Host "`n--- TBL_PRODUCTION_RECORD sample ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_PRODUCTION_RECORD LIMIT 5;'"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- TBL_COLLECT_CURSOR ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- TBL_DATA_SOURCE (updated) ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, current_ip, port, base_path, status, last_success_at, last_error_at FROM TBL_DATA_SOURCE;'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Statistics
Write-Host "`n--- Statistics Overview ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n=== Done ===" -ForegroundColor Cyan