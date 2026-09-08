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

# Full collector logs since restart
Write-Host "=== Full collector logs ===" -ForegroundColor Cyan
$result = Invoke-Remote "echo $sudopw | sudo -S journalctl -u hwview-collector --since '5 min ago' --no-pager 2>&1"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Test the URL that the adapter would construct
Write-Host "`n=== Test adapter URL format ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w 'HTTP_CODE=%{http_code} SIZE=%{size_download}' 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-08&page=1' 2>&1"
if ($result) { Write-Host "Adapter URL: $result" -ForegroundColor Green }

# Test the correct URL format
Write-Host "`n=== Test correct URL format ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w 'HTTP_CODE=%{http_code} SIZE=%{size_download}' 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-08%2000:00:00/end_date_time/2026-09-08%2023:59:59' 2>&1"
if ($result) { Write-Host "Correct URL: $result" -ForegroundColor Green }

# Test base URL status code
Write-Host "`n=== Test base URL status ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 -o /dev/null -w 'HTTP_CODE=%{http_code} SIZE=%{size_download}' 'http://192.168.30.2:86/Cron/Jili/lists/' 2>&1"
if ($result) { Write-Host "Base URL: $result" -ForegroundColor Green }

# Count records from correct URL
Write-Host "`n=== Count records from correct URL ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-08%2000:00:00/end_date_time/2026-09-08%2023:59:59' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | wc -l"
if ($result) { Write-Host "Today barcodes: $result" -ForegroundColor Green }

$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07%2000:00:00/end_date_time/2026-09-07%2023:59:59' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | wc -l"
if ($result) { Write-Host "Yesterday barcodes: $result" -ForegroundColor Green }

# Get sample barcodes from today
Write-Host "`n=== Sample barcodes (today) ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-08%2000:00:00/end_date_time/2026-09-08%2023:59:59' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | head -5"
if ($result) { Write-Host $result -ForegroundColor Green }

# Get sample barcodes from yesterday (Golden Evidence date)
Write-Host "`n=== Sample barcodes (yesterday 09-07) ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07%2000:00:00/end_date_time/2026-09-07%2023:59:59' 2>&1 | grep -oP 'DNCPEMCHW[^<\s]*' | head -5"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check batch numbers
Write-Host "`n=== Batch numbers (yesterday) ===" -ForegroundColor Cyan
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07%2000:00:00/end_date_time/2026-09-07%2023:59:59' 2>&1 | grep -oP 'Q\d{4}-\d{3}' | sort | uniq -c | sort -rn"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "`n=== Evidence collection complete ===" -ForegroundColor Cyan