$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
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

# Check table schema
Write-Host "=== Table schema ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db '.schema TBL_PRODUCTION_LINE'"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check if data exists
Write-Host "`n=== Current data ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Count: $result" -ForegroundColor Yellow }

# Direct insert with sqlite3 command
Write-Host "`n=== Direct insert ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db `"INSERT INTO TBL_PRODUCTION_LINE (line_code, line_name, customer, product, adapter_type, enabled, status) VALUES ('HW102-COPY', 'Huawei102-Copy-Line', 'Huawei', 'HW102', 'Huawei102Adapter', 1, 'CONFIGURED');`" 2>&1 && echo 'INSERT_OK'"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check again
Write-Host "`n=== After insert ===" -ForegroundColor Cyan
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT id, line_code, line_name, customer, product, adapter_type, enabled, status FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Data: $result" -ForegroundColor Green }

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_LINE;'"
if ($result) { Write-Host "Count: $result" -ForegroundColor Green }

# API check
Write-Host "`n=== API Lines ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host $result -ForegroundColor Green }

# Statistics
Write-Host "`n=== Statistics ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host $result -ForegroundColor Green }