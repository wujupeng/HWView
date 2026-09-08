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

# Check if 09-06 and 09-07 barcodes overlap
Write-Host "`n--- Barcode overlap (09-06 vs 09-07) ---" -ForegroundColor Yellow
$result = Invoke-Remote "comm -12 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  Overlap count: $result" -ForegroundColor Green

# 09-06 unique barcodes not in 09-07
$result = Invoke-Remote "comm -23 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-06 only: $result" -ForegroundColor Green

# 09-07 unique barcodes not in 09-06
$result = Invoke-Remote "comm -13 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-07 only: $result" -ForegroundColor Green

# Extract quantity values from 09-06 HTML
Write-Host "`n--- 09-06 quantity values ---" -ForegroundColor Yellow
$result = Invoke-Remote "python3 -c `"import re; html=open('/tmp/hw_0906.html').read(); trs=re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.S); qty=[]; [qty.extend(re.findall(r'<td>(\d+)</td>', tr)) for tr in trs if 'DNCPEMCHW' in tr]; from collections import Counter; print(Counter(qty))`" 2>&1
Write-Host "  Quantity distribution: $result" -ForegroundColor Green

# Extract created_at times from 09-06
Write-Host "`n--- 09-06 created_at range ---" -ForegroundColor Yellow
$result = Invoke-Remote "python3 -c `"import re; html=open('/tmp/hw_0906.html').read(); trs=re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.S); times=[]; [times.extend(re.findall(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', tr)) for tr in trs if 'DNCPEMCHW' in tr]; times.sort(); print(f'Count: {len(times)}'); print(f'Earliest: {times[0] if times else \"N/A\"}'); print(f'Latest: {times[-1] if times else \"N/A\"}')`" 2>&1
Write-Host "  $result" -ForegroundColor Green

# Extract source_ids from 09-06
Write-Host "`n--- 09-06 source_id range ---" -ForegroundColor Yellow
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | grep -oP '\d+' | sort -n | head -1"
Write-Host "  Min source_id: $result" -ForegroundColor Green
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | grep -oP '\d+' | sort -n | tail -1"
Write-Host "  Max source_id: $result" -ForegroundColor Green

# 09-07 source_id range from DB
Write-Host "`n--- 09-07 source_id range (from DB) ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT min(source_id), max(source_id) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Min/Max: $result" -ForegroundColor Green

# Check if source_ids are contiguous
Write-Host "`n--- 09-07 source_id gaps ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) as total, max(source_id) - min(source_id) + 1 as range_size FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Total vs Range: $result" -ForegroundColor Green

# Barcode sequence number analysis
Write-Host "`n--- Barcode sequence analysis ---" -ForegroundColor Yellow
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT substr(barcode, 15, 4) as seq FROM TBL_PRODUCTION_RECORD ORDER BY seq;'"
Write-Host "  09-07 sequences:" -ForegroundColor Gray
Write-Host "  $result" -ForegroundColor Gray

Write-Host "`n=== Analysis complete ===" -ForegroundColor Cyan