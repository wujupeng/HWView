$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
curl -s "http://192.168.30.2:86/Cron/Jili/lists/is_rework/0" -o /tmp/r3_rework0.html
curl -s "http://192.168.30.2:86/Cron/Jili/lists/is_rework/2" -o /tmp/r3_rework2.html
curl -s "http://192.168.30.2:86/Cron/Jili/lists/type/0" -o /tmp/r3_type0.html
curl -s "http://192.168.30.2:86/Cron/Jili/lists/type/1" -o /tmp/r3_type1.html

echo "=== File sizes ==="
echo "is_rework/0: $(stat -c%s /tmp/r3_rework0.html) bytes"
echo "is_rework/2: $(stat -c%s /tmp/r3_rework2.html) bytes"
echo "type/0:      $(stat -c%s /tmp/r3_type0.html) bytes"
echo "type/1:      $(stat -c%s /tmp/r3_type1.html) bytes"

echo ""
echo "=== Barcode counts ==="
echo "is_rework/0: $(grep -c 'DNCPEMCHW' /tmp/r3_rework0.html) barcodes"
echo "is_rework/2: $(grep -c 'DNCPEMCHW' /tmp/r3_rework2.html) barcodes"
echo "type/0:      $(grep -c 'DNCPEMCHW' /tmp/r3_type0.html) barcodes"
echo "type/1:      $(grep -c 'DNCPEMCHW' /tmp/r3_type1.html) barcodes"

echo ""
echo "=== Pagination info ==="
echo -n "is_rework/0: "; grep -oP '共\s*\d+\s*条记录|\d+\s*页' /tmp/r3_rework0.html | head -2
echo -n "is_rework/2: "; grep -oP '共\s*\d+\s*条记录|\d+\s*页' /tmp/r3_rework2.html | head -2
echo -n "type/0:      "; grep -oP '共\s*\d+\s*条记录|\d+\s*页' /tmp/r3_type0.html | head -2
echo -n "type/1:      "; grep -oP '共\s*\d+\s*条记录|\d+\s*页' /tmp/r3_type1.html | head -2

echo ""
echo "=== is_rework/0: first 3 data rows td[0] (operation type) ==="
grep -oP '<td[^>]*>[^<]*</td>' /tmp/r3_rework0.html | head -20

echo ""
echo "=== is_rework/0: pagination links ==="
grep -oP '/Cron/Jili/lists/[^"]+' /tmp/r3_rework0.html | head -5
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r3_compare.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r3_compare.sh"

Remove-Item $tmpFile -Force
