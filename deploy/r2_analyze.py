import re
import glob

files = sorted(glob.glob('/tmp/hw_0906_p*.html'))
# Also include the path file as page 1
files = ['/tmp/hw_0906_path.html'] + [f for f in files if 'path' not in f]

all_rows = []
for filepath in files:
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        html = f.read()
    rows = re.findall(r'<tr.*?</tr>', html, re.DOTALL)
    data_rows = [r for r in rows if 'DNCPEMCHW' in r]
    for row in data_rows:
        tds = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
        clean_tds = [re.sub(r'<[^>]+>', '', td).strip() for td in tds]
        all_rows.append((filepath, clean_tds))

print(f"=== Total data rows across all pages: {len(all_rows)} ===")

# Show first 3 rows structure
print("\n=== First 3 rows structure ===")
for i, (fp, tds) in enumerate(all_rows[:3]):
    print(f"\n--- Row {i+1} ({len(tds)} tds) from {fp} ---")
    for j, td in enumerate(tds):
        print(f"  td[{j}]: {td}")

# Extract quantity (3rd td, index 2) and created_at (5th td, index 4)
print("\n=== Quantity extraction (td index 2) ===")
quantities = []
for fp, tds in all_rows:
    if len(tds) >= 3:
        try:
            q = int(tds[2])
            quantities.append(q)
        except ValueError:
            quantities.append(None)

valid_qs = [q for q in quantities if q is not None]
print(f"Valid quantities: {len(valid_qs)}")
print(f"Invalid/missing: {len(quantities) - len(valid_qs)}")

from collections import Counter
dist = Counter(valid_qs)
print(f"\nQuantity distribution:")
for q, cnt in sorted(dist.items()):
    print(f"  quantity={q}: {cnt} records")

print(f"\nD (sum of quantity): {sum(valid_qs)}")
print(f"A (total records): {len(all_rows)}")

# Unique barcodes
barcodes = set()
source_ids = set()
for fp, tds in all_rows:
    if len(tds) >= 2:
        barcodes.add(tds[1])
    # Extract source_id from printload URL
    row_html = ' '.join(tds)
    sid_match = re.search(r'printload/id/(\d+)', row_html)
    if sid_match:
        source_ids.add(int(sid_match.group(1)))

print(f"B (unique barcodes): {len(barcodes)}")
print(f"C (unique source_ids): {len(source_ids)}")

# Time range
times = []
for fp, tds in all_rows:
    if len(tds) >= 5:
        times.append(tds[4])
if times:
    print(f"\nTime range: {min(times)} ~ {max(times)}")

# Batch distribution
batches = Counter()
for fp, tds in all_rows:
    if len(tds) >= 4:
        batches[tds[3]] += 1
print(f"\nBatch distribution ({len(batches)} unique batches):")
for batch, cnt in sorted(batches.items()):
    print(f"  {batch}: {cnt} records")