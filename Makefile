SHELL := /bin/bash

# Доп. аргументы: make migrate a="--plan"
a ?=

# По умолчанию production-стек (см. commands.md). Локально: make start COMPOSE=docker-compose.yml
COMPOSE ?= docker-compose.production.yml
DC := docker compose -f $(COMPOSE)

WEB_SERVICE := web
POSTGRES_SERVICE := postgres

PGDATABASE := $(shell grep -E '^PGDATABASE=' .env 2>/dev/null | cut -d= -f2- | tr -d '\r' || true)
PGUSER := $(shell grep -E '^PGUSER=' .env 2>/dev/null | cut -d= -f2- | tr -d '\r' || true)

EXEC_WEB_IT := $(DC) exec -it $(WEB_SERVICE)
EXEC_WEB_T := $(DC) exec -T $(WEB_SERVICE)
MANAGE := python manage.py

define confirm
	@echo -e "\033[31mВНИМАНИЕ: $(@)\033[0m"
	@read -r -p "Продолжить? [y/N] " response; \
	if [[ "$$response" != "y" ]]; then echo "Отменено."; exit 1; fi
endef

.PHONY: help manage makemigrations migrate createsuperuser collectstatic test cleancache \
	check check-deploy start stop down restart build build-web build-all pull up \
	deploy list logs logs-web logs-nginx logs-postgres logs-redis logs-coturn \
	bash shell dbshell psql redis-cli dump-db restore-dump reload-nginx \
	flutter-volumes flutter-shell sync-main lint ruff-format pytest

help: ## Список целей (COMPOSE=docker-compose.yml для dev без Postgres)
	@echo ""
	@echo "Аргументы: make <цель> a=\"...\"   (пример: make migrate a=\"--plan\")"
	@echo "Compose:    COMPOSE=$(COMPOSE)"
	@echo ""
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }'
	@echo ""

## Django (в контейнере web)

manage: ## Любая команда manage.py (a="check --deploy")
	$(EXEC_WEB_IT) $(MANAGE) $(a)

makemigrations: ## makemigrations (a=...)
	$(EXEC_WEB_IT) $(MANAGE) makemigrations $(a)

migrate: ## migrate (a=...)
	$(EXEC_WEB_IT) $(MANAGE) migrate $(a)

createsuperuser: ## createsuperuser (a=...)
	$(EXEC_WEB_IT) $(MANAGE) createsuperuser $(a)

collectstatic: ## collectstatic (a=...)
	$(EXEC_WEB_IT) $(MANAGE) collectstatic $(a)

test: ## manage.py test (a=путь или приложение)
	$(EXEC_WEB_IT) $(MANAGE) test $(a)

dbshell: ## manage.py dbshell
	$(EXEC_WEB_IT) $(MANAGE) dbshell

check: ## manage.py check
	$(EXEC_WEB_IT) $(MANAGE) check $(a)

check-deploy: ## manage.py check --deploy
	$(EXEC_WEB_IT) $(MANAGE) check --deploy

cleancache: ## Удалить __pycache__
	@find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

## Docker Compose

pull: ## docker compose pull
	$(DC) pull

up: ## up -d (a=доп. флаги compose)
	$(DC) up -d --remove-orphans $(a)

start: up ## Алиас для up

stop: ## Остановить контейнеры
	$(DC) stop

down: ## down (a=--volumes при необходимости)
	$(DC) down $(a)

restart: stop up ## stop + up

build: ## Собрать все сервисы (--no-cache)
	$(DC) build --no-cache $(a)

build-web: ## Пересобрать только образ web (как в commands.md)
	$(DC) build $(a) web

build-all: ## build --no-cache --pull для всего стека
	$(DC) build --no-cache --pull

deploy: ## git pull + build web + up + migrate
	git pull
	$(DC) build web
	$(DC) up -d --remove-orphans
	$(EXEC_WEB_T) $(MANAGE) migrate --noinput

list: ## compose ps (a=...)
	$(DC) ps $(a)

logs: ## Логи всех сервисов (a="-f" или a="web")
	$(DC) logs $(a)

logs-web: ## Логи web
	$(DC) logs -f web

logs-nginx: ## Логи nginx
	$(DC) logs -f nginx

logs-postgres: ## Логи postgres
	$(DC) logs -f postgres

logs-redis: ## Логи redis
	$(DC) logs -f redis

logs-coturn: ## Логи coturn
	$(DC) logs -f coturn

## Shell

bash: ## bash в контейнере web
	$(EXEC_WEB_IT) /bin/bash

shell: ## manage.py shell (a=...)
	$(EXEC_WEB_IT) $(MANAGE) shell $(a)

psql: ## psql в postgres (только если в COMPOSE есть postgres; a="-c '...'")
	@test -n "$(PGDATABASE)" && test -n "$(PGUSER)" || (echo "Задайте PGDATABASE и PGUSER в .env"; exit 1)
	$(DC) exec -it $(POSTGRES_SERVICE) psql -U "$(PGUSER)" -d "$(PGDATABASE)" $(a)

redis-cli: ## redis-cli (a=...)
	$(DC) exec -it redis redis-cli $(a)

## БД (PostgreSQL в production compose)

dump-db: ## pg_dump в dump_YYYYMMDD_HHMMSS.sql
	@test -n "$(PGDATABASE)" && test -n "$(PGUSER)" || (echo "Задайте PGDATABASE и PGUSER в .env"; exit 1)
	@stamp=$$(date +%Y%m%d_%H%M%S); \
	out="dump_$${stamp}.sql"; \
	echo "Writing $$out ..."; \
	$(DC) exec -T $(POSTGRES_SERVICE) pg_dump -U "$(PGUSER)" -d "$(PGDATABASE)" --clean --if-exists > "$$out"; \
	echo "OK: $$out"

restore-dump: ## Восстановить SQL: make restore-dump a=dump_xxx.sql (перезапись данных)
	$(call confirm)
	@test -n "$(a)" || (echo "Укажите a=файл.sql"; exit 1)
	@test -f "$(a)" || (echo "Файл не найден: $(a)"; exit 1)
	@test -n "$(PGUSER)" || (echo "Задайте PGUSER в .env"; exit 1)
	cat "$(a)" | $(DC) exec -T $(POSTGRES_SERVICE) psql -U "$(PGUSER)" -d postgres

reload-nginx: ## nginx -s reload в контейнере nginx
	$(DC) exec nginx nginx -s reload

## Flutter в Docker (из commands.md)

flutter-volumes: ## Создать тома для pub-cache и Gradle
	docker volume create moznods_pubcache 2>/dev/null || true
	docker volume create moznods_gradle 2>/dev/null || true

flutter-shell: ## Интерактивная оболочка Flutter в контейнере (каталог moznods_flutter)
	docker run --rm -it \
		-v "$$(pwd)/moznods_flutter:/app" \
		-v moznods_pubcache:/root/.pub-cache \
		-v moznods_gradle:/root/.gradle \
		-w /app \
		ghcr.io/cirruslabs/flutter:stable bash

## Git

sync-main: ## Сбросить ветку main на origin/main
	git checkout main
	git fetch origin main
	git reset --hard origin/main

## Локально на хосте (venv + requirements_dev)

lint: ## ruff check
	ruff check .

ruff-format: ## ruff format
	ruff format .

pytest: ## pytest на хосте (a=...)
	pytest $(a)
