#!/bin/bash
set -e
NGINX=/usr/sbin/nginx
echo "=== 3b. Deploy web dist ==="
echo "9090" | sudo -S rm -rf /var/www/hwview
echo "9090" | sudo -S mkdir -p /var/www/hwview
echo "9090" | sudo -S cp -r /tmp/hwview-web/dist/* /var/www/hwview/
echo "9090" | sudo -S chown -R www-data:www-data /var/www/hwview
ls -la /var/www/hwview/

echo "=== 4b. Configure nginx site ==="
echo "9090" | sudo -S tee /etc/nginx/sites-available/hwview > /dev/null << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    root /var/www/hwview;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXEOF
echo "9090" | sudo -S ln -sf /etc/nginx/sites-available/hwview /etc/nginx/sites-enabled/hwview
echo "9090" | sudo -S rm -f /etc/nginx/sites-enabled/default
echo "9090" | sudo -S $NGINX -t
echo "9090" | sudo -S systemctl enable nginx
echo "9090" | sudo -S systemctl restart nginx
echo "9090" | sudo -S systemctl is-active nginx

echo "=== 5b. Verify full chain ==="
echo "--- health via nginx ---"
curl -s http://localhost/api/v1/health
echo
echo "--- report WITHOUT key (expect 401) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "http://localhost/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-08"
echo "--- report WITH key (expect 200) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "X-Admin-Key: hwview-shadow-deploy" "http://localhost/api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-08"
echo "--- login wrong key (expect 401) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{"key":"wrong"}'
echo "--- login correct key ---"
curl -s -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{"key":"hwview-shadow-deploy"}'
echo
echo "--- frontend index via nginx ---"
curl -s http://localhost/ | head -3
echo "ALL DONE"