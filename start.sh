#!/bin/bash
set -euo pipefail

echo "🚀 Starting 3X-UI Professional Container with Nginx Reverse Proxy..."

# ====================== تنظیمات محیط ======================
export NGINX_PORT=${NGINX_PORT:-${PORT:-3000}}
export XUI_INTERNAL_PORT=2053
export SUB_PORT=2096
export XRAY_PORT=8080

# مسیر مخفی پنل (مهم)
export WEB_BASE_PATH="/admin-panel-login"

# ====================== آماده‌سازی ======================
mkdir -p /var/log/nginx /var/log/x-ui /run/nginx /etc/x-ui

cd /app || cd /usr/local/x-ui || cd /usr/local/x-ui/x-ui

echo "🔧 اعمال تنظیمات پنل (پورت + Base Path مخفی)..."
# تنظیم Base Path به مسیر دلخواه مخفی
./x-ui setting -port ${XUI_INTERNAL_PORT} -webBasePath ${WEB_BASE_PATH} || true

echo "🔧 ساخت کانفیگ Nginx..."
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# تست کانفیگ
if ! nginx -t; then
    echo "❌ Nginx configuration test failed!"
    exit 1
fi

# ====================== شروع سرویس‌ها ======================
echo "▶️ Starting Fail2Ban (if enabled)..."
if [ "${XUI_ENABLE_FAIL2BAN}" = "true" ]; then
    fail2ban-client -x start || true
fi

# چک دیتابیس PostgreSQL
if [ "${XUI_DB_TYPE}" = "postgres" ] && [ -n "${XUI_DB_DSN}" ]; then
    echo "Waiting for PostgreSQL..."
    until pg_isready -d "${XUI_DB_DSN#*://*/}" >/dev/null 2>&1; do
        sleep 2
    done
    echo "✅ PostgreSQL ready."
fi

echo "▶️ Starting 3X-UI Panel (Base Path: ${WEB_BASE_PATH})..."
./x-ui > /var/log/x-ui/panel.log 2>&1 &
XUI_PID=$!
echo "3X-UI PID: ${XUI_PID}"

sleep 4   # زمان کافی برای آماده شدن کامل پنل

echo "▶️ Starting Nginx on port ${NGINX_PORT}..."
exec nginx -g "daemon off;"
