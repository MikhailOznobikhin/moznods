# 003 — Стабильность звонков

Звонки то соединяются, то нет. Причины и исправления по порядку.

## 1. Сигналинг во Flutter (`moznods_flutter/lib/store/call_provider.dart`)
- [x] Новичок не создавал peer connection и выбрасывал входящий offer. Теперь PC создаётся по входящему offer.
- [x] ICE-кандидаты до `setRemoteDescription` терялись. Теперь они копятся в очереди и применяются после SDP.
- [x] Сообщения сигналинга обрабатывались параллельно (`listen(async ...)`). Теперь строго по одному.
- [x] При `failed` / долгом `disconnected` инициатор делает ICE restart.
- [x] Входящий offer для мёртвого PC пересоздаёт PC (собеседник переподключился).
- [x] Принимаются оба формата SDP/ICE (Flutter: строки, веб: объекты).

## 2. TURN с временными учётными данными
- [x] `GET /api/calls/ice-servers/` → STUN + TURN (coturn `use-auth-secret`, HMAC-SHA1, TTL).
- [x] Flutter и веб-клиент берут ICE-серверы с этого эндпоинта (с запасным STUN).
- Env: `TURN_SECRET`, `TURN_URLS`, `STUN_URLS`, `TURN_CREDENTIAL_TTL`. Если `TURN_SECRET` нет, но заданы `TURN_USERNAME`/`TURN_PASSWORD`, отдаются статичные учётные данные.

## 3. Живучесть сокетов
- [x] Flutter `WebSocketService`: `onConnected` после рукопожатия, heartbeat (ping/pong), переподключение с экспоненциальной паузой, без переподключения при коде 4403.
- [x] Сервер: при обрыве сокета `user_left` рассылается только через `CALL_RECONNECT_GRACE_SECONDS` (по умолчанию 15с), если пользователь не вернулся. Явный `leave_call` и кик — сразу.

## 4. coturn
- [x] `network_mode: host`, `use-auth-secret` + `static-auth-secret=${TURN_SECRET}`, диапазон портов 49152–49999.

AICODE-NOTE: Инициатор соединения — всегда тот, кто уже был в звонке (получил `user_joined`). Новичок только отвечает. Это убирает glare при входе.
