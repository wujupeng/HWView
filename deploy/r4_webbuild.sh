#!/bin/bash
set -e
cd /tmp/hwview-web
echo "=== npm install ==="
npm install --no-audit --no-fund 2>&1 | tail -3
echo "=== npm run build ==="
npm run build 2>&1 | tail -15
echo "=== dist contents ==="
ls -la dist/ | head -15
echo "=== DONE ==="