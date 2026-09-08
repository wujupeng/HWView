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

# Wait 15 seconds for tick to complete
Write-Host "Waiting 15s..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# Full collector logs
Write-Host "=== Collector logs (since restart) ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '3 min ago' --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check DB records
Write-Host "`n=== DB Records ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
if ($result) { Write-Host "TBL_PRODUCTION_RECORD count: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
if ($result) { Write-Host "TBL_COLLECT_CURSOR: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, status, last_success_at, last_error_at FROM TBL_DATA_SOURCE;'"
if ($result) { Write-Host "TBL_DATA_SOURCE: $result" -ForegroundColor Green }

# Check if the adapter URL with ?date= actually has parseable records
Write-Host "`n=== Adapter URL content check ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-07&page=1' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | wc -l"
if ($result) { Write-Host "Barcodes in ?date=2026-09-07: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-07&page=1' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | head -3"
if ($result) { Write-Host "Sample: $result" -ForegroundColor Green }

# Check TR count in adapter URL response
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-07&page=1' 2>&1 | grep -c '<tr'"
if ($result) { Write-Host "TR count: $result" -ForegroundColor Green }

Write-Host "`n=== Done ===" -ForegroundColor Cyan