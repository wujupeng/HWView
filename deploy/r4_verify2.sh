#!/bin/bash
echo "admin9090" | sudo -S systemctl stop hwview-server 2>/dev/null
echo "9090" | sudo -S systemctl stop hwview-server
sleep 2
cp /tmp/hwview-server-r4b /opt/hwview/bin/hwview-server
chmod +x /opt/hwview/bin/hwview-server
echo "9090" | sudo -S systemctl start hwview-server
sleep 2
echo "=== SERVICE STATUS ==="
echo "9090" | sudo -S systemctl is-active hwview-server
echo "=== REPORT MATRIX ==="
curl -s 'http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07' | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('dates:', d['dates'])
print('matrix:')
for i, name in enumerate(d['row_names']):
    vals = d['matrix'][i]
    print(f'  row{i+1} {name}: {vals}')
print('cumulative:', d['cumulative'])
m = d['matrix']
r1 = m[0][0] or 0
r2 = m[1][0] or 0
r3 = m[2][0] or 0
r4 = m[3][0] or 0
r5 = m[4][0] or 0
r6 = m[5][0] or 0
expected = r2 + r3 + r5
print()
print(f'=== FORMULA CHECK ===')
print(f'row1 (target old):  {r1}')
print(f'row2 (actual day):   {r2}')
print(f'row3 (actual night): {r3}')
print(f'row4 (target new):   {r4}')
print(f'row5 (actual new):   {r5}')
print(f'row6 (total):        {r6}')
print(f'expected row6 = row2+row3+row5 = {r2}+{r3}+{r5} = {expected}')
if r6 == expected:
    print('R4-BLOCKER-02 Formula: PASS')
else:
    print('R4-BLOCKER-02 Formula: FAIL')
if r5 == 519:
    print('R2-AMENDMENT actual_quantity=519: PASS')
else:
    print('R2-AMENDMENT actual_quantity=519: FAIL (got', r5, ')')
if r1 == 2000:
    print('Row1 target=2000: PASS')
else:
    print('Row1 target=2000: FAIL (got', r1, ')')
if r2 == 305:
    print('Row2 actual=305: PASS')
else:
    print('Row2 actual=305: FAIL (got', r2, ')')
"