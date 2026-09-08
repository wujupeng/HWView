$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

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
    $p.WaitForExit(60000)
    if (-not $p.HasExited) { $p.Kill() }
    if ($p.ExitCode -ne 0) {
        Write-Host "  UPLOAD ERROR: $($p.StandardError.ReadToEnd())" -ForegroundColor Red
        return $false
    }
    return $true
}

# Upload SQL file
Write-Host "=== Uploading SQL ===" -ForegroundColor Cyan
Upload-File "C:\Users\DELL\IDEProjects\HWView\deploy\insert_baseline.sql" "/tmp/insert_baseline.sql"

# Check file content on remote
Write-Host "`n=== File content on remote ===" -ForegroundColor Cyan
$result = Invoke-Remote "cat /tmp/insert_baseline.sql"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Execute SQL
Write-Host "`n=== Executing SQL ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db '.read /tmp/insert_baseline.sql' 2>&1 && echo 'EXEC_OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check data
Write-Host "`n=== Checking data ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_code, line_name, customer, product, adapter_type, enabled, status FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Data: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Count: $result" -ForegroundColor Green }

# API check
Write-Host "`n=== API check ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host "Lines: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines/HW102-COPY"
if ($result) { Write-Host "Line detail: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host "Stats: $result" -ForegroundColor Green }