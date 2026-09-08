#!/bin/bash
set -euo pipefail

DEPLOY_SERVER="${DEPLOY_SERVER:-192.168.2.110}"
DEPLOY_USER="${DEPLOY_USER:-debian}"

echo "=== HWView Remote Install Script ==="
echo "Target: ${DEPLOY_USER}@${DEPLOY_SERVER}"
echo ""

echo "Checking prerequisites..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "
    if ! command -v sqlite3 &> /dev/null; then
        echo 'Installing sqlite3...'
        sudo apt-get update -qq && sudo apt-get install -y -qq sqlite3
    fi
    if ! id debian &> /dev/null; then
        echo 'ERROR: debian user not found'
        exit 1
    fi
    echo 'Prerequisites OK'
"

echo "Verifying services..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "
    if systemctl is-active --quiet hwview-server; then
        echo 'hwview-server: ACTIVE'
    else
        echo 'hwview-server: INACTIVE'
    fi
    if systemctl is-active --quiet hwview-collector; then
        echo 'hwview-collector: ACTIVE'
    else
        echo 'hwview-collector: INACTIVE'
    fi
"

echo "Checking API health..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "curl -s http://localhost:8080/api/v1/health || echo 'API not responding'"

echo ""
echo "=== Install Verification Complete ==="