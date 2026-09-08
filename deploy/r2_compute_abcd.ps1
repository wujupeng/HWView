$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
cp /tmp/hw_0906_path.html /tmp/hw_0906_p1.html

echo "=== Per-page barcode counts ==="
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  cnt=$(grep -c 'DNCPEMCHW' /tmp/hw_0906_p${i}.html 2>/dev/null)
  echo "Page ${i}: ${cnt} barcodes"
done

echo ""
echo "=== Totals across all 17 pages ==="
total_bc=$(grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | grep -oP 'DNCPEMCHW[^<\s'"'"']*' | wc -l)
unique_bc=$(grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | grep -oP 'DNCPEMCHW[^<\s'"'"']*' | sort -u | wc -l)
unique_sid=$(grep -h 'printload/id/' /tmp/hw_0906_p*.html | grep -oP 'printload/id/\d+' | sort -u | wc -l)

echo "A (total barcode occurrences): ${total_bc}"
echo "B (unique barcodes):           ${unique_bc}"
echo "C (unique source_ids):         ${unique_sid}"

echo ""
echo "=== Quantity values distribution ==="
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | grep -oP '<td>\d+</td>' | grep -oP '\d+' | sort | uniq -c | sort -rn
echo "---"
qty_sum=$(grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | grep -oP '<td>\d+</td>' | grep -oP '\d+' | paste -sd+ | bc)
echo "D (sum of all quantity-like td values): ${qty_sum}"

echo ""
echo "=== Time range ==="
earliest=$(grep -oP '2026-09-06 \d{2}:\d{2}:\d{2}' /tmp/hw_0906_p*.html | sort | head -1)
latest=$(grep -oP '2026-09-06 \d{2}:\d{2}:\d{2}' /tmp/hw_0906_p*.html | sort | tail -1)
echo "Earliest: ${earliest}"
echo "Latest:   ${latest}"
'@

# Convert to Unix line endings
$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r2_compute.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r2_compute.sh"

Remove-Item $tmpFile -Force
