#!/bin/bash
KEY="hwview-shadow-deploy"
curl -s -H "X-Admin-Key: $KEY" "http://localhost/api/v1/reports/daily-output-plan?start_date=2026-09-06&end_date=2026-09-06" > /tmp/e1e4_single.json
python3 << 'PYEOF'
import json
d = json.load(open('/tmp/e1e4_single.json'))
m = d['matrix']
cum = d['cumulative']
r6 = m[5][0] or 0
r9 = m[8][0] or 0
checks = [
    ('E1 row6 cum=2000', cum[5] == 2000, cum[5]),
    ('E2 row7 cum=1980', cum[6] == 1980, cum[6]),
    ('E3 row8 cum=1680', cum[7] == 1680, cum[7]),
    ('E4 row9=300', r9 == 300, r9),
    ('row6 formula=2000', r6 == 2000, r6),
]
all_pass = True
for name, ok, val in checks:
    if not ok: all_pass = False
    print(f"{name}: {'PASS' if ok else 'FAIL'} (got {val})")
print('E1-E4 BASELINE: ' + ('ALL PASS' if all_pass else 'FAIL'))
PYEOF

echo "=== Export E1-E4 baseline xlsx evidence ==="
curl -s -o /tmp/r4_evidence/102_daily_output_plan_baseline_2026-09-06.xlsx -H "X-Admin-Key: $KEY" "http://localhost/api/v1/reports/daily-output-plan/export?start_date=2026-09-06&end_date=2026-09-06" -w "HTTP %{http_code}\n"

echo "=== Refresh audit evidence ==="
sqlite3 /opt/hwview/data/hwview.db -json "SELECT id, actor, action, target_type, target_id, substr(change,1,120) AS change, created_at FROM TBL_AUDIT_LOG ORDER BY id;" > /tmp/r4_evidence/audit_log_sample.json
echo "audit total: $(sqlite3 /opt/hwview/data/hwview.db 'SELECT COUNT(*) FROM TBL_AUDIT_LOG;')"
echo "ALL DONE"