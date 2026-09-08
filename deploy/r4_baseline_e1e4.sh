#!/bin/bash
set -e
KEY="hwview-shadow-deploy"
BASE="http://localhost/api/v1"

echo "=== 1. Audit actor verification (authenticated input) ==="
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":5,"carton_count":0,"loose_quantity":0,"line_code":"HW102","product_code":"HW102","input_by":"admin"}' > /dev/null
sqlite3 /opt/hwview/data/hwview.db "SELECT id, actor, action, target_id FROM TBL_AUDIT_LOG ORDER BY id DESC LIMIT 1;"

echo "=== 2. E1-E4 baseline ledger input (2026-09-06) ==="
echo "--- E1: row6 cumulative=2000 -> row2=1500, row3=500, row5=0 ---"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":1,"value":2000,"input_by":"admin"}' > /dev/null && echo "row1 target=2000 OK"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":2,"carton_count":50,"loose_quantity":0,"line_code":"HW102","product_code":"HW102","input_by":"admin"}' > /dev/null && echo "row2=50cartons*30=1500 OK"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":3,"carton_count":16,"loose_quantity":20,"line_code":"HW102","product_code":"HW102","input_by":"admin"}' > /dev/null && echo "row3=16*30+20=500 OK"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":5,"carton_count":0,"loose_quantity":0,"line_code":"HW102","product_code":"HW102","input_by":"admin"}' > /dev/null && echo "row5=0 OK"

echo "--- E2: row7 cumulative=1980 (inbound) ---"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":7,"value":1980,"input_by":"admin"}' > /dev/null && echo "row7=1980 OK"

echo "--- E3: row8 cumulative=1680 (shipment) ---"
curl -s -X POST $BASE/reports/daily-plan -H "Content-Type: application/json" -H "X-Admin-Key: $KEY" -d '{"plan_date":"2026-09-06","row_no":8,"value":1680,"input_by":"admin"}' > /dev/null && echo "row8=1680 OK"

echo "=== 3. Verify E1-E4 baselines ==="
curl -s -H "X-Admin-Key: $KEY" "$BASE/reports/daily-output-plan?start_date=2026-09-06&end_date=2026-09-08" | python3 -c "
import json, sys
d = json.load(sys.stdin)
m = d['matrix']
cum = d['cumulative']
print('matrix (2026-09-06 col):')
for i, name in enumerate(d['row_names']):
    print(f'  row{i+1} {name}: {m[i][0]}')
r6 = m[5][0] or 0
r7 = m[6][0] or 0
r8 = m[7][0] or 0
r9 = m[8][0] or 0
print()
print('=== E1-E4 BASELINE CHECK ===')
checks = [
    ('E1 row6 cumulative=2000', cum[5] == 2000, cum[5]),
    ('E2 row7 cumulative=1980', cum[6] == 1980, cum[6]),
    ('E3 row8 cumulative=1680', cum[7] == 1680, cum[7]),
    ('E4 row9=300 (1980-1680)', r9 == 300, r9),
    ('row6 formula 09-06: 1500+500+0=2000', r6 == 2000, r6),
]
all_pass = True
for name, ok, val in checks:
    status = 'PASS' if ok else 'FAIL'
    if not ok: all_pass = False
    print(f'  {name}: {status} (got {val})')
print('ALL E1-E4: ' + ('PASS' if all_pass else 'FAIL'))
"

echo "=== 4. Final audit log (actor filled) ==="
sqlite3 /opt/hwview/data/hwview.db "SELECT id, actor, action, target_id FROM TBL_AUDIT_LOG ORDER BY id DESC LIMIT 8;"
echo "ALL DONE"