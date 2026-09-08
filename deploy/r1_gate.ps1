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

Write-Host "========== R1 EVIDENCE GATE ==========" -ForegroundColor Cyan

# Deploy
Write-Host "`n=== Deploy ===" -ForegroundColor Cyan
Invoke-Remote "echo $sudopw | sudo -S systemctl stop hwview-collector 2>&1"
Upload-File "C:\Users\DELL\IDEProjects\HWView\bin\hwview-collector" "/opt/hwview/bin/hwview-collector"
Invoke-Remote "chmod +x /opt/hwview/bin/hwview-collector && /usr/bin/sqlite3 /opt/hwview/data/hwview.db 'DELETE FROM TBL_PRODUCTION_RECORD; DELETE FROM TBL_COLLECT_CURSOR;' 2>&1 && echo 'DB cleaned'"
Invoke-Remote "echo $sudopw | sudo -S systemctl start hwview-collector 2>&1"
Write-Host "Started, waiting 30s..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Gate 1: Source TCP/HTTP
Write-Host "`n=== Gate 1: Source Connectivity ===" -ForegroundColor Cyan
$r = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w '%{http_code}' 'http://192.168.30.2:86/Cron/Jili/lists/' 2>&1"
Write-Host "  HTTP status: $r" -ForegroundColor $(if($r -eq '200'){'Green'}else{'Red'})

# Gate 2: Adapter Fetch
Write-Host "`n=== Gate 2: Adapter Fetch ===" -ForegroundColor Cyan
$r = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '35 sec ago' --no-pager 2>&1 | grep 'collect success'"
Write-Host "  $r" -ForegroundColor $(if($r -match 'collect success'){'Green'}else{'Red'})

# Gate 3: Adapter Parse (30 records)
Write-Host "`n=== Gate 3: Parse >= 30 ===" -ForegroundColor Cyan
$r = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
$count = $r.Trim()
Write-Host "  Records: $count" -ForegroundColor $(if([int]$count -ge 30){'Green'}else{'Red'})

# Gate 4: Pagination termination
Write-Host "`n=== Gate 4: Pagination ===" -ForegroundColor Cyan
$r = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '35 sec ago' --no-pager 2>&1 | grep 'tick completed'"
Write-Host "  $r" -ForegroundColor $(if($r -match 'completed'){'Green'}else{'Red'})

# Gate 5: DB INSERT
Write-Host "`n=== Gate 5: DB INSERT ===" -ForegroundColor Cyan
$r = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, source_id, barcode, batch_no, quantity, created_at, production_date FROM TBL_PRODUCTION_RECORD LIMIT 3;'"
Write-Host "  $r" -ForegroundColor Green

# Gate 6: Deduplication
Write-Host "`n=== Gate 6: Dedup ===" -ForegroundColor Cyan
$r = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) - count(DISTINCT barcode) FROM TBL_PRODUCTION_RECORD;'"
$dup = $r.Trim()
Write-Host "  Duplicates: $dup" -ForegroundColor $(if([int]$dup -eq 0){'Green'}else{'Red'})

# Gate 7: Cursor
Write-Host "`n=== Gate 7: Cursor ===" -ForegroundColor Cyan
$r = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT line_id, source_id, last_created_at FROM TBL_COLLECT_CURSOR;'"
Write-Host "  $r" -ForegroundColor Green

# Gate 8: Idempotency (restart)
Write-Host "`n=== Gate 8: Idempotency ===" -ForegroundColor Cyan
$before = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Invoke-Remote "echo $sudopw | sudo -S systemctl restart hwview-collector 2>&1"
Start-Sleep -Seconds 30
$after = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Before: $($before.Trim()) After: $($after.Trim())" -ForegroundColor $(if($before.Trim() -eq $after.Trim()){'Green'}else{'Red'})

# Gate 9: Shadow Statistics
Write-Host "`n=== Gate 9: Shadow Stats ===" -ForegroundColor Cyan
$r = Invoke-Remote "curl -s 'http://localhost:8080/api/v1/statistics/lines/HW102-COPY?date=2026-09-07'"
Write-Host "  $r" -ForegroundColor Green
$shadowOk = $r -match '"shadow_mode":true' -and $r -match 'pending business confirmation'
$shadowStatus = if ($shadowOk) { "PASS" } else { "FAIL" }
Write-Host "  Shadow mode + label: $shadowStatus" -ForegroundColor $(if($shadowOk){'Green'}else{'Red'})

# Gate 10: Quantity FROZEN
Write-Host "`n=== Gate 10: Quantity FROZEN ===" -ForegroundColor Cyan
$r = Invoke-Remote "curl -s 'http://localhost:8080/api/v1/statistics/overview'"
$frozenOk = $r -match '"quantity_label":"pending business confirmation"'
Write-Host "  Quantity label: pending business confirmation" -ForegroundColor $(if($frozenOk){'Green'}else{'Red'})

# Summary
Write-Host "`n========== R1 EVIDENCE SUMMARY ==========" -ForegroundColor Cyan
$r = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) as total, count(DISTINCT barcode) as unique_barcodes, count(DISTINCT batch_no) as batches, sum(quantity) as total_pieces FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  $r" -ForegroundColor Green

$r = Invoke-Remote "echo $sudopw | sudo -S systemctl is-active hwview-server hwview-collector 2>&1"
Write-Host "  Services: $r" -ForegroundColor Green

Write-Host "`n========== R1 GATE COMPLETE ==========" -ForegroundColor Cyan