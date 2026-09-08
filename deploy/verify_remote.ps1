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
        Write-Host "  ERROR (exit $($p.ExitCode)): $stderr" -ForegroundColor Red
        return $null
    }
    return $stdout
}

# Try sqlite3 with full path first
Write-Host "=== Trying sqlite3 ===" -ForegroundColor Cyan
$result = Invoke-Remote "ls /usr/bin/sqlite3 2>/dev/null || ls /usr/local/bin/sqlite3 2>/dev/null || dpkg -L sqlite3 2>/dev/null | grep bin || echo 'NOT_FOUND'"
Write-Host $result -ForegroundColor Yellow

# Use API to create the production line
Write-Host "`n=== Creating HW102-COPY via API ===" -ForegroundColor Cyan
$json = '{"line_code":"HW102-COPY","line_name":"Huawei102-Copy-Line","customer":"Huawei","product":"HW102","adapter_type":"Huawei102Adapter"}'
$result = Invoke-Remote "curl -s -X POST http://localhost:8080/api/v1/lines -H 'Content-Type: application/json' -d '$json'"
if ($result) { Write-Host "Create result: $result" -ForegroundColor Green }

# Verify
Write-Host "`n=== Verifying ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines"
if ($result) { Write-Host "Lines: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/lines/HW102-COPY"
if ($result) { Write-Host "Line detail: $result" -ForegroundColor Green }

# Check statistics endpoint
Write-Host "`n=== Checking statistics (shadow mode) ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/overview"
if ($result) { Write-Host "Stats overview: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/statistics/lines/HW102-COPY"
if ($result) { Write-Host "Line stats: $result" -ForegroundColor Green }

# Check adapters
Write-Host "`n=== Checking adapters ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/adapters"
if ($result) { Write-Host "Adapters: $result" -ForegroundColor Green }

# Check health endpoints
Write-Host "`n=== Checking health ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/health"
if ($result) { Write-Host "Health: $result" -ForegroundColor Green }

# Check data sources
Write-Host "`n=== Checking data sources ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/data-sources"
if ($result) { Write-Host "Data sources: $result" -ForegroundColor Green }

# Check agent endpoints
Write-Host "`n=== Checking agents ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -s http://localhost:8080/api/v1/agents"
if ($result) { Write-Host "Agents: $result" -ForegroundColor Green }

Write-Host "`n=== Done ===" -ForegroundColor Cyan