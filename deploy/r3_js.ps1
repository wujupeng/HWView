$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
echo "=== All /Cron/ URLs in show page ==="
grep -oP '/Cron/[A-Za-z]+/[A-Za-z]+[^"'"'"' ]*' /tmp/r3_show.html | sort -u

echo ""
echo "=== attr-url values ==="
grep -oP 'attr-url="[^"]+"' /tmp/r3_show.html | sort -u

echo ""
echo "=== AJAX/POST/GET calls in JS ==="
grep -oP 'url\s*[:=]\s*["'"'"'][^"'"'"']+["'"'"']' /tmp/r3_show.html | sort -u

echo ""
echo "=== Last 80 lines (JS section) ==="
tail -80 /tmp/r3_show.html
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r3_js.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r3_js.sh"

Remove-Item $tmpFile -Force
