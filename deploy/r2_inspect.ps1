$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

# Show raw HTML of first 3 data rows from page 1
$cmd = 'python3 -c "
import re
with open('"'"'/tmp/hw_0906_p1.html'"'"', '"'"'r'"'"') as f:
    html = f.read()
# Find all tr blocks containing DNCPEMCHW
rows = re.findall(r'"'"'<tr.*?</tr>'"'"', html, re.DOTALL)
data_rows = [r for r in rows if '"'"'DNCPEMCHW'"'"' in r]
print(f'"'"'Found {len(data_rows)} data rows'"'"')
for i, row in enumerate(data_rows[:3]):
    tds = re.findall(r'"'"'<td[^>]*>(.*?)</td>'"'"', row, re.DOTALL)
    print(f'"'"'\n--- Row {i+1} ({len(tds)} tds) ---'"'"')
    for j, td in enumerate(tds):
        clean = re.sub(r'"'"'<[^>]+>'"'"', '"'"''"'"', td).strip()
        print(f'"'"'  td[{j}]: {clean}'"'"')
"'

& $plink -ssh -pw $pw -batch -hostkey $hostkey $target $cmd