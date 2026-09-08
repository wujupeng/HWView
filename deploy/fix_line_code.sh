#!/bin/bash
sudo -S sqlite3 /opt/hwview/data/hwview.db "UPDATE TBL_PRODUCTION_LINE SET line_code='HW102' WHERE id=2;" <<< "9090"
echo "--- After update ---"
sudo -S sqlite3 /opt/hwview/data/hwview.db "SELECT id, line_code, line_name FROM TBL_PRODUCTION_LINE;" <<< "9090"