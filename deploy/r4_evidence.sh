#!/bin/bash
set -e
mkdir -p /tmp/r4_evidence
cd /tmp/r4_evidence

echo "=== 1. Export xlsx sample ==="
curl -s -o "102_daily_output_plan_2026-09-07.xlsx" "http://localhost:8080/api/v1/reports/daily-output-plan/export?start_date=2026-09-07&end_date=2026-09-07" -w "HTTP %{http_code}\n"
file "102_daily_output_plan_2026-09-07.xlsx"

echo "=== 2. Extract audit log sample ==="
sqlite3 /opt/hwview/data/hwview.db -json "SELECT * FROM TBL_AUDIT_LOG ORDER BY id DESC LIMIT 20;" > audit_log_sample.json 2>/dev/null || echo "[]" > audit_log_sample.json
echo "audit log entries: $(python3 -c "import json; print(len(json.load(open('/tmp/r4_evidence/audit_log_sample.json'))))" 2>/dev/null || echo 0)"

echo "=== 3. Report API evidence JSON ==="
curl -s "http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07" > report_api_response.json
python3 -c "import json; d=json.load(open('/tmp/r4_evidence/report_api_response.json')); print('matrix row6:', d['matrix'][5], 'row5:', d['matrix'][4])"

echo "=== 4. Carton spec evidence ==="
curl -s "http://localhost:8080/api/v1/config/carton-spec" > carton_spec_response.json
echo "saved"

echo "=== 5. List all files ==="
ls -la /tmp/r4_evidence/
echo "=== ALL DONE ==="