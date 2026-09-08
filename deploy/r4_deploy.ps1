$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$cmd = "echo '$pw' | sudo -S systemctl stop hwview-server && sleep 1 && cp /tmp/hwview-server-r4 /opt/hwview/bin/hwview-server && chmod +x /opt/hwview/bin/hwview-server && echo '$pw' | sudo -S systemctl start hwview-server && sleep 2 && echo '$pw' | sudo -S systemctl status hwview-server --no-pager -l"

Write-Host "=== Stop, replace, start ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd

Write-Host "`n=== Test health ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "curl -s http://localhost:8080/api/v1/health"

Write-Host "`n=== Test carton spec API ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "curl -s http://localhost:8080/api/v1/config/carton-spec"

Write-Host "`n=== Test report API ==="
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "curl -s 'http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-05&end_date=2026-09-10' | python3 -m json.tool 2>/dev/null | head -50"
