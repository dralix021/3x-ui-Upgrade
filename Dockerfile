FROM alpine:3.20 AS base

# ========================================================
# مرحله نهایی
# ========================================================
FROM alpine:3.20

# تنظیمات پایه و امنیتی
ENV TZ=Asia/Tehran \
    XUI_IN_DOCKER=true \
    XUI_MAIN_FOLDER=/app \
    XUI_ENABLE_FAIL2BAN=true \
    XUI_DB_TYPE=postgres \
    # متغیرهای مهم Railway / Railway-like platforms
    PORT=${PORT:-2053} \
    XUI_PORT=${XUI_PORT:-2053}

# نصب پکیج‌های ضروری + PostgreSQL client + Nginx
RUN apk add --no-cache --update \
    ca-certificates \
    tzdata \
    bash \
    curl \
    openssl \
    nginx \
    supervisor \
    postgresql-client \
    fail2ban \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    # پاک‌سازی
    && rm -rf /var/cache/apk/* /tmp/*

# دانلود و نصب آخرین نسخه 3x-ui (به جای نسخه قدیمی v3.5.0)
RUN mkdir -p /app /etc/x-ui /var/log/x-ui /run/nginx \
    && ARCH=$(uname -m) && case ${ARCH} in \
         x86_64|amd64) XUI_ARCH="amd64";; \
         aarch64|arm64) XUI_ARCH="arm64";; \
         *) XUI_ARCH="amd64";; esac \
    && curl -L "https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-${XUI_ARCH}.tar.gz" -o /tmp/x-ui.tar.gz \
    && tar -xzf /tmp/x-ui.tar.gz -C /usr/local/ \
    && rm /tmp/x-ui.tar.gz \
    && mv /usr/local/x-ui/* /app/ \
    && chmod +x /app/x-ui /app/x-ui.sh

# کپی فایل‌های کانفیگ
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY supervisord.conf /etc/supervisord.conf
COPY start.sh /start.sh

RUN chmod +x /start.sh /app/x-ui

# Nginx + Supervisor + 3x-ui volumes
VOLUME ["/etc/x-ui", "/var/log/x-ui", "/root/.acme.sh"]

EXPOSE ${PORT}

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD curl -f http://127.0.0.1:${PORT}/ || exit 1

CMD ["/start.sh"]
