# Makefile для kudasobrat.ru (v1.1.2)

COMPOSE = docker compose -f docker-compose.yml
DEV  = $(COMPOSE) -f docker-compose.dev.yml
PROD = $(COMPOSE) -f docker-compose.prod.yml

# --- Superadmin (telegram) ---------------------------------------------------
TG_SUPERADMIN    ?=
SUPERADMIN_EMAIL ?= dev-superadmin@example.test
SUPERADMIN_NAME  ?= Dev Superadmin

.PHONY: help init dev prod prod-service down rebuild logs ps migrate migrate-prod rollback backup fix-port-conflict
.PHONY: bot-health bot-diag bot-send bot-build bot-rebuild bot-build-prod bot-restart bot-logs
.PHONY: webhook-info webhook-set webhook-del webhook-refresh bot-apply-prod bot-health-prod bot-diag-prod bot-release nginx-reload nginx-test
.PHONY: snapshot-api snapshot-parser
.PHONY: tag-release tags-lint tag-del tag-retag tag-move submodules-fix-head
.PHONY: mods-status mods-sync-dev
.PHONY: superadmin

help:
	@printf "\n\033[1;34m╭─────────────────────[ 📦 KUDASOBRAT CLI ]─────────────────────╮\033[0m\n"
	@printf " \033[1;32m  Доступные команды для управления инфраструктурой проекта\033[0m\n"
	@printf " \033[90m  Используйте \033[1;37mmake <команда>\033[0m\033[90m для быстрого запуска задач\033[0m\n"
	@printf "\033[1;34m╰──────────────────────────────────────────────────────────────╯\033[0m\n\n"
	@printf " \033[1;36m%-18s\033[0m %s\n" "init"          "🔧  Клонирование подмодулей и первичная инициализация"
	@printf " \033[1;36m%-18s\033[0m %s\n" "dev"           "🧪  Запуск DEV окружения (hot-reload, маунты)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod"          "🚀  Продакшен-режим (build + up, remove-orphans)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod-service"  "🚀  Пересобрать/перезапустить один сервис (SVC=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "rebuild"       "🔁  Пересборка всех сервисов (no-cache)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "down"          "🛑  Остановить и удалить все контейнеры"
	@printf " \033[1;36m%-18s\033[0m %s\n" "logs"          "📜  Хвост логов всех сервисов (tail -f)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "ps"            "🔍  Статус всех контейнеров"
	@printf " \033[1;36m%-18s\033[0m %s\n" "migrate"       "📂  Artisan migrate (интерактивно)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "migrate-prod"  "📂  Artisan migrate в PROD (--force)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "rollback"      "⏪  Откат версии через scripts/rollback.sh"
	@printf " \033[1;36m%-18s\033[0m %s\n" "backup"        "💾  Ручной backup БД через scripts/backup_db.sh"
	@printf " \033[1;36m%-18s\033[0m %s\n" "superadmin"    "👑  Ensure супер-админ в DEV (TG_SUPERADMIN=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "nginx-test"    "🧪  Проверить синтаксис конфигурации nginx (prod)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "tag-release"   "🏷  Создать infra-тэг rel-<ENV>-YYYYMMDD-SS (из текущей ветки)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "tags-lint"     "🧹  Показать некондиционные тэги"
	@printf " \033[1;36m%-18s\033[0m %s\n" "tag-del"       "🗑  Удалить тэг локально+remote (TAG=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "tag-retag"     "🔁  Перетегировать старый тэг в канон (SRC=..., ENV=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "tag-move"      "🎯  Переместить существующий тэг на REF (TAG=..., REF=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "mods-status"   "🧭  Диагностика веток dev/main по всем подмодулям"
	@printf " \033[1;36m%-18s\033[0m %s\n" "mods-sync-dev" "🤝  Локально выровнять dev=origin/main во всех подмодулях"
	@printf "\n"

init:
	git submodule update --init --recursive

dev:
	$(DEV) up -d --build --remove-orphans

prod:
	$(PROD) up -d --build --remove-orphans

prod-service:
	@test -n "$(SVC)" || (echo "SVC is required: make prod-service SVC=<service-name>"; exit 1)
	$(PROD) up -d --no-deps --build $(SVC)

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

migrate-prod:
	$(PROD) exec kudab-api php artisan migrate --force

rollback:
	bash scripts/rollback.sh

backup:
	bash scripts/backup_db.sh

# -----------------------------
# Superadmin (Telegram -> User)
# -----------------------------

superadmin:
	@test -n "$(TG_SUPERADMIN)" || (echo "TG_SUPERADMIN is required: make superadmin TG_SUPERADMIN=<telegram-id-or-username>"; exit 1)
	$(DEV) exec kudab-api php artisan bot:superadmin $(TG_SUPERADMIN) \
		--email="$(SUPERADMIN_EMAIL)" \
		--name="$(SUPERADMIN_NAME)"

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
	@curl -fsS http://127.0.0.1:8000/diag | python3 -m json.tool || true

bot-send:
	@curl -fsS -X POST "http://127.0.0.1:8000/send-test?msg=ok" | python3 -m json.tool || true

# -----------------------------
# Бот (образы/контейнер)
# -----------------------------

bot-build:
	$(DEV) build kudab-bot

bot-rebuild:
	$(DEV) build --pull --no-cache kudab-bot

bot-build-prod:
	$(PROD) build kudab-bot

bot-restart:
	$(DEV) up -d --no-deps kudab-bot

bot-logs:
	$(COMPOSE) logs -f --tail=200 kudab-bot

# -----------------------------
# Бот (prod) — вебхук
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

# --- PROD: быстрый деплой только бота ---
bot-apply-prod:
	$(PROD) build kudab-bot
	$(PROD) up -d --no-deps kudab-bot

# --- PROD: diag/health изнутри контейнера ---
bot-health-prod:
	$(PROD) exec kudab-bot sh -lc 'curl -fsS http://localhost:8000/health && echo'

bot-diag-prod:
	$(PROD) exec kudab-bot sh -lc '\
	  (curl -fsS http://localhost:8000/diag | python3 -m json.tool || echo "[warn] /diag not available"); \
	  echo; \
	  curl -fsS http://localhost:8000/health && echo'

# --- PROD: перезалить вебхук ---
webhook-refresh: webhook-del webhook-set

# --- Быстрый релиз под prod ---
bot-release:
	$(PROD) build kudab-bot
	$(PROD) up -d --no-deps kudab-bot
	$(MAKE) webhook-refresh
	$(MAKE) bot-diag-prod

# --- Nginx ---
nginx-reload:
	$(PROD) exec kudab-nginx nginx -s reload

nginx-test:
	$(PROD) exec kudab-nginx nginx -t

# -----------------------------
# Infra: тэги (канон rel-<env>-YYYYMMDD-SS)
# -----------------------------

tag-release:
	@if [ -z "$$ENV" ]; then echo "ENV not set (use ENV=prod|stage|dev)"; exit 1; fi; \
	BRANCH=$${BRANCH:-$$(git rev-parse --abbrev-ref HEAD)}; \
	echo "Tagging from branch: $$BRANCH"; \
	git switch $$BRANCH; \
	git pull --ff-only; \
	git submodule status --recursive; \
	DATE=$$(TZ=UTC date +%Y%m%d); \
	SEQ=$$(git tag -l "rel-$$ENV-$$DATE-*" | sed -E 's/.*-([0-9]+)(-.+)?$$/\1/' | sort -n | tail -1 | awk '{print ($$1==""?0:$$1+1)}'); \
	TAG="rel-$$ENV-$$DATE-$$(printf '%02d' "$$SEQ")"; \
	git tag -a "$$TAG" -m "infra: $$TAG — фиксация подмодулей (@$$BRANCH)"; \
	git push origin "$$TAG"; \
	echo "$$TAG"

tags-lint:
	@echo "Non-canonical tags:"; \
	git tag -l | grep -Ev '^rel-(prod|stage|dev)-[0-9]{8}-[0-9]{2}$$' || echo "OK"

tag-del:
	@test -n "$(TAG)" || (echo "TAG is required (make tag-del TAG=<name>)"; exit 1)
	@git push origin :refs/tags/$(TAG) || true
	@git tag -d $(TAG) || true

tag-retag:
	@test -n "$(SRC)" || (echo "SRC (old tag) is required"; exit 1)
	@test -n "$(ENV)" || (echo "ENV=prod|stage|dev is required"; exit 1)
	@COMMIT=$$(git rev-list -n1 "$(SRC)"); \
	DATE=$$(git show -s --format=%cd --date=format:%Y%m%d $$COMMIT); \
	SEQ=$$(git tag -l "rel-$(ENV)-$$DATE-*" | sed -E 's/.*-([0-9]+)$$/\1/' | sort -n | tail -1 | awk '{print ($$1==""?0:$$1+1)}'); \
	NEW=rel-$(ENV)-$$DATE-$$(printf '%02d' "$$SEQ"); \
	git tag -a "$$NEW" "$$COMMIT" -m "infra: retag $(SRC) -> $$NEW"; \
	git push origin "$$NEW"; \
	git push origin :refs/tags/$(SRC) || true; \
	git tag -d $(SRC) || true; \
	echo $$NEW

# Переместить существующий тэг на указанный REF (по умолчанию HEAD)
tag-move:
	@test -n "$(TAG)" || (echo "TAG is required (make tag-move TAG=<name> [REF=<ref>])"; exit 1)
	@REF=$${REF:-$$(git rev-parse HEAD)}; \
	git tag -f -a "$(TAG)" -m "infra: move $(TAG) -> $$REF" "$$REF"; \
	git push origin :refs/tags/$(TAG); \
	git push origin $(TAG)

# Починить origin/HEAD у сабмодулей (если где-то не задан и ломает команды)
submodules-fix-head:
	@git submodule foreach --recursive 'git remote set-head origin -a || true'

# -----------------------------
# Подмодули: диагностика / синк
# -----------------------------

mods-status:
	@git submodule foreach --recursive '\
	  echo "== $$path =="; \
	  git fetch --all --tags >/dev/null 2>&1; \
	  echo -n "branch: "; git rev-parse --abbrev-ref HEAD; \
	  if git show-ref --quiet refs/remotes/origin/dev; then \
	    echo -n "ahead/behind vs origin/dev:  "; git rev-list --left-right --count origin/dev...HEAD; \
	  else echo "no origin/dev"; fi; \
	  if git show-ref --quiet refs/remotes/origin/main; then \
	    echo -n "main..dev: "; git rev-list --left-right --count origin/main...dev 2>/dev/null || echo "n/a"; \
	  fi; echo;'

mods-sync-dev:
	@git submodule foreach --recursive '\
	  git fetch --all --tags >/dev/null 2>&1; \
	  if git show-ref --verify --quiet refs/heads/dev; then git switch dev; else git switch -c dev origin/main; fi; \
	  git merge --ff-only origin/main || git reset --hard origin/main; \
	  git push -u origin dev || git push --force-with-lease origin dev;'
