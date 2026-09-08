$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

function Invoke-Remote {
    param([string]$Command, [int]$TimeoutMs = 60000)
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

Write-Host "========== R2 CROSS-VALIDATION DATA PREP ==========" -ForegroundColor Cyan

# ============================================================
# Day 1: 2026-09-07 (already in DB)
# ============================================================
Write-Host "`n=== Day 1: 2026-09-07 (from DB) ===" -ForegroundColor Yellow

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(*) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  A (record count): $result" -ForegroundColor Green

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(DISTINCT source_id) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  B (unique source_id): $result" -ForegroundColor Green

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT count(DISTINCT barcode) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  C (unique barcode): $result" -ForegroundColor Green

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT sum(quantity) FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  D (quantity sum): $result" -ForegroundColor Green

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT DISTINCT quantity FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Distinct quantities: $result" -ForegroundColor Green

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT DISTINCT batch_no FROM TBL_PRODUCTION_RECORD;'"
Write-Host "  Distinct batches: $result" -ForegroundColor Green

# Barcode pattern analysis
Write-Host "`n  --- Barcode pattern analysis ---" -ForegroundColor Gray
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT barcode FROM TBL_PRODUCTION_RECORD LIMIT 5;'"
Write-Host "  Sample barcodes:" -ForegroundColor Gray
Write-Host "  $result" -ForegroundColor Gray

# Check if barcodes have sequential numbers
$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT substr(barcode, 15, 4) as seq FROM TBL_PRODUCTION_RECORD ORDER BY seq LIMIT 5;'"
Write-Host "  Barcode seq (pos 15-18): $result" -ForegroundColor Gray

$result = Invoke-Remote "/usr/bin/sqlite3 /opt/hwview/data/hwview.db 'SELECT substr(barcode, 15, 4) as seq FROM TBL_PRODUCTION_RECORD ORDER BY seq DESC LIMIT 5;'"
Write-Host "  Barcode seq (last 5): $result" -ForegroundColor Gray

# ============================================================
# Day 2: 2026-09-06 (fetch from source)
# ============================================================
Write-Host "`n=== Day 2: 2026-09-06 (fetch from source) ===" -ForegroundColor Yellow

# Fetch HTML
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-06&page=1' -o /tmp/hw_0906.html 2>&1 && wc -c /tmp/hw_0906.html"
Write-Host "  Fetch: $result" -ForegroundColor Green

# Count barcodes
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | wc -l"
Write-Host "  Barcodes found: $result" -ForegroundColor Green

# Count unique barcodes
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u | wc -l"
Write-Host "  Unique barcodes: $result" -ForegroundColor Green

# Count printload IDs (source_ids)
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | sort -u | wc -l"
Write-Host "  Unique source_ids: $result" -ForegroundColor Green

# Extract quantities (column 3 in table)
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906.html | wc -l"
Write-Host "  Total records (printload links): $result" -ForegroundColor Green

# Get sample barcodes from 09-06
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906.html | sort -u | head -5"
Write-Host "  Sample barcodes: $result" -ForegroundColor Green

# Get sample quantities - extract the number after barcode in table
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<]*</td>\s*<td>\d+' /tmp/hw_0906.html | grep -oP '\d+$' | sort | uniq -c | sort -rn"
Write-Host "  Quantity distribution: $result" -ForegroundColor Green

# Get batch numbers
$result = Invoke-Remote "grep -oP 'Q\d{4}-\d{3}' /tmp/hw_0906.html | sort | uniq -c | sort -rn"
Write-Host "  Batch distribution: $result" -ForegroundColor Green

# Check for pagination
$result = Invoke-Remote "grep -c 'next' /tmp/hw_0906.html 2>/dev/null || echo 0"
Write-Host "  Pagination links: $result" -ForegroundColor Gray

# Fetch page 2 to check if there are more records
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/?date=2026-09-06&page=2' -o /tmp/hw_0906_p2.html 2>&1 && grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_p2.html | sort -u | wc -l"
Write-Host "  Page 2 unique barcodes: $result" -ForegroundColor Green

# ============================================================
# Cross-Validation Analysis
# ============================================================
Write-Host "`n=== CROSS-VALIDATION ANALYSIS ===" -ForegroundColor Cyan

Write-Host @"
  Business Evidence:
    Packaging spec (from Quality Dept): 60 pieces/box
    
  2026-09-07 data (from DB):
    A = 30 records
    B = 30 unique source_ids
    C = 30 unique barcodes
    D = 510 (30 x 17)
    quantity = 17 (all records)
    
  Hypothesis 1: quantity=17 means 17 pieces
    -> Total pieces = 30 x 17 = 510
    -> 510 / 60 = 8.5 boxes (not integer, unlikely)
    
  Hypothesis 2: quantity=17 means 17 boxes
    -> Total pieces = 30 x 17 x 60 = 30,600
    -> But C=30 barcodes, not 30,600 (each barcode != each piece)
    
  Hypothesis 3: each barcode = 1 box, quantity=17 = pieces per box
    -> But 17 != 60 (conflicts with Quality Dept spec)
    
  Hypothesis 4: each record = 1 scan event, quantity=17 = some unit
    -> Need business confirmation
"@ -ForegroundColor Yellow

Write-Host "`n========== ANALYSIS COMPLETE ==========" -ForegroundColor Cyan