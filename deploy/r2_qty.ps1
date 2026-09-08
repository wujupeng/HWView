$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
echo "=== Extracting quantity (3rd td) and created_at (5th td) from all pages ==="

# Use awk to parse HTML rows
# Each data row contains DNCPEMCHW in the barcode td
# Row structure: <tr> <td>op</td> <td>barcode</td> <td>quantity</td> <td>batch</td> <td>created_at</td> <td>del</td> </tr>

# Extract quantity values (3rd td in rows containing DNCPEMCHW)
# Method: for each line with DNCPEMCHW, extract all <td>...</td> and take the 3rd one
echo "--- Quantity distribution ---"
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*' | awk 'NR%6==3{print}' | sort -n | uniq -c | sort -rn

echo ""
echo "--- D (sum of quantity) ---"
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*' | awk 'NR%6==3{sum+=$1} END{print sum}'

echo ""
echo "--- Verify: extract first 5 rows sample ---"
grep -h 'DNCPEMCHW' /tmp/hw_0906_p1.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | head -5 | while IFS= read -r row; do
  tds=$(echo "$row" | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*')
  echo "$tds" | tr '\n' '|'
  echo ""
done

echo ""
echo "=== Time range (from created_at field, 5th td) ==="
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*' | awk 'NR%6==5{print}' | sort | head -1
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*' | awk 'NR%6==5{print}' | sort | tail -1

echo ""
echo "=== Batch distribution (4th td) ==="
grep -h 'DNCPEMCHW' /tmp/hw_0906_p*.html | sed 's/<\/tr>/\n/g' | grep 'DNCPEMCHW' | sed 's/<td>/\n<td>/g' | grep -oP '(?<=<td>)[^<]*' | awk 'NR%6==4{print}' | sort | uniq -c | sort -rn | head -20
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r2_qty.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r2_qty.sh"

Remove-Item $tmpFile -Force