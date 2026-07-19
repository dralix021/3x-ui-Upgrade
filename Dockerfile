FROM alpine:3.20

ENV TZ=Asia/Tehran \
    XUI_IN_DOCKER=true \
    XUI_MAIN_FOLDER=/app \
    XUI_ENABLE_FAIL2BAN=true \
    NGINX_PORT=${NGINX_PORT:-${PORT:-3000}} \
    WEB_BASE_PATH="/admin-panel-login"

# نصب تمام وابستگی‌ها
RUN apk add --no-cache --update \
    ca-certificates \
    tzdata \
    bash \
    curl \
    openssl \
    nginx \
    postgresql-client \
    fail2ban \
    gettext \          # ← مهم: برای envsubst
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && rm -rf /var/cache/apk/* /tmp/*

# نصب 3x-ui
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

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE ${NGINX_PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD curl -f http://127.0.0.1:${NGINX_PORT}${WEB_BASE_PATH}/ || exit 1

CMD ["/start.sh"]
