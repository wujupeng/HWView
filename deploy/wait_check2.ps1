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

# Wait 20 more seconds
Write-Host "Waiting 20s..." -ForegroundColor Cyan
Start-Sleep -Seconds 20

# Check collector logs (broader window)
Write-Host "=== Collector logs (last 40) ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector -n 40 --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check DB
Write-Host "`n=== DB ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
if ($result) { Write-Host "Records: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
if ($result) { Write-Host "Cursor: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, source_id, barcode, batch_no, quantity, created_at, production_date FROM TBL_PRODUCTION_RECORD LIMIT 5;'"
if ($result) { Write-Host "Sample: $result" -ForegroundColor Green }

# Check if collector is still running
Write-Host "`n=== Collector status ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl status hwview-collector --no-pager 2>&1 | head -10"
if ($result) { Write-Host $result -ForegroundColor Yellow }

Write-Host "`n=== Done ===" -ForegroundColor Cyan