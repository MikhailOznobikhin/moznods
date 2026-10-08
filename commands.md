# Commands & build flow

## TL;DR

- На сервере (2 ядра / 4 GB) **APK не собирается** — он строится в GitHub Actions и раздаётся через GitHub Releases.
- На сервере ничего не собирается: образ `web` (Django + Flutter web) строится в GitHub Actions и лежит в GHCR.
- Для production: `make deploy` — сервер скачивает готовый образ из GHCR (собирается в GitHub Actions).

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

## Production: образ собирается в GitHub Actions

Образ `web` (Django + Flutter web) собирает `.github/workflows/docker-image.yml` и публикует в GHCR:

- `ghcr.io/mikhailoznobikhin/moznods-web:latest` — каждый push в `main`;
- `...:sha-<коммит>` — каждый коммит (для отката);
- `...:vX.Y.Z` — теги релизов.

На PR образ только собирается (проверка), без публикации.

Сервер ничего не собирает, только скачивает готовый образ:

```
make deploy        # git pull + docker compose pull web + up -d + migrate
```

### Первый раз на сервере

Пакет в GHCR по умолчанию приватный. Два варианта:

1. Сделать его публичным: GitHub → профиль → Packages → `moznods-web` → Package settings → Change visibility → Public.
2. Или залогиниться на сервере токеном с правом `read:packages`
   (GitHub → Settings → Developer settings → Personal access tokens):

```
echo <TOKEN> | docker login ghcr.io -u MikhailOznobikhin --password-stdin
```

### Откат на предыдущую версию

```
MOZNODS_IMAGE=ghcr.io/mikhailoznobikhin/moznods-web:sha-1a2b3c4 make deploy
```

(короткий sha — во вкладке Actions или `git log --oneline`).

### Сборка на самом сервере (запасной вариант)

`make deploy-local-build` — как раньше, собирает образ на сервере (нужно ~3 ГБ RAM).

Контейнер `web` при старте копирует Flutter-сборку из образа в общий volume `flutter_web_build` и выполняет
`collectstatic`; nginx отдаёт `/static/` с `Cache-Control: no-cache`, так что браузеры сразу получают новую версию.
