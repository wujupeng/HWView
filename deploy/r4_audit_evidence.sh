#!/bin/bash
set -e
echo "=== 1. Deploy new binary ==="
echo "9090" | sudo -S systemctl stop hwview-server
sleep 2
cp /tmp/hwview-server-r4c /opt/hwview/bin/hwview-server
chmod +x /opt/hwview/bin/hwview-server
echo "9090" | sudo -S systemctl start hwview-server
sleep 2
echo "9090" | sudo -S systemctl is-active hwview-server

echo "=== 2. Trigger audit events ==="
echo "--- REPORT_INPUT (carton mode row5) ---"
curl -s -X POST http://localhost:8080/api/v1/reports/daily-plan -H 'Content-Type: application/json' -d '{"plan_date":"2026-09-08","row_no":5,"carton_count":17,"loose_quantity":9,"line_code":"HW102","product_code":"HW102","input_by":"admin"}'
echo
echo "--- REPORT_INPUT (value mode row1) ---"
curl -s -X POST http://localhost:8080/api/v1/reports/daily-plan -H 'Content-Type: application/json' -d '{"plan_date":"2026-09-08","row_no":1,"value":2000,"input_by":"admin"}'
echo
echo "--- HOLIDAY_CONFIG ---"
curl -s -X POST http://localhost:8080/api/v1/reports/holidays -H 'Content-Type: application/json' -d '{"holiday_date":"2026-10-01","holiday_name":"National Day","is_rest":true,"config_by":"admin"}'
echo
echo "--- REPORT_EXPORT ---"
curl -s -o /tmp/r4_evidence/102_daily_output_plan_2026-09-07_to_2026-09-08.xlsx "http://localhost:8080/api/v1/reports/daily-output-plan/export?start_date=2026-09-07&end_date=2026-09-08" -w "HTTP %{http_code}\n"

echo "=== 3. Verify audit log ==="
sqlite3 /opt/hwview/data/hwview.db -json "SELECT id, actor, action, target_type, target_id, substr(change,1,120) AS change, created_at FROM TBL_AUDIT_LOG ORDER BY id;" > /tmp/r4_evidence/audit_log_sample.json
python3 -c "
import json
entries = json.load(open('/tmp/r4_evidence/audit_log_sample.json'))
print(f'audit entries: {len(entries)}')
for e in entries:
    print(f\"  [{e['action']}] {e['target_type']} -> {e['target_id']} by {e['actor']}\")
"

echo "=== 4. Report matrix 2 days ==="
curl -s "http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-08" > /tmp/r4_evidence/report_api_response_2days.json
python3 -c "
import json
d = json.load(open('/tmp/r4_evidence/report_api_response_2days.json'))
print('dates:', d['dates'])
for i, name in enumerate(d['row_names']):
    print(f'  row{i+1} {name}: {d[\"matrix\"][i]}')
"

echo "=== 5. Carton spec evidence ==="
curl -s "http://localhost:8080/api/v1/config/carton-spec" > /tmp/r4_evidence/carton_spec_response.json
echo "ALL DONE"