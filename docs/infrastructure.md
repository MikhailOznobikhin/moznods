# Рекомендуемая инфраструктура для MOznoDS

Этот документ описывает минимальные и рекомендуемые системные требования для развертывания платформы MOznoDS, включая основное приложение (Django + Channels) и вспомогательный сервер WebRTC (Coturn).

---

## 1. Основное приложение (Django, Channels, SQLite)

MOznoDS спроектирован как легковесное решение, использующее SQLite и Django Channels (в режиме `InMemoryChannelLayer` для экономии ресурсов).

### Минимальные требования (до 10-20 онлайн-пользователей):
- **CPU**: 1 ядро (Shared vCPU).
- **RAM**: 1 ГБ (минимум 512 МБ, но 1 ГБ обеспечит стабильность при сборке фронтенда и работе нескольких процессов Daphne).
- **Диск**: 10 ГБ HDD/SSD (SQLite база данных и медиа-файлы занимают мало места в начале).
- **ОС**: Ubuntu 22.04 LTS или аналогичный Linux.

### Рекомендуемые требования (50+ пользователей):
- **CPU**: 2 ядра (Dedicated).
- **RAM**: 2-4 ГБ.
- **Диск**: 20 ГБ NVMe.
- **Рекомендация**: При росте нагрузки стоит перейти с `InMemoryChannelLayer` на **Redis** и использовать **PostgreSQL** вместо SQLite.

---

## 2. Звонки (LiveKit)

Звонки идут через собственный LiveKit (SFU) из `docker-compose.production.yml`: он же сигналинг,
TURN (UDP 3478 и TLS 5349 с сертификатом Let's Encrypt домена) и ICE по TCP. Подробности — [webrtc.md](webrtc.md).

### Минимальные требования
- **RAM**: ~150–300 МБ для LiveKit при небольших звонках.
- **Канал**: каждый участник отдаёт поток один раз; входящий трафик сервера растёт с числом участников.
- **Порты (фаервол)**: 7881/tcp, 7882-7883/udp, 3478/udp, 5349/tcp, плюс 80/443.

## 3. Советы по развертыванию (Self-hosted)

1. **Docker**: Рекомендуется использовать Docker Compose для изоляции компонентов.
2. **Reverse Proxy (Nginx/Caddy)**: 
   - Настройте HTTPS (через Let's Encrypt).
   - Убедитесь, что заголовки `X-Forwarded-Proto` и `X-Forwarded-For` передаются в Django.
3. **Безопасность Django**:
   - При использовании HTTPS установите `CSRF_COOKIE_SECURE=True` и `SESSION_COOKIE_SECURE=True` в `.env`.
   - Не забудьте добавить все используемые домены в `ALLOWED_HOSTS` и `CSRF_TRUSTED_ORIGINS`.
4. **Статика**: 
   - Запустите `python manage.py collectstatic` перед запуском.
   - Nginx должен сам отдавать файлы из папки `STATIC_ROOT`.

---

## 4. Docker Production Deployment

### Services
| Service | Image | Purpose |
|---------|-------|---------|
| web | Django + Flutter | Main application |
| postgres | postgres:16-alpine | Database |
| redis | redis:7-alpine | Channels layer, cache, call presence |
| livekit | livekit/livekit-server | Calls: SFU, signaling, TURN |
| nginx | nginx:alpine | Reverse proxy, SSL |

### Quick Start

```bash
# 1. Copy and edit environment
cp .env.production.example .env
nano .env  # Fill in your SECRET_KEY, domain, passwords

# 2. Generate SSL certificates (or use Let's Encrypt)
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/privkey.pem -out nginx/ssl/fullchain.pem

# 3. Build and start
docker compose -f docker-compose.production.yml up -d

# 4. Run migrations
docker compose -f docker-compose.production.yml exec web python manage.py migrate

# 5. Create superuser
docker compose -f docker-compose.production.yml exec web python manage.py createsuperuser

# collectstatic runs automatically when the web container starts.
```

### Media Files
Media files are stored locally in `/app/media/` (Docker volume: `media_volume`).

### Calls (LiveKit)
- Set `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (≥ 32 chars) and `DOMAIN` in `.env`.
- Logs: `make logs-livekit`.
