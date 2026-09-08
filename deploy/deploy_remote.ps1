$ErrorActionPreference = "Stop"
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
        Write-Host "  ERROR (exit $($p.ExitCode)): $stderr" -ForegroundColor Red
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
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    if (-not $p.HasExited) { $p.Kill() }
    if ($p.ExitCode -ne 0) {
        Write-Host "  UPLOAD ERROR (exit $($p.ExitCode)): $stderr" -ForegroundColor Red
        return $false
    }
    Write-Host "  OK: $LocalPath -> $RemotePath" -ForegroundColor Green
    return $true
}

# === Step 1: Test connection ===
Write-Host "=== Step 1: Testing SSH connection ===" -ForegroundColor Cyan
$result = Invoke-Remote "whoami && uname -a && cat /etc/os-release | head -3"
if ($result) {
    Write-Host $result -ForegroundColor Green
} else {
    Write-Host "Connection failed!" -ForegroundColor Red
    exit 1
}

# === Step 2: Create remote directories ===
Write-Host "`n=== Step 2: Creating remote directories ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S mkdir -p /opt/hwview/bin /opt/hwview/config /opt/hwview/deploy /opt/hwview/data /opt/hwview/logs 2>&1 && echo $sudopw | sudo -S chown -R debian:debian /opt/hwview 2>&1 && echo 'Dirs created OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# === Step 3: Upload binaries ===
Write-Host "`n=== Step 3: Uploading binaries ===" -ForegroundColor Cyan
Upload-File "C:\Users\DELL\IDEProjects\HWView\bin\hwview-server" "/opt/hwview/bin/hwview-server"
Upload-File "C:\Users\DELL\IDEProjects\HWView\bin\hwview-collector" "/opt/hwview/bin/hwview-collector"

# === Step 4: Upload config and deploy files ===
Write-Host "`n=== Step 4: Uploading config & deploy files ===" -ForegroundColor Cyan
Upload-File "C:\Users\DELL\IDEProjects\HWView\config\config.deploy.yaml" "/opt/hwview/config/config.yaml"
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\init_schema.sql" "/opt/hwview/deploy/init_schema.sql"
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\hwview-server.service" "/opt/hwview/deploy/hwview-server.service"
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\hwview-collector.service" "/opt/hwview/deploy/hwview-collector.service"

# === Step 5: Make binaries executable ===
Write-Host "`n=== Step 5: Setting permissions ===" -ForegroundColor Cyan
$result = Invoke-Remote "chmod +x /opt/hwview/bin/hwview-server /opt/hwview/bin/hwview-collector && echo 'Permissions set OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# === Step 6: Initialize database ===
Write-Host "`n=== Step 6: Initializing database ===" -ForegroundColor Cyan
# Check if sqlite3 is available
$result = Invoke-Remote "which sqlite3 2>/dev/null && echo 'SQLITE3_AVAILABLE' || echo 'SQLITE3_NOT_FOUND'"
if ($result -and $result.Contains("SQLITE3_AVAILABLE")) {
    Write-Host "  sqlite3 found, initializing DB from schema..." -ForegroundColor Yellow
    $result = Invoke-Remote "sqlite3 /opt/hwview/data/hwview.db < /opt/hwview/deploy/init_schema.sql 2>&1 && echo 'DB initialized OK'"
    if ($result) { Write-Host $result -ForegroundColor Green }
} else {
    Write-Host "  sqlite3 not found, will install it..." -ForegroundColor Yellow
    $result = Invoke-Remote "echo $sudopw | sudo -S apt-get install -y sqlite3 2>&1 | tail -3"
    if ($result) { Write-Host $result -ForegroundColor Yellow }
    $result = Invoke-Remote "which sqlite3 2>/dev/null && echo 'SQLITE3_NOW_AVAILABLE' || echo 'STILL_NOT_FOUND'"
    if ($result -and $result.Contains("SQLITE3_NOW_AVAILABLE")) {
        $result = Invoke-Remote "sqlite3 /opt/hwview/data/hwview.db < /opt/hwview/deploy/init_schema.sql 2>&1 && echo 'DB initialized OK'"
        if ($result) { Write-Host $result -ForegroundColor Green }
    } else {
        Write-Host "  Cannot install sqlite3, AutoMigrate will create tables on first run" -ForegroundColor Yellow
    }
}

# === Step 7: Install systemd services ===
Write-Host "`n=== Step 7: Installing systemd services ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S cp /opt/hwview/deploy/hwview-server.service /etc/systemd/system/ 2>&1 && echo $sudopw | sudo -S cp /opt/hwview/deploy/hwview-collector.service /etc/systemd/system/ 2>&1 && echo $sudopw | sudo -S systemctl daemon-reload 2>&1 && echo 'Services installed OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# === Step 8: Start services ===
Write-Host "`n=== Step 8: Starting services ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl enable hwview-server hwview-collector 2>&1 && echo $sudopw | sudo -S systemctl start hwview-server 2>&1 && sleep 3 && echo $sudopw | sudo -S systemctl start hwview-collector 2>&1 && sleep 3 && echo 'Services started OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# === Step 9: Verify ===
Write-Host "`n=== Step 9: Verification ===" -ForegroundColor Cyan

Write-Host "--- hwview-server status ---" -ForegroundColor Yellow
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl status hwview-server --no-pager -l 2>&1 | head -15"
if ($result) { Write-Host $result }

Write-Host "--- hwview-collector status ---" -ForegroundColor Yellow
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl status hwview-collector --no-pager -l 2>&1 | head -15"
if ($result) { Write-Host $result }

Write-Host "--- API health check ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/health 2>&1"
if ($result) { Write-Host $result }

Write-Host "--- API lines check ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines 2>&1 | head -30"
if ($result) { Write-Host $result }

Write-Host "--- DB tables check ---" -ForegroundColor Yellow
$result = Invoke-Remote "sqlite3 /opt/hwview/data/hwview.db '.tables' 2>&1"
if ($result) { Write-Host $result }

Write-Host "--- DB production lines check ---" -ForegroundColor Yellow
$result = Invoke-Remote "sqlite3 /opt/hwview/data/hwview.db 'SELECT * FROM TBL_PRODUCTION_LINE;' 2>&1"
if ($result) { Write-Host $result }

Write-Host "`n=== Deployment complete ===" -ForegroundColor Cyan
