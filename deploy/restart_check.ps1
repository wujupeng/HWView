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

# Check if collector is still running
Write-Host "=== Collector process ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl status hwview-collector --no-pager -l 2>&1 | head -15"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Get ALL collector logs (not just recent)
Write-Host "`n=== All collector logs (last 30) ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector -n 30 --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Restart collector and watch logs in real-time
Write-Host "`n=== Restarting collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl restart hwview-collector 2>&1 && echo 'Restarted'"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "Waiting 15s for tick..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# Get logs immediately after restart
Write-Host "`n=== Logs after restart ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector -n 30 --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check DB
Write-Host "`n=== DB check ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
if ($result) { Write-Host "Records: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
if ($result) { Write-Host "Cursor: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, status, last_success_at, last_error_at FROM TBL_DATA_SOURCE;'"
if ($result) { Write-Host "Source: $result" -ForegroundColor Green }

Write-Host "`n=== Done ===" -ForegroundColor Cyan