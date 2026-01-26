# Makefile для kudasobrat.ru (v1.1.3)

COMPOSE = docker compose -f docker-compose.yml
DEV  = $(COMPOSE) -f docker-compose.dev.yml
PROD = $(COMPOSE) -f docker-compose.prod.yml

# --- Superadmin (telegram) ---------------------------------------------------
TG_SUPERADMIN    ?=
SUPERADMIN_EMAIL ?= dev-superadmin@example.test
SUPERADMIN_NAME  ?= Dev Superadmin

# --- Services (DEV) ----------------------------------------------------------
HZ_SVC          ?= kudab-horizon
API_SVC         ?= kudab-api
DB_SVC          ?= kudab-db
PARSER_CLI_SVC  ?= kudab-parser

# -----------------------------
# LLM / Parser: one-button dev smoke test
# -----------------------------

# PROMPT_VER берём из .env (LLM_EVENTS_PROMPT_VERSION), но можно переопределить make PROMPT_VER=...
ENV_PROMPT_VER := $(shell sed -n 's/^LLM_EVENTS_PROMPT_VERSION=//p' .env 2>/dev/null | head -n 1 | tr -d '\r')
PROMPT_VER   ?= $(if $(strip $(ENV_PROMPT_VER)),$(strip $(ENV_PROMPT_VER)),v8)

BENCH_LIMIT  ?= 50
BENCH_FILE   ?= llm/bench/posts.json

SMOKE_POLL_SEC        ?= 2
SMOKE_HZ_ATTEMPTS     ?= 60    # 120s
SMOKE_POSTS_ATTEMPTS  ?= 60
SMOKE_LLM_ATTEMPTS    ?= 120   # 240s
SMOKE_POSTS_MIN       ?= $(BENCH_LIMIT)  # ждём минимум постов под bench

# -----------------------------
# REINDEX: универсальный прогон через scripts/dev/reindex.sh
# (явно прокидываем env, иначе скрипт возьмёт дефолты)
# -----------------------------

REINDEX_VERIFY_LIMIT         ?= 20
REINDEX_EVENTS_EXTRACT_LIMIT ?= 2000
REINDEX_POSTS_MIN            ?= $(SMOKE_POSTS_MIN)

.PHONY: help init dev prod prod-service down rebuild logs ps migrate migrate-prod rollback backup fix-port-conflict
.PHONY: bot-health bot-diag bot-send bot-build bot-rebuild bot-build-prod bot-restart bot-logs
.PHONY: webhook-info webhook-set webhook-del webhook-refresh bot-apply-prod bot-health-prod bot-diag-prod bot-release nginx-reload nginx-test
.PHONY: snapshot-api snapshot-parser
.PHONY: tag-release tags-lint tag-del tag-retag tag-move submodules-fix-head
.PHONY: mods-status mods-sync-dev mods-update mods-promote mods-backport
.PHONY: superadmin
.PHONY: dev-smoke dev-smoke-reset dev-smoke-wait-horizon dev-smoke-seed dev-smoke-posts dev-smoke-llm dev-smoke-report
.PHONY: dev-smoke-post dev-post
.PHONY: reindex reindex-prod
.PHONY: dev-test
.PHONY: prod-pull prod-deploy prod-deploy-service

help:
	@printf "\n\033[1;34m╭─────────────────────[ 📦 KUDASOBRAT CLI ]─────────────────────╮\033[0m\n"
	@printf " \033[1;32m  Доступные команды для управления инфраструктурой проекта\033[0m\n"
	@printf " \033[90m  Используйте \033[1;37mmake <команда>\033[0m\033[90m для быстрого запуска задач\033[0m\n"
	@printf "\033[1;34m╰──────────────────────────────────────────────────────────────╯\033[0m\n\n"
	@printf " \033[1;36m%-18s\033[0m %s\n" "init"          "🔧  Клонирование подмодулей и первичная инициализация"
	@printf " \033[1;36m%-18s\033[0m %s\n" "dev"           "🧪  Запуск DEV окружения (hot-reload, маунты)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "dev-smoke"     "🧪  DEV smoke (reset+wait-horizon+seed+posts+llm+report)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "dev-smoke-post" "🧪  DEV smoke по одному существующему посту (POST_ID=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "reindex"       "🔁  REINDEX в DEV (reset/seed/enqueue/verify/assert/extract/wait/consume)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "reindex-prod"  "🔁  REINDEX в PROD (safe: без reset/seed/enqueue/verify/assert, consume не sync)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod"          "🚀  Продакшен-режим (build + up, remove-orphans)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod-service"  "🚀  Пересобрать/перезапустить один сервис (SVC=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod-pull"     "⬇️  PROD: стянуть актуальный infra+подмодули (git fetch/reset + submodule update)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod-deploy"   "🚀  PROD: prod-pull + up -d --build --remove-orphans"
	@printf " \033[1;36m%-18s\033[0m %s\n" "prod-deploy-service" "🚀  PROD: prod-pull + rebuild/recreate одного сервиса (SVC=...)"
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
	@printf " \033[1;36m%-18s\033[0m %s\n" "mods-backport" "🧯  Main → Dev во всех сервисах (ff-only) + обновить infra/dev"
	@printf " \033[1;36m%-18s\033[0m %s\n" "mods-sync-dev" "🤝  Локально выровнять dev=origin/main во всех подмодулям"
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

# -----------------------------
# PROD: pull latest infra + submodules (safe for pinned submodules)
# Примечание: DETACHED в подмодулях на проде — норма, если infra пинит SHA.
# -----------------------------

prod-pull:
	@set -e; \
	echo "== git: update infra repo =="; \
	git config --local fetch.recurseSubmodules false; \
	git config --local submodule.recurse false; \
	git fetch origin --prune; \
	git switch main; \
	git reset --hard origin/main; \
	echo "== git: sync/update submodules =="; \
	git submodule sync --recursive; \
	git submodule update --init --recursive; \
	echo "✅ prod-pull DONE"; \
	$(MAKE) mods-status || true

prod-deploy: prod-pull
	$(PROD) up -d --build --remove-orphans

prod-deploy-service: prod-pull
	@test -n "$(SVC)" || (echo "SVC is required: make prod-deploy-service SVC=<service-name>"; exit 1)
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
# LLM / Parser: one-button dev smoke test
# -----------------------------

dev-smoke: dev-smoke-reset dev-smoke-wait-horizon dev-smoke-seed dev-smoke-posts dev-smoke-llm dev-smoke-report
	@echo "✅ dev-smoke DONE (version=$(PROMPT_VER))"

dev-smoke-reset:
	$(DEV) exec -T $(API_SVC) php artisan dev:reset --seed=0 --redis=1 --horizon=1

dev-smoke-wait-horizon:
	@cid=`$(DEV) ps -q $(HZ_SVC)`; \
	  test -n "$$cid" || (echo "❌ ERROR: $(HZ_SVC) container not found"; exit 2); \
	  echo "waiting horizon healthy (cid=$$cid) ..."; \
	  for i in $$(seq 1 $(SMOKE_HZ_ATTEMPTS)); do \
	    st=$$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' $$cid 2>/dev/null || true); \
	    echo "horizon=$$st"; \
	    echo "$$st" | grep -Eq 'running (healthy|nohealth)' && exit 0; \
	    sleep $(SMOKE_POLL_SEC); \
	  done; \
	  echo "❌ ERROR: horizon not healthy in time"; \
	  $(DEV) logs --tail=200 $(HZ_SVC); \
	  exit 2

dev-smoke-seed:
	$(DEV) exec -T $(API_SVC) php artisan db:seed --force

dev-smoke-posts:
	@echo "enqueue communities via $(PARSER_CLI_SVC) ..."
	$(DEV) exec -T $(PARSER_CLI_SVC) php artisan parser:enqueue:communities
	@echo "waiting context_posts >= $(SMOKE_POSTS_MIN) ..."; \
	  for i in $$(seq 1 $(SMOKE_POSTS_ATTEMPTS)); do \
	    c=`$(DEV) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select count(*) from context_posts;"`; \
	    echo "context_posts=$$c"; \
	    test "$$c" -ge $(SMOKE_POSTS_MIN) && exit 0; \
	    sleep $(SMOKE_POLL_SEC); \
	  done; \
	  echo "❌ ERROR: context_posts < $(SMOKE_POSTS_MIN)"; \
	  $(DEV) logs --tail=200 $(HZ_SVC); \
	  exit 2

dev-smoke-llm:
	$(DEV) exec -T $(HZ_SVC) php artisan llm:bench:make --limit=$(BENCH_LIMIT) --min_text=0 --file=$(BENCH_FILE)
	@ids=`$(DEV) exec -T $(HZ_SVC) php -r 'echo count(json_decode(@file_get_contents("storage/app/$(BENCH_FILE)"), true) ?? []);'`; \
	  echo "bench_ids=$$ids"; \
	  test "$$ids" -gt 0 || (echo "❌ ERROR: bench file has 0 ids ($(BENCH_FILE))"; exit 2)
	$(DEV) exec -T $(HZ_SVC) php artisan llm:bench:run $(PROMPT_VER) --file=$(BENCH_FILE) --reset=1
	@echo "waiting llm_jobs finished (version=$(PROMPT_VER)) ..."; \
	  for i in $$(seq 1 $(SMOKE_LLM_ATTEMPTS)); do \
	    total=`$(DEV) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select count(*) from llm_jobs where task='events_extract' and prompt_version='$(PROMPT_VER)';"`; \
	    pend=`$(DEV) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select count(*) from llm_jobs where task='events_extract' and prompt_version='$(PROMPT_VER)' and status in ('pending','processing');"`; \
	    echo "llm_jobs total=$$total pending_or_processing=$$pend"; \
	    test "$$total" -gt 0 -a "$$pend" -eq 0 && exit 0; \
	    sleep $(SMOKE_POLL_SEC); \
	  done; \
	  echo "❌ ERROR: llm_jobs not finished in time"; \
	  $(DEV) exec -T $(DB_SVC) psql -U kudab -d kudab -c "select id, context_post_id, status, attempt, retry_at, updated_at from llm_jobs where task='events_extract' and prompt_version='$(PROMPT_VER)' order by id desc limit 20;"; \
	  exit 2

dev-smoke-report:
	$(DEV) exec -T $(HZ_SVC) php artisan llm:bench:report --file=$(BENCH_FILE) --versions=$(PROMPT_VER)

# -----------------------------
# Smoke: one existing post (POST_ID)
# -----------------------------

# 1 = снести derived-данные по посту (events/event_sources/event_interest)
CLEAN     ?= 1
# 1 = удалить llm_jobs по посту+версии перед прогоном (детерминированность)
RESET_LLM ?= 1
# 1 = ConsumeLlmEventsJob(..., true). Должно быть разрешено allow_no_geo.
NO_GEO    ?= 0

dev-smoke-post:
	@test -n "$(POST_ID)" || (echo "POST_ID is required: make dev-smoke-post POST_ID=<id>"; exit 1)
	@test -f scripts/dev/smoke_post.sh || (echo "ERROR: scripts/dev/smoke_post.sh not found"; exit 2)
	@chmod +x scripts/dev/smoke_post.sh
	POST_ID=$(POST_ID) PROMPT_VER=$(PROMPT_VER) CLEAN=$(CLEAN) RESET_LLM=$(RESET_LLM) NO_GEO=$(NO_GEO) \
	  bash scripts/dev/smoke_post.sh

# алиас покороче
dev-post: dev-smoke-post

# -----------------------------
# REINDEX (универсальный, красивый вывод)
# -----------------------------

reindex:
	@set -e; \
	echo ""; \
	printf "\033[1;34m╭──────────────────────[ 🔁 REINDEX ]──────────────────────╮\033[0m\n"; \
	printf "  STACK: dev | DC: DEV | PROMPT_VER: %s\n" "$(PROMPT_VER)"; \
	printf "  limits: POSTS_MIN=%s VERIFY_LIMIT=%s EXTRACT_LIMIT=%s\n" "$(REINDEX_POSTS_MIN)" "$(REINDEX_VERIFY_LIMIT)" "$(REINDEX_EVENTS_EXTRACT_LIMIT)"; \
	printf "\033[1;34m╰──────────────────────────────────────────────────────────╯\033[0m\n"; \
	STACK=dev \
	DC='$(DEV)' \
	PROMPT_VER='$(PROMPT_VER)' \
	VERIFY_LIMIT='$(REINDEX_VERIFY_LIMIT)' \
	EVENTS_EXTRACT_LIMIT='$(REINDEX_EVENTS_EXTRACT_LIMIT)' \
	POSTS_MIN='$(REINDEX_POSTS_MIN)' \
	bash scripts/dev/reindex.sh

# Прод: безопасный режим (без reset/seed/enqueue/verify/assert; consume в очередь, не sync)
# Прод: безопасный режим по умолчанию, но флаги можно переопределять:
# make reindex-prod CONFIRM_PROD=1 SEED=1 ENQUEUE=1
reindex-prod:
	@set -e; \
	echo ""; \
	printf "\033[1;34m╭──────────────────────[ 🔁 REINDEX ]──────────────────────╮\033[0m\n"; \
	printf "  STACK: prod | DC: PROD | PROMPT_VER: %s\n" "$(PROMPT_VER)"; \
	printf "  safe defaults: RESET=0 SEED=0 ENQUEUE=0 VERIFY=0 ASSERTS=0 CONSUME_SYNC=0\n"; \
	printf "  limits: POSTS_MIN=%s VERIFY_LIMIT=%s EXTRACT_LIMIT=%s\n" "$(REINDEX_POSTS_MIN)" "$(REINDEX_VERIFY_LIMIT)" "$(REINDEX_EVENTS_EXTRACT_LIMIT)"; \
	printf "\033[1;34m╰──────────────────────────────────────────────────────────╯\033[0m\n"; \
	STACK=prod \
	DC='$(PROD)' \
	PROMPT_VER='$(PROMPT_VER)' \
	VERIFY_LIMIT='$(REINDEX_VERIFY_LIMIT)' \
	EVENTS_EXTRACT_LIMIT='$(REINDEX_EVENTS_EXTRACT_LIMIT)' \
	POSTS_MIN='$(REINDEX_POSTS_MIN)' \
	RESET=$${RESET:-0} SEED=$${SEED:-0} ENQUEUE=$${ENQUEUE:-0} VERIFY=$${VERIFY:-0} ASSERTS=$${ASSERTS:-0} CONSUME_SYNC=$${CONSUME_SYNC:-0} \
	bash scripts/dev/reindex.sh

# -----------------------------
# Full pipeline: communities -> posts -> verify -> events_extract
# -----------------------------

dev-test:
	@test -f scripts/dev/reindex.sh || (echo "ERROR: scripts/dev/reindex.sh not found"; exit 2)
	@chmod +x scripts/dev/reindex.sh
	PROMPT_VER=$(PROMPT_VER) VERIFY_LIMIT=$(REINDEX_VERIFY_LIMIT) EVENTS_EXTRACT_LIMIT=$(REINDEX_EVENTS_EXTRACT_LIMIT) POSTS_MIN=$(REINDEX_POSTS_MIN) \
	  bash scripts/dev/reindex.sh

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

tag-move:
	@test -n "$(TAG)" || (echo "TAG is required (make tag-move TAG=<name> [REF=<ref>])"; exit 1)
	@REF=$${REF:-$$(git rev-parse HEAD)}; \
	git tag -f -a "$(TAG)" -m "infra: move $(TAG) -> $$REF" "$$REF"; \
	git push origin :refs/tags/$(TAG); \
	git push origin $(TAG)

submodules-fix-head:
	@git submodule foreach --recursive 'git remote set-head origin -a || true'

# -----------------------------
# Подмодули: диагностика / синк
# -----------------------------

mods-status:
	@TARGET="$${TARGET:-$$(git rev-parse --abbrev-ref HEAD)}" FETCH="$${FETCH:-0}" bash scripts/mods/status.sh

mods-update:
	@TARGET="$${TARGET:-$$(git rev-parse --abbrev-ref HEAD)}" bash scripts/mods/update.sh

mods-promote:
	@bash scripts/mods/promote.sh

mods-backport:
	@bash scripts/mods/backport.sh

mods-sync-dev:
	@TARGET="dev" bash scripts/mods/update.sh
