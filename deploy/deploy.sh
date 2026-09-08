#!/bin/bash
set -euo pipefail

DEPLOY_SERVER="${DEPLOY_SERVER:-192.168.2.110}"
DEPLOY_USER="${DEPLOY_USER:-debian}"
DEPLOY_PATH="/opt/hwview"
BINARY_SERVER="./bin/hwview-server"
BINARY_COLLECTOR="./bin/hwview-collector"
SCHEMA_SQL="./deploy/init_schema.sql"
SERVICE_SERVER="./deploy/hwview-server.service"
SERVICE_COLLECTOR="./deploy/hwview-collector.service"

echo "=== HWView Deployment Script ==="
echo "Target: ${DEPLOY_USER}@${DEPLOY_SERVER}:${DEPLOY_PATH}"
echo ""

if [ ! -f "${BINARY_SERVER}" ]; then
    echo "Building binaries..."
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "${BINARY_SERVER}" ./cmd/hwview-server
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "${BINARY_COLLECTOR}" ./cmd/hwview-collector
fi

echo "Creating remote directories..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "sudo mkdir -p ${DEPLOY_PATH}/bin ${DEPLOY_PATH}/data ${DEPLOY_PATH}/config && sudo chown -R ${DEPLOY_USER}:${DEPLOY_USER} ${DEPLOY_PATH}"

echo "Copying binaries..."
scp "${BINARY_SERVER}" "${DEPLOY_USER}@${DEPLOY_SERVER}:${DEPLOY_PATH}/bin/"
scp "${BINARY_COLLECTOR}" "${DEPLOY_USER}@${DEPLOY_SERVER}:${DEPLOY_PATH}/bin/"

echo "Copying config..."
scp config/config.yaml "${DEPLOY_USER}@${DEPLOY_SERVER}:${DEPLOY_PATH}/config/"

echo "Copying schema..."
scp "${SCHEMA_SQL}" "${DEPLOY_USER}@${DEPLOY_SERVER}:${DEPLOY_PATH}/deploy/"

echo "Initializing database..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "sqlite3 ${DEPLOY_PATH}/data/hwview.db < ${DEPLOY_PATH}/deploy/init_schema.sql 2>/dev/null || echo 'Schema already initialized'"

echo "Installing systemd services..."
scp "${SERVICE_SERVER}" "${DEPLOY_USER}@${DEPLOY_SERVER}:/tmp/hwview-server.service"
scp "${SERVICE_COLLECTOR}" "${DEPLOY_USER}@${DEPLOY_SERVER}:/tmp/hwview-collector.service"
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "sudo mv /tmp/hwview-server.service /etc/systemd/system/ && sudo mv /tmp/hwview-collector.service /etc/systemd/system/ && sudo systemctl daemon-reload"

echo "Enabling and starting services..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "sudo systemctl enable hwview-server hwview-collector && sudo systemctl restart hwview-server && sleep 2 && sudo systemctl restart hwview-collector"

echo "Checking service status..."
ssh "${DEPLOY_USER}@${DEPLOY_SERVER}" "sudo systemctl is-active hwview-server && sudo systemctl is-active hwview-collector"

echo ""
echo "=== Deployment Complete ==="
echo "HWView Server:  http://${DEPLOY_SERVER}:8080"
echo "API Health:     http://${DEPLOY_SERVER}:8080/api/v1/health"
echo ""
echo "Service logs:   ssh ${DEPLOY_USER}@${DEPLOY_SERVER} 'sudo journalctl -u hwview-server -f'"