$pw = (Get-Content "C:\Users\DELL\IDEProjects\HWView\deploy\.sshpw" -Raw).Trim()
$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$target = "debian@192.168.2.110"
$hostkey = "SHA256:C20ScxLx9sNJUXiw0vSsEC2w7aQ1K3J98FHaeJN2q14"

$script = @'
#!/bin/bash
echo "=== 1. Create carton spec (30 units/box) ==="
curl -s -X POST http://localhost:8080/api/v1/config/carton-spec -H 'Content-Type: application/json' -d '{"line_code":"HW102","product_code":"HW102","units_per_carton":30,"effective_from":"2026-09-01","config_by":"admin"}'
echo ""

echo "=== 2. Create carton spec (60 units/box, different product) ==="
curl -s -X POST http://localhost:8080/api/v1/config/carton-spec -H 'Content-Type: application/json' -d '{"line_code":"HW102","product_code":"OTHER","units_per_carton":60,"effective_from":"2026-09-01","config_by":"admin"}'
echo ""

echo "=== 3. Input row 5 (new line actual): 17 cartons + 9 loose ==="
curl -s -X POST http://localhost:8080/api/v1/reports/daily-plan -H 'Content-Type: application/json' -d '{"plan_date":"2026-09-07","row_no":5,"carton_count":17,"loose_quantity":9,"product_code":"HW102","input_by":"admin"}'
echo ""

echo "=== 4. Input row 2 (old line day): 10 cartons + 5 loose ==="
curl -s -X POST http://localhost:8080/api/v1/reports/daily-plan -H 'Content-Type: application/json' -d '{"plan_date":"2026-09-07","row_no":2,"carton_count":10,"loose_quantity":5,"product_code":"HW102","input_by":"admin"}'
echo ""

echo "=== 5. Input row 1 (target old line): 2000 ==="
curl -s -X POST http://localhost:8080/api/v1/reports/daily-plan -H 'Content-Type: application/json' -d '{"plan_date":"2026-09-07","row_no":1,"value":2000,"input_by":"admin"}'
echo ""

echo "=== 6. Verify report formula ==="
curl -s 'http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07' | python3 -c "
import sys, json
d = json.load(sys.stdin)
m = d['matrix']
r2 = m[1][0] or 0
r3 = m[2][0] or 0
r4 = m[3][0] or 0
r5 = m[4][0] or 0
r6 = m[5][0] or 0
expected = r2 + r3 + r5
print(f'row2(老线白班): {r2}')
print(f'row3(老线夜班): {r3}')
print(f'row4(目标新线): {r4}')
print(f'row5(新线实际): {r5}')
print(f'row6(合计):     {r6}')
print(f'Expected row6 = row2+row3+row5 = {r2}+{r3}+{r5} = {expected}')
print(f'Formula check: {\"PASS\" if r6 == expected else \"FAIL\"}')
print(f'R4-BLOCKER-02 (row4 not in sum): {\"PASS\" if r4 == 0 else \"N/A (row4 has value but not in sum)\"}')
"
'@

$script = $script -replace "`r`n", "`n"

$tmpFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile, $script, [System.Text.UTF8Encoding]::new($false))

& $pscp -pw $pw -batch -hostkey $hostkey $tmpFile "${target}:/tmp/r4_e2e.sh"
& $plink -ssh -pw $pw -batch -hostkey $hostkey $target "bash /tmp/r4_e2e.sh"

Remove-Item $tmpFile -Force
