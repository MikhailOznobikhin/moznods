#!/bin/bash
# Загружаем переменные из корневого .env
# Ожидается наличие DOMAIN и TURN_SECRET
ROOT_ENV="/root/moznods/.env"

if [ -f "$ROOT_ENV" ]; then
    set -a
    source "$ROOT_ENV"
    set +a
else
    echo "Error: $ROOT_ENV not found"
    exit 1
fi

# Если DOMAIN задан, используем его для формирования URL, если они не заданы явно
if [ ! -z "$DOMAIN" ]; then
    VITE_API_URL=${VITE_API_URL:-https://${DOMAIN}}
    VITE_WS_URL=${VITE_WS_URL:-wss://${DOMAIN}}
    VITE_TURN_URL=${VITE_TURN_URL:-turn:${DOMAIN}:3478}
    
    # Используем TURN_SECRET если он задан
    if [ ! -z "$TURN_SECRET" ]; then
        VITE_TURN_USERNAME=${VITE_TURN_USERNAME:-${TURN_SECRET}}
        VITE_TURN_PASSWORD=${VITE_TURN_PASSWORD:-${TURN_SECRET}}
    fi
fi

# Создаём .env.production для Vite динамически
cat > /root/moznods/frontend/.env.production << EOF
VITE_API_URL=${VITE_API_URL}
VITE_WS_URL=${VITE_WS_URL}
VITE_TURN_URL=${VITE_TURN_URL}
VITE_TURN_USERNAME=${VITE_TURN_USERNAME}
VITE_TURN_PASSWORD=${VITE_TURN_PASSWORD}
EOF

echo "Generated .env.production with DOMAIN: ${DOMAIN:-custom}"

# Собираем проект
cd /root/moznods/frontend
npm run build