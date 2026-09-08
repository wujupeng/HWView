#!/bin/bash
echo '=== TEST DATE FUNCTION ==='
sqlite3 /opt/hwview/data/hwview.db "SELECT DATE(plan_date), plan_date, row_no, actual_quantity FROM TBL_DAILY_PRODUCTION_PLAN;"
echo '=== TEST DATE QUERY ==='
sqlite3 /opt/hwview/data/hwview.db "SELECT COUNT(*) FROM TBL_DAILY_PRODUCTION_PLAN WHERE DATE(plan_date) >= '2026-09-07' AND DATE(plan_date) <= '2026-09-07' AND line_code = 'HW102';"
echo '=== TEST PLAIN QUERY ==='
sqlite3 /opt/hwview/data/hwview.db "SELECT COUNT(*) FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date >= '2026-09-07' AND plan_date <= '2026-09-07' AND line_code = 'HW102';"
echo '=== CURL PLANS ==='
curl -s 'http://localhost:8080/api/v1/reports/daily-plan?start_date=2026-09-07&end_date=2026-09-07'
echo
echo '=== CURL REPORT MATRIX ==='
curl -s 'http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07' | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('dates:', d['dates'])
print('matrix:')
for i, name in enumerate(d['row_names']):
    vals = d['matrix'][i]
    print(f'  row{i+1} {name}: {vals}')
print('cumulative:', d['cumulative'])
"