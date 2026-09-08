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
        Write-Host "  ERROR (exit $($p.ExitCode)): $stderr" -ForegroundColor Red
        return $null
    }
    return $stdout
}

# Stop services first to avoid DB lock
Write-Host "=== Stopping services ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl stop hwview-collector hwview-server 2>&1 && echo 'Services stopped'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Remove existing DB and reinitialize from schema
Write-Host "`n=== Reinitializing DB from schema ===" -ForegroundColor Cyan
$result = Invoke-Remote "rm -f /opt/hwview/data/hwview.db && /usr/bin/sqlite3 /opt/hwview/data/hwview.db < /opt/hwview/deploy/init_schema.sql 2>&1 && echo 'DB initialized OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Verify DB content
Write-Host "`n=== Verifying DB ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db '.tables'"
if ($result) { Write-Host "Tables: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_code, line_name, customer, product, adapter_type, status FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Production lines: $result" -ForegroundColor Green }

# Restart services
Write-Host "`n=== Restarting services ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl start hwview-server 2>&1 && sleep 2 && echo $sudopw | sudo -S systemctl start hwview-collector 2>&1 && sleep 2 && echo 'Services restarted'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Full API verification
Write-Host "`n=== API Verification ===" -ForegroundColor Cyan

Write-Host "--- Health ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/health"
if ($result) { Write-Host $result }

Write-Host "--- Lines ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host $result }

Write-Host "--- Line HW102-COPY ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines/HW102-COPY"
if ($result) { Write-Host $result }

Write-Host "--- Statistics Overview ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result }

Write-Host "--- Adapters ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/adapters"
if ($result) { Write-Host $result }

# Service status
Write-Host "`n=== Service Status ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl is-active hwview-server hwview-collector 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check service logs for errors
Write-Host "`n=== Recent logs ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-server --since '2 min ago' --no-pager 2>&1 | tail -5"
if ($result) { Write-Host "Server logs: $result" -ForegroundColor Yellow }

$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '2 min ago' --no-pager 2>&1 | tail -5"
if ($result) { Write-Host "Collector logs: $result" -ForegroundColor Yellow }

Write-Host "`n=== Verification complete ===" -ForegroundColor Cyan