# Commands & build flow

## TL;DR

- На сервере (2 ядра / 4 GB) **APK не собирается** — он строится в GitHub Actions и раздаётся через GitHub Releases.
- На сервере собирается только Flutter web (легковесный) + Django.
- Для production достаточно `docker compose -f docker-compose.production.yml up -d --build`.

## CI: GitHub Actions (`.github/workflows/build-flutter.yml`)

Workflow триггерится:

- автоматически при push в `main` и при PR;
- при пуше тега `v*` (создаёт Release с приложенным `moznods.apk` + `moznods-web.tar.gz`);
- вручную через UI GitHub → Actions → "Build Flutter (web + APK)" → Run workflow.

Что делает CI:

1. Поднимает Ubuntu runner (4 CPU / 16 GB / бесплатно).
2. `flutter pub get` + `dart run build_runner build` (с кэшем pub).
3. `flutter build web --release`.
4. `flutter build apk --release --target-platform android-arm64` (с кэшем Gradle).
5. Загружает в Action artifacts `moznods.apk` и `moznods-web.tar.gz` (хранятся 30 дней).
6. **Если запускался по тегу `v*`** — создаёт GitHub Release и прикладывает APK + web bundle.

### Релиз новой версии APK

```
git tag v1.0.0
git push origin v1.0.0
```

Через ~5–8 минут появится:
`https://github.com/MikhailOznobikhin/moznods/releases/download/v1.0.0/moznods.apk`

«Стабильная» ссылка на самый свежий релиз:
`https://github.com/MikhailOznobikhin/moznods/releases/latest/download/moznods.apk`

### Скачать APK без релиза (по конкретному запуску workflow)

GitHub → Actions → нужный run → секция Artifacts → `moznods-apk`.

## Подключение CI-артефакта к Django

Эндпоинт `/api/downloads/apk/` сначала ищет локальный файл, а если не находит — делает 302-редирект на URL из настройки `MOZNODS_APK_RELEASE_URL`. Достаточно добавить в `.env` на сервере:

```
MOZNODS_APK_RELEASE_URL=https://github.com/MikhailOznobikhin/moznods/releases/latest/download/moznods.apk
```

Перезапустить web-контейнер:

```
docker compose -f docker-compose.production.yml up -d
```

После этого `/download` в приложении и `/api/downloads/apk/info/` начнут отдавать «available: true», а сама кнопка «Скачать» перенаправит пользователя прямо на CDN GitHub.

## Production-сборка на сервере (только Django + web)

Образ собирает Flutter web внутри build-stage. Контейнер `web` при старте кладёт эту сборку в **общий volume** `flutter_web_build`, откуда её читает nginx (`/flutter/` и `flutter_bootstrap.js`). Раньше nginx монтировал `./moznods_flutter/build/web` с хоста — из-за этого после деплоя часто отдавалась **старая** веб-сборка с диска сервера, а не из образа.

```
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d
```

После обновления при необходимости сделайте в браузере жёсткое обновление (Ctrl+Shift+R) или очистите кэш для сайта — у Flutter web есть service worker.

Если хотите ещё уменьшить нагрузку на сервер — собирайте web в CI и подставляйте архив (опционально, отдельная доработка).

## Локальная разработка (на машине разработчика)

Когда нужно потрогать Flutter без коммита:

```
cd moznods_flutter
flutter pub get
flutter run -d chrome     # web
flutter run -d <device>   # android
```

Регенерация локализаций после правок ARB-файлов:

```
cd moznods_flutter && flutter gen-l10n
```

(обычно вызывается автоматически на `flutter pub get`).

## Полезные ручные команды (Docker, если очень нужно)

Persistent volumes для кэшей:

```
docker volume create moznods_pubcache
docker volume create moznods_gradle
```

Алиас:

```bash
alias mznflutter='docker run --rm \
  -v /home/mozno/moznods/moznods_flutter:/app \
  -v moznods_pubcache:/root/.pub-cache \
  -v moznods_gradle:/root/.gradle \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable bash -lc'
```
