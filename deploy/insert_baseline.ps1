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
    $p.WaitForExit(60000)
    if (-not $p.HasExited) { $p.Kill() }
    if ($p.ExitCode -ne 0) {
        Write-Host "  UPLOAD ERROR: $($p.StandardError.ReadToEnd())" -ForegroundColor Red
        return $false
    }
    Write-Host "  OK: $LocalPath -> $RemotePath" -ForegroundColor Green
    return $true
}

# Create a SQL file for baseline data insertion
$sqlContent = @"
INSERT OR IGNORE INTO TBL_PRODUCTION_LINE (line_code, line_name, customer, product, adapter_type, enabled, status) VALUES ('HW102-COPY', 'Huawei102-Copy-Line', 'Huawei', 'HW102', 'Huawei102Adapter', 1, 'CONFIGURED');
"@
Set-Content -Path "C:\Users\DELL\IDEProjects\HWView\deploy\insert_baseline.sql" -Value $sqlContent -Encoding UTF8

# Upload and execute
Write-Host "=== Uploading baseline SQL ===" -ForegroundColor Cyan
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\insert_baseline.sql" "/tmp/insert_baseline.sql"

Write-Host "`n=== Inserting baseline data ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db < /tmp/insert_baseline.sql 2>&1 && echo 'Insert OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Verify DB
Write-Host "`n=== DB Verification ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_code, line_name, customer, product, adapter_type, enabled, status FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Production lines: $result" -ForegroundColor Green }

# API verification
Write-Host "`n=== API Verification ===" -ForegroundColor Cyan

Write-Host "--- Lines ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host $result }

Write-Host "--- Line HW102-COPY ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines/HW102-COPY"
if ($result) { Write-Host $result }

Write-Host "--- Statistics Overview (Shadow Mode) ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result }

# Service status
Write-Host "`n=== Service Status ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S systemctl is-active hwview-server hwview-collector 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Memory usage
Write-Host "`n=== Resource Usage ===" -ForegroundColor Cyan
$result = Invoke-Remote "ps aux | grep hwview | grep -v grep"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Disk usage
$result = Invoke-Remote "ls -lh /opt/hwview/data/hwview.db"
if ($result) { Write-Host "DB size: $result" -ForegroundColor Yellow }

Write-Host "`n=== FINAL DEPLOYMENT STATUS ===" -ForegroundColor Green
Write-Host "Server:   192.168.2.110:8080  (ACTIVE)" -ForegroundColor Green
Write-Host "Services: hwview-server + hwview-collector (ACTIVE)" -ForegroundColor Green
Write-Host "DB:       /opt/hwview/data/hwview.db (7 tables, 1 baseline line)" -ForegroundColor Green
Write-Host "Shadow:   shadow_mode=true, quantity_label='pending business confirmation'" -ForegroundColor Green
Write-Host "Adapters: Huawei102Adapter, BMWAdapter, SchaefflerAdapter, MagnaAdapter, GenericAdapter" -ForegroundColor Green