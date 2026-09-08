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

Write-Host "=== HTML table analysis ===" -ForegroundColor Cyan

# Get context around first barcode
Write-Host "--- Context around first barcode ---" -ForegroundColor Yellow
$result = Invoke-Remote "line=$(grep -n 'DNCPEMCHW' /tmp/hwview_analysis.html | head -1 | cut -d: -f1) && awk -v l=$$line 'NR>=l-10 && NR<=l+10' /tmp/hwview_analysis.html"
if ($result) { Write-Host $result -ForegroundColor Gray }

# Get the data area
Write-Host "--- Data area (chars 4000-7000) ---" -ForegroundColor Yellow
$result = Invoke-Remote "dd if=/tmp/hwview_analysis.html bs=1 skip=4000 count=3000 2>/dev/null"
if ($result) { Write-Host $result -ForegroundColor Gray }

# Count tables
Write-Host "--- Table count ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -c '<table' /tmp/hwview_analysis.html"
if ($result) { Write-Host "Tables: $result" -ForegroundColor Green }

# Find table classes
Write-Host "--- Table classes ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'class=[\x22][^\x22]*table[^\x22]*[\x22]' /tmp/hwview_analysis.html | sort | uniq -c"
if ($result) { Write-Host $result -ForegroundColor Green }

Write-Host "--- Done ---" -ForegroundColor Cyan
