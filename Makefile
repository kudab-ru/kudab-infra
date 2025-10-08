# Makefile для kudasobrat.ru (v1.0.1)

COMPOSE = docker compose -f docker-compose.yml
DEV = $(COMPOSE) -f docker-compose.dev.yml
PROD = $(COMPOSE) -f docker-compose.prod.yml

.PHONY: help init dev prod down rebuild logs ps migrate rollback backup

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

bot-diag:
	@curl -fsS http://127.0.0.1:8000/diag | jq .

bot-send:
	@curl -fsS -X POST "http://127.0.0.1:8000/send-test?msg=ok" | jq .

# -----------------------------
# Бот (prod) — управление вебхуком
# Требует переменных: BOT_TOKEN, WEBHOOK_URL, WEBHOOK_SECRET
# -----------------------------

webhook-info:
	@curl -s "https://api.telegram.org/bot$$BOT_TOKEN/getWebhookInfo" | jq .

webhook-set:
	@curl -s "https://api.telegram.org/bot$$BOT_TOKEN/setWebhook" \
	  -d "url=$$WEBHOOK_URL" -d "secret_token=$$WEBHOOK_SECRET" | jq .

webhook-del:
	@curl -s "https://api.telegram.org/bot$$BOT_TOKEN/deleteWebhook" \
	  -d "drop_pending_updates=true" | jq .