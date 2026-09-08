$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
echo "=== Port scan 192.168.30.2 ==="
for port in 80 81 82 83 84 85 86 87 88 89 443 800 8080 8443 8888 9090 3000 5000 7000 9000; do
  (echo >/dev/tcp/192.168.30.2/$port) 2>/dev/null && echo "Port $port: OPEN" || echo "Port $port: closed"
done
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r3_ports.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r3_ports.sh"

Remove-Item $tmpFile -Force
