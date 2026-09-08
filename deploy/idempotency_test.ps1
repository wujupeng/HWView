$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
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

# Record count before restart
Write-Host "=== Before restart ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "Records before: $result" -ForegroundColor Green

# Restart collector
Write-Host "`n=== Restart collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl restart hwview-collector 2>&1 && echo 'Restarted'"
Write-Host $result -ForegroundColor Green

# Wait for tick
Write-Host "`nWaiting 30s..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Check logs
Write-Host "=== Collector logs after restart ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '35 sec ago' --no-pager 2>&1"
Write-Host $result -ForegroundColor Yellow

# Record count after restart
Write-Host "`n=== After restart ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "Records after: $result" -ForegroundColor Green

# Check for duplicates
Write-Host "`n=== Duplicate check ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT barcode, count(*) as cnt FROM TBL_PRODUCTION_RECORD GROUP BY barcode HAVING cnt > 1;'"
Write-Host "Duplicates: $result" -ForegroundColor Green

# Cursor check
Write-Host "`n=== Cursor ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
Write-Host $result -ForegroundColor Green

# All records summary
Write-Host "`n=== Record summary ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) as total, count(DISTINCT barcode) as unique_barcodes, count(DISTINCT source_id) as unique_source_ids, min(created_at) as earliest, max(created_at) as latest FROM TBL_PRODUCTION_RECORD;'"
Write-Host $result -ForegroundColor Green

# Statistics
Write-Host "`n=== Statistics (09-07) ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s 'http://localhost:8080/api/v1/statistics/lines/HW102-COPY?date=2026-09-07'"
Write-Host $result -ForegroundColor Green

Write-Host "`n=== Idempotency test complete ===" -ForegroundColor Cyan