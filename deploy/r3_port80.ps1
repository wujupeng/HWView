$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

# Check port 80
Write-Host "=== Port 80 root ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "curl -s -o /tmp/r3_port80.html -w 'HTTP %{http_code}, %{size_download} bytes' 'http://192.168.30.2:80/' && echo '' && head -50 /tmp/r3_port80.html"

Write-Host "`n=== Port 80 /Cron/Jili/lists/ ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "curl -s -o /dev/null -w 'HTTP %{http_code}, %{size_download} bytes' 'http://192.168.30.2:80/Cron/Jili/lists/'"