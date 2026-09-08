$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

& $pscp -pw $pw -batch -hostkey $hostkey "C:\Users\DELL\IDEProjects\HWView\bin\hwview-server" "${target}:/tmp/hwview-server-r4b"

$script = @'
#!/bin/bash
echo "9090" | sudo -S systemctl stop hwview-server
sleep 2
cp /tmp/hwview-server-r4b /opt/hwview/bin/hwview-server
chmod +x /opt/hwview/bin/hwview-server
echo "9090" | sudo -S systemctl start hwview-server
sleep 2
curl -s "http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07" > /tmp/r4_report.json
python3 << 'PYEOF'
import json
with open("/tmp/r4_report.json") as f:
    d = json.load(f)
m = d["matrix"]
r1 = m[0][0] or 0
r2 = m[1][0] or 0
r3 = m[2][0] or 0
r4 = m[3][0] or 0
r5 = m[4][0] or 0
r6 = m[5][0] or 0
print(f"row1(目标老线):  {r1}")
print(f"row2(老线白班):  {r2}")
print(f"row3(老线夜班):  {r3}")
print(f"row4(目标新线):  {r4}")
print(f"row5(新线实际):  {r5}")
print(f"row6(合计):     {r6}")
expected = r2 + r3 + r5
print(f"Expected row6 = row2+row3+row5 = {r2}+{r3}+{r5}%s = {expected}" % ("+0" if r4 == 0 else ""))
print(f"R4-BLOCKER-02 Formula: {'F' if r6 == expected else 'FAIL'}{'PASS' if r6 == expected else ''}")
if r5 == 519:
    print(f"R2-AMENDMENT actual_quantity=519: PASS")
PYEOF
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r4_verify.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r4_verify.sh"

Remove-Item $tmpFile -Force
