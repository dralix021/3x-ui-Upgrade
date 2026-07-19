#!/bin/bash
set -euo pipefail

echo "🚀 Starting 3X-UI Professional Container..."

# ====================== تنظیمات ======================
export NGINX_PORT=${NGINX_PORT:-${PORT:-3000}}
export WEB_BASE_PATH=${WEB_BASE_PATH:-"/admin-panel-login"}
export XUI_INTERNAL_PORT=2053

# ====================== آماده‌سازی ======================
mkdir -p /var/log/nginx /var/log/x-ui /run/nginx /etc/x-ui

cd /app || cd /usr/local/x-ui

echo "🔧 اعمال تنظیمات پنل (Base Path: ${WEB_BASE_PATH})..."
./x-ui setting -port ${XUI_INTERNAL_PORT} -webBasePath ${WEB_BASE_PATH} || true

# ====================== Nginx Config ======================
echo "🔧 ساخت کانفیگ Nginx..."
envsubst '${NGINX_PORT},${WEB_BASE_PATH}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

if ! nginx -t; then
    echo "❌ Nginx config failed!"
    exit 1
fi

# ====================== دیتابیس ======================
if [ "${XUI_DB_TYPE}" = "postgres" ]; then
    if [ -z "${XUI_DB_DSN}" ]; then
        echo "⚠️  WARNING: XUI_DB_TYPE=postgres but XUI_DB_DSN is empty. Falling back to SQLite."
        export XUI_DB_TYPE=""
        export XUI_DB_DSN=""
    else
        echo "⏳ Waiting for PostgreSQL..."
        for i in {1..30}; do
            if pg_isready -d "${XUI_DB_DSN#*://*/}" >/dev/null 2>&1; then
                echo "✅ PostgreSQL is ready."
                break
            fi
            sleep 2
        done
    fi
fi

# ====================== شروع سرویس‌ها ======================
echo "▶️ Starting Fail2Ban (if enabled)..."
if [ "${XUI_ENABLE_FAIL2BAN}" = "true" ]; then
    fail2ban-client -x start || true
fi

echo "▶️ Starting 3X-UI Panel..."
./x-ui > /var/log/x-ui/panel.log 2>&1 &
echo "3X-UI started (PID: $!)"

sleep 4

echo "▶️ Starting Nginx on port ${NGINX_PORT}..."
exec nginx -g "daemon off;"
