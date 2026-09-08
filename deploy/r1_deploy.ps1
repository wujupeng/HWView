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
    $p.WaitForExit(120000)
    if (-not $p.HasExited) { $p.Kill() }
    return ($p.ExitCode -eq 0)
}

# Step 1: Stop collector
Write-Host "=== Stopping collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl stop hwview-collector 2>&1 && echo 'Stopped'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Step 2: Upload new binary
Write-Host "`n=== Uploading new binary ===" -ForegroundColor Cyan
$ok = Upload-File "C:\Users\DELL\IDEProjects\HWView\bin\hwview-collector" "/opt/hwview/bin/hwview-collector"
if ($ok) { Write-Host "  Upload OK" -ForegroundColor Green } else { Write-Host "  Upload FAILED" -ForegroundColor Red }

# Step 3: Make executable and start
Write-Host "`n=== Starting collector ===" -ForegroundColor Cyan
$result = Invoke-Remote "chmod +x /opt/hwview/bin/hwview-collector && echo $sudopw | sudo -S systemctl start hwview-collector 2>&1 && sleep 2 && echo $sudopw | sudo -S systemctl is-active hwview-collector 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Step 4: Wait for first collection tick (15 seconds)
Write-Host "`n=== Waiting 15s for collection tick ===" -ForegroundColor Cyan
Start-Sleep -Seconds 15

# Step 5: Check collector logs
Write-Host "`n=== Collector logs ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '20 sec ago' --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Step 6: Check DB
Write-Host "`n=== DB Check ===" -ForegroundColor Cyan

Write-Host "--- TBL_PRODUCTION_RECORD count ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
if ($result) { Write-Host "Count: $result" -ForegroundColor Green }

Write-Host "--- TBL_PRODUCTION_RECORD sample ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, source_id, barcode, batch_no, quantity, created_at, production_date FROM TBL_PRODUCTION_RECORD LIMIT 5;'"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "--- TBL_COLLECT_CURSOR ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_COLLECT_CURSOR;'"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "--- TBL_DATA_SOURCE status ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_id, status, last_success_at, last_error_at FROM TBL_DATA_SOURCE;'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Step 7: Statistics API
Write-Host "`n=== Statistics API ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n=== Deploy complete ===" -ForegroundColor Cyan