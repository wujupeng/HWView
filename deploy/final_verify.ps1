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

# Stop services
Write-Host "=== Stopping services ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl stop hwview-collector hwview-server 2>&1 && echo 'Stopped'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Remove DB (AutoMigrate will recreate)
Write-Host "`n=== Removing old DB ===" -ForegroundColor Cyan
$result = Invoke-Remote "rm -f /opt/hwview/data/hwview.db && echo 'DB removed'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Start server (AutoMigrate creates tables)
Write-Host "`n=== Starting server (AutoMigrate) ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl start hwview-server 2>&1 && sleep 3 && echo $sudopw | sudo -S systemctl is-active hwview-server 2>&1"
if ($result) { Write-Host "Server status: $result" -ForegroundColor Green }

# Create JSON file on remote, then use curl with -d @file
Write-Host "`n=== Creating HW102-COPY via API ===" -ForegroundColor Cyan
$result = Invoke-Remote "cat > /tmp/line.json << 'ENDJSON'`n{`"line_code`":`"HW102-COPY`",`"line_name`":`"Huawei102-Copy-Line`",`"customer`":`"Huawei`",`"product`":`"HW102`",`"adapter_type`":`"Huawei102Adapter`"}`nENDJSON`ncurl -s -X POST http://localhost:8080/api/v1/lines -H 'Content-Type: application/json' -d @/tmp/line.json"
if ($result) { Write-Host "Create result: $result" -ForegroundColor Green }

# Start collector
Write-Host "`n=== Starting collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl start hwview-collector 2>&1 && sleep 2 && echo $sudopw | sudo -S systemctl is-active hwview-collector 2>&1"
if ($result) { Write-Host "Collector status: $result" -ForegroundColor Green }

# Full verification
Write-Host "`n=== Full API Verification ===" -ForegroundColor Cyan

Write-Host "--- Health ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/health"
if ($result) { Write-Host $result }

Write-Host "--- Lines ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host $result }

Write-Host "--- Line HW102-COPY ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines/HW102-COPY"
if ($result) { Write-Host $result }

Write-Host "--- Statistics Overview (Shadow Mode) ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result }

Write-Host "--- Adapters ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/adapters"
if ($result) { Write-Host $result }

# DB verification
Write-Host "`n=== DB Verification ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db '.tables'"
if ($result) { Write-Host "Tables: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_code, line_name, customer, product, adapter_type, status FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Production lines: $result" -ForegroundColor Green }

# Service status
Write-Host "`n=== Service Status ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl is-active hwview-server hwview-collector 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Recent logs
Write-Host "`n=== Recent server logs ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-server --since '1 min ago' --no-pager 2>&1 | tail -5"
if ($result) { Write-Host $result -ForegroundColor Yellow }

Write-Host "`n=== Deployment verification complete ===" -ForegroundColor Cyan