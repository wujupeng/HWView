#!/bin/bash
echo "=== 1. 9月7日源系统采集记录 ==="
sqlite3 /opt/hwview/data/hwview.db "SELECT COUNT(*) as total, SUM(quantity) as sum_qty, MIN(quantity) as min_qty, MAX(quantity) as max_qty FROM TBL_PRODUCTION_RECORD WHERE production_date='2026-09-07';"
echo "--- 记录明细（前20条）---"
sqlite3 -header /opt/hwview/data/hwview.db "SELECT id, barcode, quantity, production_date, line_code, product_code FROM TBL_PRODUCTION_RECORD WHERE production_date='2026-09-07' LIMIT 20;"
echo "--- quantity分布 ---"
sqlite3 -header /opt/hwview/data/hwview.db "SELECT quantity, COUNT(*) as cnt FROM TBL_PRODUCTION_RECORD WHERE production_date='2026-09-07' GROUP BY quantity ORDER BY quantity;"

echo "=== 2. 全部记录操作类型 ==="
sqlite3 -header /opt/hwview/data/hwview.db "SELECT COUNT(*) as total FROM TBL_PRODUCTION_RECORD;"
sqlite3 -header /opt/hwview/data/hwview.db ".schema TBL_PRODUCTION_RECORD" | head -20

echo "=== 3. 9月7日 TBL_DAILY_PRODUCTION_PLAN 录入数据 ==="
sqlite3 -header /opt/hwview/data/hwview.db "SELECT id, plan_date, row_no, value, carton_count, units_per_carton_snapshot, loose_quantity, actual_quantity, line_code, input_by FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date LIKE '2026-09-07%' ORDER BY row_no;"

echo "=== 4. 装箱规格配置 ==="
sqlite3 -header /opt/hwview/data/hwview.db "SELECT * FROM TBL_CARTON_SPECIFICATION;"

echo "=== 5. 源系统数据源配置 ==="
sqlite3 -header /opt/hwview/data/hwview.db "SELECT id, source_name, source_type, endpoint, adapter_type, is_active FROM TBL_DATA_SOURCE;"

echo "=== 6. 采集游标 ==="
sqlite3 -header /opt/hwview/data/hwview.db "SELECT * FROM TBL_COLLECT_CURSOR;"

echo "ALL DONE"