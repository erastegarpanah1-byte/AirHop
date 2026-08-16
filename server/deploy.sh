#!/usr/bin/env bash
#
# AirHop — اسکریپت نصب یکجا روی سرور ایران (Ubuntu/Debian)
#   bash deploy.sh
# متغیرها: SIGNAL_PORT (پیش‌فرض 8787)، TURN_USER (airhop)، TURN_PASS (تصادفی)

set -euo pipefail

SIGNAL_PORT="${SIGNAL_PORT:-8787}"
TURN_USER="${TURN_USER:-airhop}"
TURN_PASS="${TURN_PASS:-$(openssl rand -hex 16)}"
APP_DIR="/opt/airhop/server"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; exit 1; }

[[ $EUID -eq 0 ]] || err "باید با root اجرا شود (sudo bash deploy.sh)"

info "به‌روزرسانی بسته‌ها..."
apt-get update -y -qq

if ! command -v node >/dev/null 2>&1; then
  info "نصب Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
  apt-get install -y -qq nodejs npm || err "نصب Node.js شکست خورد"
fi
info "Node.js: $(node -v) / npm $(npm -v)"

info "ایجاد دایرکتوری $APP_DIR"
mkdir -p "$APP_DIR/src"

if [[ ! -f "$APP_DIR/package.json" ]]; then
  warn "package.json در $APP_DIR یافت نشد. فایل‌های server/ را اول کپی کن (rsync -av server/ $APP_DIR/)"
fi

if [[ -f "$APP_DIR/package.json" ]]; then
  info "نصب وابستگی‌های npm..."
  ( cd "$APP_DIR" && npm install --omit=dev --silent ) || err "npm install شکست خورد"
fi

cat > "$APP_DIR/.env" <<EOF
PORT=$SIGNAL_PORT
HOST=0.0.0.0
ROOM_TTL_MS=600000
EOF
info ".env ساخته شد (PORT=$SIGNAL_PORT)"

info "ثبت سرویس systemd..."
cat > /etc/systemd/system/airhop-signaling.service <<EOF
[Unit]
Description=AirHop Signaling Server (Node.js)
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node $APP_DIR/src/main.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production
EnvironmentFile=$APP_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable airhop-signaling
systemctl restart airhop-signaling
sleep 1
if systemctl is-active --quiet airhop-signaling; then info "سیگنالینگ فعال شد."; else warn "سیگنالینگ فعال نشد: journalctl -u airhop-signaling -n 50"; fi

if ! command -v turnserver >/dev/null 2>&1; then
  info "نصب coturn..."
  apt-get install -y -qq coturn || err "نصب coturn شکست خورد"
fi

PUBLIC_IP="${PUBLIC_IP:-$(curl -s -4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')}"
info "آدرس عمومی: $PUBLIC_IP"

cat > /etc/turnserver.conf <<EOF
listening-port=3478
listening-ip=0.0.0.0
external-ip=$PUBLIC_IP
min-port=49152
max-port=65535
user=$TURN_USER:$TURN_PASS
no-cli
deny-loopback-ip
no-multicast-peers
syslog
EOF

sed -i 's/^#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn
systemctl restart coturn
systemctl enable coturn

if command -v ufw >/dev/null 2>&1; then
  info "باز کردن پورت‌ها (ufw)..."
  ufw allow "$SIGNAL_PORT/tcp" >/dev/null 2>&1 || true
  ufw allow 3478/tcp >/dev/null 2>&1 || true
  ufw allow 3478/udp >/dev/null 2>&1 || true
  ufw allow 49152:65535/udp >/dev/null 2>&1 || true
  ufw reload >/dev/null 2>&1 || true
  info "فایروال پیکربندی شد."
else
  warn "ufw نیست؛ پورت‌ها دستی باز کن."
fi

echo ""
echo "======================================================"
echo "  نصب AirHop کامل شد!"
echo "======================================================"
echo "  سیگنالینگ: http://$PUBLIC_IP:$SIGNAL_PORT"
echo "  TURN:       turn:$PUBLIC_IP:3478"
echo "  TURN کاربر: $TURN_USER"
echo "  TURN رمز:   $TURN_PASS"
echo ""
echo "  این مقادیر را در app_config.dart کلاینت بگذار."
echo "======================================================"
