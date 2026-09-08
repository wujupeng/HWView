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
    if ($p.ExitCode -ne 0) { return $null }
    return $stdout
}

Write-Host "=== R2 Deep Analysis ===" -ForegroundColor Cyan

# Barcode overlap
Write-Host "`n--- Barcode overlap (09-06 vs 09-07) ---" -ForegroundColor Yellow
$result = Invoke-Remote "comm -12 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  Overlap: $result" -ForegroundColor Green

$result = Invoke-Remote "comm -23 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-06 only: $result" -ForegroundColor Green

$result = Invoke-Remote "comm -13 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-07 only: $result" -ForegroundColor Green

# Source ID ranges
Write-Host "`n--- 09-06 source_id range ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | grep -oP '\d+' | sort -n | head -1"
Write-Host "  Min: $result" -ForegroundColor Green
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | grep -oP '\d+' | sort -n | tail -1"
Write-Host "  Max: $result" -ForegroundColor Green

Write-Host "`n--- 09-07 source_id range (DB) ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT min(source_id), max(source_id), max(source_id)-min(source_id)+1 as range_size, count(*) as actual_count FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Min/Max/Range/Count: $result" -ForegroundColor Green

# Barcode sequences from DB
Write-Host "`n--- 09-07 barcode sequences ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT substr(barcode, 15, 4) as seq FROM TBL_PRODUCTION_RECORD ORDER BY seq;'"
Write-Host "  $result" -ForegroundColor Gray

# Time range from DB
Write-Host "`n--- 09-07 time range ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT min(created_at), max(created_at) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  $result" -ForegroundColor Green

# 09-06 time range from HTML
Write-Host "`n--- 09-06 time range ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP '2026-09-06 \d{2}:\d{2}:\d{2}' /tmp/hw_0906.html | sort | head -1"
Write-Host "  Earliest: $result" -ForegroundColor Green
$result = Invoke-Remote "grep -oP '2026-09-06 \d{2}:\d{2}:\d{2}' /tmp/hw_0906.html | sort | tail -1"
Write-Host "  Latest: $result" -ForegroundColor Green

# Quantity values from 09-06 HTML - extract td values after barcode
Write-Host "`n--- 09-06 quantity check ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -A1 'DNCPEMCHW' /tmp/hw_0906.html | grep -oP '<td>\d+</td>' | head -5"
Write-Host "  Quantity cells: $result" -ForegroundColor Green

Write-Host "`n=== Done ===" -ForegroundColor Cyan