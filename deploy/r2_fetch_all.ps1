$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$cmd = 'for i in 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do curl -s -o /tmp/hw_0906_p${i}.html "http://192.168.30.2:86/Cron/Jili/lists/start_date_time/2026-09-06%2000:00:00/end_date_time/2026-09-06%2023:59:59/p/${i}"; sz=$(stat -c%s /tmp/hw_0906_p${i}.html 2>/dev/null); echo "Page ${i}: ${sz} bytes"; done; echo "--- Done ---"'

& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd
