$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"
$sudopw = $pw

function Invoke-Remote {
    param([string]$Command, [int]$TimeoutMs = 60000)
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
    $p.WaitForExit(120000)
    if (-not $p.HasExited) { $p.Kill() }
    return ($p.ExitCode -eq 0)
}

# Step 1: Stop collector
Write-Host "=== Step 1: Stop collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl stop hwview-collector 2>&1 && echo 'Stopped'"
Write-Host $result -ForegroundColor Green

# Step 2: Clean DB records and cursor
Write-Host "`n=== Step 2: Clean DB ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'DELETE FROM TBL_PRODUCTION_RECORD; DELETE FROM TBL_COLLECT_CURSOR; UPDATE TBL_DATA_SOURCE SET status=chr(79)||chr(70)||chr(70)||chr(76)||chr(73)||chr(78)||chr(69), last_success_at=NULL, last_error_at=NULL;' 2>&1 && echo 'DB cleaned'"
Write-Host $result -ForegroundColor Green

# Step 3: Upload new binary
Write-Host "`n=== Step 3: Upload binary ===" -ForegroundColor Cyan
$ok = Upload-File "C:\Users\DELL\IDEProjects\HWView\bin\hwview-collector" "/opt/hwview/bin/hwview-collector"
if ($ok) { Write-Host "  Upload OK" -ForegroundColor Green }

# Step 4: Start collector
Write-Host "`n=== Step 4: Start collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "chmod +x /opt/hwview/bin/hwview-collector && echo $sudopw | sudo -S systemctl start hwview-collector 2>&1 && sleep 2 && echo $sudopw | sudo -S systemctl is-active hwview-collector 2>&1"
Write-Host $result -ForegroundColor Green

# Step 5: Wait for collection (30 seconds for HTTP fetch + parse)
Write-Host "`n=== Step 5: Waiting 30s ===" -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Step 6: Check logs
Write-Host "`n=== Step 6: Collector logs ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '40 sec ago' --no-pager 2>&1"
Write-Host $result -ForegroundColor Yellow

# Step 7: Check DB
Write-Host "`n=== Step 7: DB Verification ===" -ForegroundColor Cyan

Write-Host "--- Record count ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "Count: $result" -ForegroundColor Green

Write-Host "--- Sample records ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, source_id, barcode, batch_no, quantity, created_at, production_date FROM TBL_PRODUCTION_RECORD LIMIT 5;'"
Write-Host $result -ForegroundColor Green

Write-Host "--- Cursor ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
Write-Host $result -ForegroundColor Green

Write-Host "--- Data source status ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, status, last_success_at FROM TBL_DATA_SOURCE;'"
Write-Host $result -ForegroundColor Green

# Step 8: Statistics
Write-Host "`n=== Step 8: Statistics ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
Write-Host $result -ForegroundColor Green

Write-Host "`n=== Done ===" -ForegroundColor Cyan