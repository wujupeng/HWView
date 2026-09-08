import re
import glob

files = ['/tmp/hw_0906_path.html'] + sorted([f for f in glob.glob('/tmp/hw_0906_p*.html') if 'path' not in f])

all_rows = []
for filepath in files:
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        html = f.read()
    rows = re.findall(r'<tr.*?</tr>', html, re.DOTALL)
    data_rows = [r for r in rows if 'DNCPEMCHW' in r]
    for row in data_rows:
        tds = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
        clean_tds = [re.sub(r'<[^>]+>', '', td).strip() for td in tds]
        all_rows.append((filepath, clean_tds, row))

# Check td[0] distribution (operation type)
from collections import Counter
op_types = Counter()
for fp, tds, raw in all_rows:
    if len(tds) >= 1:
        op_types[tds[0]] += 1

print("=== Operation type (td[0]) distribution ===")
for op, cnt in op_types.most_common():
    print(f"  '{op}': {cnt} records")

# Check if there are any non-"补打" records
print(f"\nTotal: {sum(op_types.values())} records")
print(f"Unique operation types: {len(op_types)}")

# Extract source_id from raw HTML (not from cleaned tds)
source_ids = set()
for fp, tds, raw in all_rows:
    sid_match = re.search(r'printload/id/(\d+)', raw)
    if sid_match:
        source_ids.add(int(sid_match.group(1)))
print(f"\nC (unique source_ids from raw HTML): {len(source_ids)}")

# Barcode sequence number analysis
seq_nums = set()
for fp, tds, raw in all_rows:
    if len(tds) >= 2:
        bc = tds[1]
        parts = bc.split('.')
        if len(parts) >= 2:
            try:
                seq = int(parts[1])
                seq_nums.add(seq)
            except ValueError:
                pass

print(f"\n=== Barcode sequence analysis ===")
print(f"Unique sequence numbers: {len(seq_nums)}")
if seq_nums:
    print(f"Min seq: {min(seq_nums)}")
    print(f"Max seq: {max(seq_nums)}")
    print(f"Range: {max(seq_nums) - min(seq_nums) + 1}")
    print(f"Coverage: {len(seq_nums)}/{max(seq_nums) - min(seq_nums) + 1} = {len(seq_nums)/(max(seq_nums) - min(seq_nums) + 1)*100:.1f}%")

# Check 09-07 data from DB
print("\n=== 09-07 DB records (for comparison) ===")
import subprocess
result = subprocess.run(['sqlite3', '/opt/hwview/data/hwview.db',
    'SELECT count(*), count(DISTINCT barcode), sum(quantity) FROM TBL_PRODUCTION_RECORD;'],
    capture_output=True, text=True)
print(f"  count/unique_bc/sum_qty: {result.stdout.strip()}")

result = subprocess.run(['sqlite3', '/opt/hwview/data/hwview.db',
    'SELECT min(created_at), max(created_at) FROM TBL_PRODUCTION_RECORD;'],
    capture_output=True, text=True)
print(f"  time range: {result.stdout.strip()}")

# Check quantity values in DB
result = subprocess.run(['sqlite3', '/opt/hwview/data/hwview.db',
    'SELECT quantity, count(*) FROM TBL_PRODUCTION_RECORD GROUP BY quantity ORDER BY quantity;'],
    capture_output=True, text=True)
print(f"  quantity distribution:\n{result.stdout.strip()}")