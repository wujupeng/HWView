$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
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

# ============================================================
# Part 1: Source Connectivity + Real Data Fetch
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Part 1: Source Connectivity (.110 -> .30.2:86)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Basic TCP connectivity
Write-Host "`n--- TCP port 86 check ---" -ForegroundColor Yellow
$result = Invoke-Remote "timeout 5 bash -c 'echo > /dev/tcp/192.168.30.2/86' 2>&1 && echo 'TCP_OK' || echo 'TCP_FAIL'"
if ($result) { Write-Host $result -ForegroundColor Green }

# curl with connect-timeout
Write-Host "`n--- HTTP connect test ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w 'HTTP_CODE=%{http_code} SIZE=%{size_download} TIME=%{time_total}s' http://192.168.30.2:86/ 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Fetch real production data for 2026-09-07
Write-Host "`n--- Real data fetch: 2026-09-07 ---" -ForegroundColor Yellow
$fetchCmd = "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07+00%3A00%3A00/end_date_time/2026-09-07+23%3A59%3A59' -o /tmp/hwview_0907_now.html 2>&1 && echo 'FETCH_OK' || echo 'FETCH_FAIL'"
$result = Invoke-Remote $fetchCmd
if ($result) { Write-Host $result -ForegroundColor Green }

# Check file size
Write-Host "`n--- File size ---" -ForegroundColor Yellow
$result = Invoke-Remote "wc -c /tmp/hwview_0907_now.html 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check record count
Write-Host "`n--- Record count (Chinese) ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '共[^<]*条记录' /tmp/hwview_0907_now.html 2>&1 || echo 'NO_RECORD_COUNT_FOUND'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check record count (alternative patterns)
Write-Host "`n--- Record count (alt patterns) ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '\d+(?=条)' /tmp/hwview_0907_now.html 2>&1 | head -3 || echo 'NO_MATCH'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check printload links (source_id)
Write-Host "`n--- printload links (source_id) ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hwview_0907_now.html 2>&1 | head -5 || echo 'NO_PRINTLOAD'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check barcodes (DNCPEMCHW pattern)
Write-Host "`n--- Barcodes (DNCPEMCHW) ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hwview_0907_now.html 2>&1 | head -5 || echo 'NO_BARCODE'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check any table rows
Write-Host "`n--- HTML table rows count ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -c '<tr' /tmp/hwview_0907_now.html 2>&1 || echo '0'"
if ($result) { Write-Host "TR count: $result" -ForegroundColor Green }

# First 500 chars of HTML to understand structure
Write-Host "`n--- HTML head (first 500 chars) ---" -ForegroundColor Yellow
$result = Invoke-Remote "head -c 500 /tmp/hwview_0907_now.html 2>&1"
if ($result) { Write-Host $result -ForegroundColor Gray }

# ============================================================
# Part 2: Collector Logs
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Part 2: hwview-collector logs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector -n 100 --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# ============================================================
# Part 3: Server Logs + Health API
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Part 3: hwview-server logs + health API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n--- Server logs (last 50) ---" -ForegroundColor Yellow
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-server -n 50 --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

Write-Host "`n--- API /health ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://127.0.0.1:8080/api/v1/health"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- API /health/sources ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://127.0.0.1:8080/api/v1/health/sources 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- API /health/datasources ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://127.0.0.1:8080/api/v1/health/datasources 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# ============================================================
# Part 4: DB - Check Production Records
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Part 4: DB Production Records" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n--- TBL_PRODUCTION_RECORD count ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;' 2>&1"
if ($result) { Write-Host "Count: $result" -ForegroundColor Green }

Write-Host "`n--- TBL_PRODUCTION_RECORD sample ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_PRODUCTION_RECORD LIMIT 5;' 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- TBL_DATA_SOURCE content ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_DATA_SOURCE;' 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- TBL_COLLECT_CURSOR content ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;' 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n--- TBL_DATA_SOURCE_HEALTH content ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_DATA_SOURCE_HEALTH;' 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# ============================================================
# Part 5: Service Status Summary
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Part 5: Service Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$result = Invoke-Remote "echo $sudopw | sudo -S systemctl is-active hwview-server hwview-collector 2>&1"
if ($result) { Write-Host "Services: $result" -ForegroundColor Green }

$result = Invoke-Remote "ps aux | grep hwview | grep -v grep"
if ($result) { Write-Host $result -ForegroundColor Yellow }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "EVIDENCE COLLECTION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan