#!/bin/bash
DB=/opt/hwview/data/hwview.db
TODAY=$(date +%Y-%m-%d)
echo "=== Today: $TODAY ==="

echo "=== 1. Dashboard data source: TBL_PRODUCTION_RECORD ==="
echo "--- 1a. BoxCount = COUNT(*) (record count, NOT carton_count) ---"
sqlite3 -header $DB "SELECT line_id, COUNT(*) as box_count FROM TBL_PRODUCTION_RECORD WHERE production_date='$TODAY' GROUP BY line_id;"
echo "--- 1b. PieceCount = SUM(quantity) (source quantity, NOT actual_quantity) ---"
sqlite3 -header $DB "SELECT line_id, SUM(quantity) as piece_count FROM TBL_PRODUCTION_RECORD WHERE production_date='$TODAY' GROUP BY line_id;"
echo "--- 1c. Total ---"
sqlite3 -header $DB "SELECT COUNT(*) as total_box_count, SUM(quantity) as total_piece_count FROM TBL_PRODUCTION_RECORD WHERE production_date='$TODAY';"

echo "=== 2. Verify via API ==="
curl -s -H "X-Admin-Key: hwview-shadow-deploy" "http://localhost/api/v1/statistics/overview?date=$TODAY" | python3 -m json.tool 2>/dev/null || curl -s -H "X-Admin-Key: hwview-shadow-deploy" "http://localhost/api/v1/statistics/overview?date=$TODAY"

echo "=== 3. quantity distribution today ==="
sqlite3 -header $DB "SELECT quantity, COUNT(*) as cnt FROM TBL_PRODUCTION_RECORD WHERE production_date='$TODAY' GROUP BY quantity ORDER BY quantity;"

echo "=== 4. Compare: TBL_DAILY_PRODUCTION_PLAN (R4 correct source) ==="
sqlite3 -header $DB "SELECT plan_date, row_no, carton_count, units_per_carton_snapshot, loose_quantity, actual_quantity FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date LIKE '$TODAY%' ORDER BY row_no;"
echo "--- 4b. R4 correct totals ---"
sqlite3 -header $DB "SELECT SUM(carton_count) as correct_box_count, SUM(actual_quantity) as correct_piece_count FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date LIKE '$TODAY%' AND actual_quantity IS NOT NULL;"

echo "=== 5. All dates record count ==="
sqlite3 -header $DB "SELECT production_date, COUNT(*) as records, SUM(quantity) as sum_qty FROM TBL_PRODUCTION_RECORD GROUP BY production_date ORDER BY production_date;"

echo "=== 6. Lines table ==="
sqlite3 -header $DB "SELECT id, line_code, line_name FROM TBL_PRODUCTION_LINE;"

echo "ALL DONE"