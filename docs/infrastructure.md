# Рекомендуемая инфраструктура для MOznoDS

Этот документ описывает системные требования и подготовку сервера для MOznoDS (Django + Channels, PostgreSQL, Redis, LiveKit).

---

## 1. Сервер под production-стек

Стек из `docker-compose.production.yml`: web (Daphne, один процесс), PostgreSQL, Redis, LiveKit, nginx.
Образ собирается в GitHub Actions, сервер только скачивает его, поэтому память на сборку Flutter не нужна.

### Сколько памяти занимает стек (оценка, не замер)
| Что | В простое | Лимит в compose |
|-----|-----------|-----------------|
| ОС + Docker | ~300–400 МБ | — |
| web (Daphne) | ~150–250 МБ | 512 МБ |
| PostgreSQL | ~100–300 МБ (`shared_buffers=256MB`) | 512 МБ |
| Redis | ~10–50 МБ (`maxmemory 128mb`) | 192 МБ |
| LiveKit | ~50–150 МБ, растёт со звонками | 512 МБ |
| nginx | ~10–20 МБ | 128 МБ |

Итого ~0,7–1,2 ГБ, поэтому:
- **Минимум (до ~20–30 человек онлайн, звонки на несколько человек)**: 1 vCPU, 2 ГБ RAM + 2 ГБ swap, 20–40 ГБ SSD.
- **Комфортно (видеозвонки на 5+ человек, запас)**: 2 vCPU, 4 ГБ RAM, SSD.
- Узкое место при звонках сначала канал (каждый видеопоток ~0,5–2 Мбит/с, сервер раздаёт его каждому участнику), потом CPU у LiveKit и TLS.
- Диск лучше SSD/NVMe: PostgreSQL на HDD заметно медленнее. Место уходит на ОС (~3–4 ГБ), swap, образы (~1,5–2 ГБ, старые удаляет `make deploy`), БД и `media_volume`. На 10 ГБ стек помещается со swap 1 ГБ (`SWAP_SIZE=1G`), но вложения быстро съедят остаток; 20 ГБ спокойнее.
- ОС: Ubuntu LTS (24.04).

### Подготовка сервера
1. `sh docker/server-setup.sh` от root: swap, sysctl, Docker, ufw с портами LiveKit, fail2ban, автообновления безопасности.
2. SSH: вход по ключу, в `/etc/ssh/sshd_config` поставить `PasswordAuthentication no` и `PermitRootLogin prohibit-password`, затем `systemctl restart ssh`. Сначала проверить вход по ключу в отдельной сессии.
3. Сертификат: `certbot certonly --standalone -d <домен> -d www.<домен>` (до запуска nginx, пока порт 80 свободен).
4. `.env` и `make deploy` (см. раздел 4).

Docker пишет свои правила iptables в обход ufw, поэтому порт web открыт только на `127.0.0.1`.

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

# 2. Let's Encrypt certificate (nginx and LiveKit read /etc/letsencrypt)
certbot certonly --standalone -d <domain> -d www.<domain>

# 3. Pull the image built in GitHub Actions and start
docker compose -f docker-compose.production.yml pull
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
