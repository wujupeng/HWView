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

Write-Host "========== R2 EVIDENCE: 2026-09-06 RAW DATA ==========" -ForegroundColor Cyan

# Fetch 09-06 using PATH-BASED URL (not ?date=)
Write-Host "`n=== R2-EVIDENCE-001: Fetch 2026-09-06 (path-based URL) ===" -ForegroundColor Yellow
$result = Invoke-Remote "curl -sS 'http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-06%2000:00:00/end_date_time/2026-09-06%2023:59:59' -o /tmp/hw_0906_path.html 2>&1 && wc -c /tmp/hw_0906_path.html"
Write-Host "  File: $result" -ForegroundColor Green

# Count barcodes
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | wc -l"
Write-Host "  Barcodes found: $result" -ForegroundColor Green

# Count unique barcodes
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u | wc -l"
Write-Host "  Unique barcodes: $result" -ForegroundColor Green

# Count unique source_ids
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906_path.html | sort -u | wc -l"
Write-Host "  Unique source_ids: $result" -ForegroundColor Green

# TR count
$result = Invoke-Remote "grep -c '<tr' /tmp/hw_0906_path.html"
Write-Host "  TR count: $result" -ForegroundColor Green

# Check if 09-06 path data differs from 09-07
Write-Host "`n=== Compare 09-06 (path) vs 09-07 (DB) ===" -ForegroundColor Yellow
$result = Invoke-Remote "comm -12 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  Overlap: $result" -ForegroundColor Green

$result = Invoke-Remote "comm -23 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-06 only: $result" -ForegroundColor Green

$result = Invoke-Remote "comm -13 <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u) <(grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw.html | sort -u) | wc -l"
Write-Host "  09-07 only: $result" -ForegroundColor Green

# R2-EVIDENCE-002: Extract all records with quantity
Write-Host "`n=== R2-EVIDENCE-002: All records with quantity ===" -ForegroundColor Yellow

# Extract source_id, barcode, quantity, batch, created_at for each record
# Using grep to extract printload IDs
Write-Host "`n--- Source IDs ---" -ForegroundColor Gray
$result = Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906_path.html | grep -oP '\d+' | sort -n"
Write-Host "  $result" -ForegroundColor Gray

# Extract barcodes
Write-Host "`n--- Barcodes ---" -ForegroundColor Gray
$result = Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u"
Write-Host "  $result" -ForegroundColor Gray

# Extract created_at times
Write-Host "`n--- Created_at times ---" -ForegroundColor Gray
$result = Invoke-Remote "grep -oP '2026-09-06 \d{2}:\d{2}:\d{2}' /tmp/hw_0906_path.html | sort"
Write-Host "  $result" -ForegroundColor Gray

# Extract quantity values (number in td after barcode td)
Write-Host "`n--- Quantity values ---" -ForegroundColor Gray
$result = Invoke-Remote "grep -A1 'DNCPEMCHW' /tmp/hw_0906_path.html | grep -oP '<td>\d+</td>' | sort | uniq -c"
Write-Host "  $result" -ForegroundColor Gray

# Batch numbers
Write-Host "`n--- Batch numbers ---" -ForegroundColor Gray
$result = Invoke-Remote "grep -oP 'Q\d{4}-\d{3}' /tmp/hw_0906_path.html | sort | uniq -c | sort -rn"
Write-Host "  $result" -ForegroundColor Gray

# R2-EVIDENCE-004: Compute A/B/C/D
Write-Host "`n=== R2-EVIDENCE-004: A/B/C/D for 2026-09-06 ===" -ForegroundColor Yellow
$A = (Invoke-Remote "grep -oP 'printload/id/\d+' /tmp/hw_0906_path.html | sort -u | wc -l").Trim()
$B = $A  # same as A since all unique
$C = (Invoke-Remote "grep -oP 'DNCPEMCHW[^<\s]*' /tmp/hw_0906_path.html | sort -u | wc -l").Trim()
$qtyCount = (Invoke-Remote "grep -A1 'DNCPEMCHW' /tmp/hw_0906_path.html | grep -oP '<td>\d+</td>' | grep -oP '\d+' | head -1").Trim()
$D = [int]$A * [int]$qtyCount

Write-Host "  A (record count)     = $A" -ForegroundColor Green
Write-Host "  B (unique source_id) = $B" -ForegroundColor Green
Write-Host "  C (unique barcode)   = $C" -ForegroundColor Green
Write-Host "  D (quantity sum)     = $D ($A x $qtyCount)" -ForegroundColor Green

# R2-EVIDENCE-005: Cross-validate with business ledger
Write-Host "`n=== R2-EVIDENCE-005: Cross-Validation ===" -ForegroundColor Yellow
Write-Host @"
  Business Ledger (2026-09-06):
    E1 = 2000 (actual completed)
    E2 = 1980 (warehouse inbound) = 33 boxes
    E3 = 1680 (shipped) = 28 boxes
    E4 =  300 (inventory) = 5 boxes
    Verification: 1980 = 1680 + 300 = OK
    
  HWView Technical Data:
    A = $A records
    B = $B unique source_ids
    C = $C unique barcodes
    D = $D (quantity sum)
    quantity = $qtyCount (per record)
    
  Cross-Validation:
    A vs E1: $A vs 2000 -> $(if([int]$A -eq 2000){'MATCH'}else{'NO MATCH'})
    A vs E2: $A vs 1980 -> $(if([int]$A -eq 1980){'MATCH'}else{'NO MATCH'})
    D vs E1: $D vs 2000 -> $(if([int]$D -eq 2000){'MATCH'}else{'NO MATCH'})
    D vs E2: $D vs 1980 -> $(if([int]$D -eq 1980){'MATCH'}else{'NO MATCH'})
    D/60:    $([int]$D/60) boxes
    E2/60:   33 boxes
"@ -ForegroundColor Cyan

# R2-EVIDENCE-006: Check all hypotheses
Write-Host "`n=== R2-EVIDENCE-006: Hypothesis Check ===" -ForegroundColor Yellow
Write-Host @"
  H1: quantity=$qtyCount means $qtyCount pieces
    Total = $A x $qtyCount = $D pieces
    $D vs E1(2000): $(if([int]$D -eq 2000){'MATCH'}else{'NO MATCH'})
    $D vs E2(1980): $(if([int]$D -eq 1980){'MATCH'}else{'NO MATCH'})
    
  H2: quantity=$qtyCount means $qtyCount boxes
    Total = $A x $qtyCount x 60 = $([int]$A * [int]$qtyCount * 60) pieces
    $([int]$A * [int]$qtyCount * 60) vs E1(2000): $(if([int]$A * [int]$qtyCount * 60 -eq 2000){'MATCH'}else{'NO MATCH'})
    
  H3: A (record count) = E1 or E2
    $A vs 2000: $(if([int]$A -eq 2000){'MATCH'}else{'NO MATCH'})
    $A vs 1980: $(if([int]$A -eq 1980){'MATCH'}else{'NO MATCH'})
    
  H4: C (barcode count) = E1 or E2
    $C vs 2000: $(if([int]$C -eq 2000){'MATCH'}else{'NO MATCH'})
    $C vs 1980: $(if([int]$C -eq 1980){'MATCH'}else{'NO MATCH'})
    
  H5: quantity=$qtyCount is unrelated to production count
    -> System field with other business meaning
"@ -ForegroundColor Cyan

Write-Host "`n========== R2 EVIDENCE COMPLETE ==========" -ForegroundColor Cyan