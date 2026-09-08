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

Write-Host "=== Fetch and analyze HTML ===" -ForegroundColor Cyan

# Fetch HTML
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-07&page=1' -o /tmp/hw.html 2>&1 && wc -c /tmp/hw.html"
Write-Host "Fetch: $result" -ForegroundColor Green

# Count tables
$result = Invoke-Remote "grep -c '<table' /tmp/hw.html"
Write-Host "Tables: $result" -ForegroundColor Green

# Find line number of first barcode
$result = Invoke-Remote "grep -n 'DNCPEMCHW' /tmp/hw.html | head -1"
Write-Host "First barcode line: $result" -ForegroundColor Green

# Get context around first barcode (10 lines before and after)
$result = Invoke-Remote "grep -n 'DNCPEMCHW' /tmp/hw.html | head -1 | cut -d: -f1"
$lineNum = $result.Trim()
Write-Host "Line num: $lineNum" -ForegroundColor Yellow

$startLine = [int]$lineNum - 15
$endLine = [int]$lineNum + 5
$result = Invoke-Remote "sed -n '${startLine},${endLine}p' /tmp/hw.html"
Write-Host "`n--- Context ---" -ForegroundColor Yellow
Write-Host $result -ForegroundColor Gray

# Count all TR with 5+ TD
$result = Invoke-Remote "grep -oP '<tr[^>]*>.*?</tr>' /tmp/hw.html | grep -c '<td'"
Write-Host "`nTR with TDs: $result" -ForegroundColor Green

# Check what the actual data rows look like
$result = Invoke-Remote "grep -oP '<tr[^>]*>.*?DNCPEMCHW.*?</tr>' /tmp/hw.html | head -1"
Write-Host "`n--- First data TR ---" -ForegroundColor Yellow
Write-Host $result -ForegroundColor Gray

Write-Host "`n=== Done ===" -ForegroundColor Cyan