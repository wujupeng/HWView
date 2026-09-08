#!/bin/bash
set -e
echo "=== Deploy ==="
echo "9090" | sudo -S systemctl stop hwview-server
sleep 2
cp /tmp/hwview-server-r4d /opt/hwview/bin/hwview-server
chmod +x /opt/hwview/bin/hwview-server
echo "9090" | sudo -S systemctl start hwview-server
sleep 2
echo "9090" | sudo -S systemctl is-active hwview-server

echo "=== Export xlsx with aux columns ==="
curl -s -o /tmp/r4_evidence/102_daily_output_plan_2026-09-07_to_2026-09-08.xlsx "http://localhost:8080/api/v1/reports/daily-output-plan/export?start_date=2026-09-07&end_date=2026-09-08" -w "HTTP %{http_code}\n"

echo "=== Verify xlsx content ==="
python3 << 'PYEOF'
import zipfile, re
path = "/tmp/r4_evidence/102_daily_output_plan_2026-09-07_to_2026-09-08.xlsx"
z = zipfile.ZipFile(path)
sheet = z.read("xl/worksheets/sheet1.xml").decode("utf-8")
shared = z.read("xl/sharedStrings.xml").decode("utf-8")
strings = re.findall(r"<t[^>]*>([^<]*)</t>", shared)
print("shared strings:", strings)
for keyword in ["箱数", "装箱规格", "散件", "实际件数", "102日产出计划"]:
    found = keyword in shared
    print(f"  '{keyword}': {'PASS' if found else 'MISSING'}")
values = re.findall(r"<v>([^<]*)</v>", sheet)
print("numeric values:", values)
PYEOF

echo "=== Audit log count ==="
sqlite3 /opt/hwview/data/hwview.db "SELECT COUNT(*) FROM TBL_AUDIT_LOG;"

echo "=== Refresh evidence files ==="
sqlite3 /opt/hwview/data/hwview.db -json "SELECT id, actor, action, target_type, target_id, substr(change,1,120) AS change, created_at FROM TBL_AUDIT_LOG ORDER BY id;" > /tmp/r4_evidence/audit_log_sample.json
curl -s "http://localhost:8080/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-08" > /tmp/r4_evidence/report_api_response_2days.json
echo "ALL DONE"