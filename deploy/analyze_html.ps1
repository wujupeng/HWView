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

# Analyze the HTML file
Write-Host "=== HTML Analysis ===" -ForegroundColor Cyan

# Check if it's a login page
Write-Host "`n--- Login form check ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -ci 'login\|password\|signin\|登录\|密码' /tmp/hwview_0907_now.html 2>&1"
if ($result) { Write-Host "Login keywords: $result" -ForegroundColor Green }

# Check for error messages
Write-Host "`n--- Error message check ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -i 'error\|错误\|失败\|无数据\|没有' /tmp/hwview_0907_now.html 2>&1 | head -5"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Check title
Write-Host "`n--- Title ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '<title>[^<]*</title>' /tmp/hwview_0907_now.html 2>&1"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check all <tr> content
Write-Host "`n--- All TR content ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '<tr[^>]*>.*?</tr>' /tmp/hwview_0907_now.html 2>&1 | head -10"
if ($result) { Write-Host $result -ForegroundColor Gray }

# Check for pagination
Write-Host "`n--- Pagination check ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'page=\d+|共\d+页|每页\d+|pagination' /tmp/hwview_0907_now.html 2>&1 | head -5"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check for 'lists' specific content
Write-Host "`n--- Lists page specific ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'Jili|lists|printload|Cron' /tmp/hwview_0907_now.html 2>&1 | sort | uniq -c | sort -rn"
if ($result) { Write-Host $result -ForegroundColor Green }

# Dump middle of HTML (around data area)
Write-Host "`n--- HTML body excerpt (chars 2000-4000) ---" -ForegroundColor Yellow
$result = Invoke-Remote "dd if=/tmp/hwview_0907_now.html bs=1 skip=2000 count=2000 2>/dev/null"
if ($result) { Write-Host $result -ForegroundColor Gray }

# Try different date format - maybe the URL needs different encoding
Write-Host "`n=== Try different URL formats ===" -ForegroundColor Cyan

# Try without URL encoding
Write-Host "`n--- Try plain date format ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07 00:00:00/end_date_time/2026-09-07 23:59:59' -o /tmp/hwview_0907_v2.html 2>&1 && wc -c /tmp/hwview_0907_v2.html && grep -c '<tr' /tmp/hwview_0907_v2.html"
if ($result) { Write-Host $result -ForegroundColor Green }

# Try the Golden Evidence date: Q0926-078 / 2026-09-07
# Also try the base path from spec
Write-Host "`n--- Try base /Cron/Jili/lists/ ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/' -o /tmp/hwview_base.html 2>&1 && wc -c /tmp/hwview_base.html && grep -c '<tr' /tmp/hwview_base.html && grep -oP '<title>[^<]*</title>' /tmp/hwview_base.html"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check if there's a session/cookie requirement
Write-Host "`n--- Check for session/cookie ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS -v --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/' 2>&1 | grep -i 'set-cookie\|location\|redirect\|session' | head -5"
if ($result) { Write-Host $result -ForegroundColor Yellow }

# Try with the exact Golden Evidence URL from spec
Write-Host "`n--- Try Golden Evidence URL pattern ---" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS --connect-timeout 3 --max-time 10 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-07%2000:00:00/end_date_time/2026-09-07%2023:59:59' -o /tmp/hwview_0907_v3.html 2>&1 && wc -c /tmp/hwview_0907_v3.html && grep -c '<tr' /tmp/hwview_0907_v3.html"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check v3 content for records
Write-Host "`n--- v3 record count ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '共\d+条|total.*?\d+|count.*?\d+' /tmp/hwview_0907_v3.html 2>&1 | head -5"
if ($result) { Write-Host $result -ForegroundColor Green }

# Check v3 for table data
Write-Host "`n--- v3 table data ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '<td[^>]*>.*?</td>' /tmp/hwview_0907_v3.html 2>&1 | head -10"
if ($result) { Write-Host $result -ForegroundColor Gray }

Write-Host "`n=== Analysis complete ===" -ForegroundColor Cyan