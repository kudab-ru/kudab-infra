# Makefile для kudasobrat.ru (v1.0.2)

COMPOSE = docker compose -f docker-compose.yml
DEV = $(COMPOSE) -f docker-compose.dev.yml
PROD = $(COMPOSE) -f docker-compose.prod.yml

.PHONY: help init dev prod down rebuild logs ps migrate rollback backup fix-port-conflict
.PHONY: bot-health bot-diag bot-send
.PHONY: bot-build bot-rebuild bot-build-prod bot-restart bot-logs
.PHONY: webhook-info webhook-set webhook-del webhook-refresh
.PHONY: snapshot-api snapshot-parser
.PHONY: bot-apply-prod bot-health-prod bot-diag-prod bot-release nginx-reload

help:
	@printf "\n\033[1;34m╭─────────────────────[ 📦 KUDASOBRAT CLI ]─────────────────────╮\033[0m\n"
	@printf " \033[1;32m  Доступные команды для управления инфраструктурой проекта\033[0m\n"
	@printf " \033[90m  Используйте \033[1;37mmake <команда>\033[0m\033[90m для быстрого запуска задач\033[0m\n"
	@printf "\033[1;34m╰──────────────────────────────────────────────────────────────╯\033[0m\n\n"
	@printf " \033[1;36m%-18s\033[0m %s\n" "init"        "🔧  Клонирование подмодулей и первичная инициализация"
	@printf " \033[1;36m%-18s\033[0m %s\n" "dev"         "🧪  Запуск DEV окружения (hot-reload, маунты)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod"        "🚀  Продакшен-режим с SSL и CI/CD"
	@printf " \033[1;36m%-18s\033[0m %s\n" "rebuild"     "🔁  Пересборка всех сервисов (build --no-cache)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "down"        "🛑  Остановить и удалить все контейнеры"
	@printf " \033[1;36m%-18s\033[0m %s\n" "logs"        "📜  Просмотр логов всех сервисов (tail -f)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "ps"          "🔍  Текущий статус всех контейнеров"
	@printf " \033[1;36m%-18s\033[0m %s\n" "migrate"     "📂  Artisan migrate в контейнере API"
	@printf " \033[1;36m%-18s\033[0m %s\n" "rollback"    "⏪  Откат версии через scripts/rollback.sh"
	@printf " \033[1;36m%-18s\033[0m %s\n" "backup"      "💾  Ручной backup БД через scripts/backup_db.sh"
	@printf "\n"

init:
	git submodule update --init --recursive

dev:
	$(DEV) up -d --build

prod:
	$(PROD) up -d --build

rebuild:
	$(COMPOSE) down
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f --tail=50

ps:
	$(COMPOSE) ps

migrate:
	docker exec -it kudab-api php artisan migrate

rollback:
	bash scripts/rollback.sh

backup:
	bash scripts/backup_db.sh

fix-port-conflict:
	@printf "\n\033[1;34m╭─────────────────────[ 🔧 FIX PORT CONFLICT ]──────────────────────╮\033[0m\n\n"
	@printf " \033[1;36mПроверка, не занят ли порт 5432 локальным PostgreSQL на хосте...\033[0m\n"
	@if lsof -i :5432 | grep -q LISTEN; then \
		printf " \033[1;33m⚠️  Порт 5432 занят! Пытаемся остановить локальный PostgreSQL...\033[0m\n"; \
		if command -v systemctl >/dev/null 2>&1; then \
			sudo systemctl stop postgresql && printf " \033[1;32m✅ PostgreSQL остановлен через systemctl\033[0m\n"; \
		elif command -v pg_ctl >/dev/null 2>&1; then \
			pg_ctl stop -D /usr/local/var/postgres && printf " \033[1;32m✅ PostgreSQL остановлен через pg_ctl\033[0m\n"; \
		else \
			printf " \033[1;31m❌ Не удалось определить способ остановки PostgreSQL. Заверши вручную.\033[0m\n"; \
			exit 1; \
		fi \
	else \
		printf " \033[1;32m✅ Порт 5432 свободен — конфликта нет.\033[0m\n"; \
	fi
	@printf "\033[1;36m♻️  Перезапуск контейнера PostgreSQL...\033[0m\n"
	@docker restart kudab-db >/dev/null && printf " \033[1;32m✅ Контейнер PostgreSQL успешно перезапущен.\033[0m\n\n"
	@printf "\033[1;34m╰──────────────────────────────────────────────────────────────────╯\033[0m\n\n"

# -----------------------------
# Бот (dev) — быстрые проверки
# -----------------------------

bot-health:
	@curl -fsS http://127.0.0.1:8000/health && echo

bot-diag: # [fix] убран jq, формат через python
	@curl -fsS http://127.0.0.1:8000/diag | python3 -m json.tool || true

bot-send: # [fix] убран jq, формат через python
	@curl -fsS -X POST "http://127.0.0.1:8000/send-test?msg=ok" | python3 -m json.tool || true

# -----------------------------
# Бот (образы/контейнер)
# -----------------------------

## Собрать ТОЛЬКО образ бота (dev-слой)
bot-build:
	$(DEV) build kudab-bot

## Пересобрать ТОЛЬКО образ бота (без кэша, с pull)
bot-rebuild:
	$(DEV) build --pull --no-cache kudab-bot

## Собрать ТОЛЬКО образ бота под prod-слой (без запуска)
bot-build-prod:
	$(PROD) build kudab-bot

## Перезапустить контейнер бота (без депсов)
bot-restart:
	$(DEV) up -d --no-deps kudab-bot

## Логи бота
bot-logs:
	$(COMPOSE) logs -f --tail=200 kudab-bot

# -----------------------------
# Бот (prod) — управление вебхуком (без jq)
# Теперь автоматически читаем services/kudab-bot/.env
# -----------------------------

webhook-info:
	@set -a; . services/kudab-bot/.env; set +a; \
	curl -s "https://api.telegram.org/bot$$BOT_TOKEN/getWebhookInfo" | python3 -m json.tool

webhook-set:
	@set -a; . services/kudab-bot/.env; set +a; \
	curl -s "https://api.telegram.org/bot$$BOT_TOKEN/setWebhook" \
	  -d "url=$$WEBHOOK_URL" -d "secret_token=$$WEBHOOK_SECRET" | python3 -m json.tool

webhook-del:
	@set -a; . services/kudab-bot/.env; set +a; \
	curl -s "https://api.telegram.org/bot$$BOT_TOKEN/deleteWebhook" \
	  -d "drop_pending_updates=true" | python3 -m json.tool

bot-help:
	@printf "\nЗапусти в чате: /help, /events today, /events city 1\n"

snapshot-api:
	./tools/snapshot_kudab.sh kudab-api

snapshot-parser:
	./tools/snapshot_kudab.sh kudab-parser

# --- PROD: быстрый деплой только бота (сборка + рестарт контейнера) ---
bot-apply-prod:
	$(PROD) build kudab-bot
	$(PROD) up -d --no-deps kudab-bot

# --- PROD: diag/health ИЗНУТРИ контейнера ---
bot-health-prod:
	$(PROD) exec kudab-bot sh -lc 'curl -fsS http://localhost:8000/health && echo'

bot-diag-prod: # [fix] убран неверный пайп; /diag опционален, /health обязателен
	$(PROD) exec kudab-bot sh -lc '\
	  (curl -fsS http://localhost:8000/diag | python3 -m json.tool || echo "[warn] /diag not available"); \
	  echo; \
	  curl -fsS http://localhost:8000/health && echo'

# --- PROD: перезалить вебхук (удалить + поставить) ---
webhook-refresh: webhook-del webhook-set

# --- Быстрый релиз под prod: собрать, поднять, обновить вебхук, показать diag ---
bot-release:
	$(PROD) build kudab-bot
	$(PROD) up -d --no-deps kudab-bot
	$(MAKE) webhook-refresh
	$(MAKE) bot-diag-prod

# --- Nginx reload на всякий случай ---
nginx-reload:
	$(PROD) exec kudab-nginx nginx -s reload

