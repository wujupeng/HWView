$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

& $pscp -pw $pw -batch -hostkey $hostkey "C:\Users\DELL\IDEProjects\HWView\deploy\r2_analyze.py" "${target}:/tmp/r2_analyze.py"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "python3 /tmp/r2_analyze.py"