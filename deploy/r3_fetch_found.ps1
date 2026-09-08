$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

# Fetch and save all found endpoints
$cmd1 = 'curl -s "http://192.168.30.2:86/Cron/Jili/printload" -o /tmp/r3_printload.html && echo "printload: $(wc -c < /tmp/r3_printload.html) bytes"'
$cmd2 = 'curl -s "http://192.168.30.2:86/Cron/Jili/printload/id/146978" -o /tmp/r3_printload_id.html && echo "printload/id: $(wc -c < /tmp/r3_printload_id.html) bytes"'
$cmd3 = 'curl -s "http://192.168.30.2:86/Cron/Jili/show/id/146978" -o /tmp/r3_show.html && echo "show: $(wc -c < /tmp/r3_show.html) bytes"'
$cmd4 = 'curl -s "http://192.168.30.2:86/Cron/Jili/get/id/146978" -o /tmp/r3_get.txt && echo "get: $(wc -c < /tmp/r3_get.txt) bytes"'

Write-Host "=== Fetching endpoints ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd1
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd2
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd3
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd4

# Show content of show endpoint (most interesting)
Write-Host "`n=== /Cron/Jili/show/id/146978 (first 200 lines) ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "head -200 /tmp/r3_show.html"

Write-Host "`n=== /Cron/Jili/printload (first 100 lines) ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "head -100 /tmp/r3_printload.html"

Write-Host "`n=== /Cron/Jili/get/id/146978 ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "cat /tmp/r3_get.txt"