# Makefile для kudab.ru (v1.1.3)

STACK ?= dev # dev|prod (универсальные алиасы ниже)

DOCKER_GC_UNTIL ?= 168h # 7 дней (docker prune: удалять всё, что не использовалось дольше)

COMPOSE = docker compose -f docker-compose.yml
DEV  = $(COMPOSE) -f docker-compose.dev.yml
PROD = $(COMPOSE) -f docker-compose.prod.yml

DC = $(if $(filter prod,$(STACK)),$(PROD),$(DEV))

# --- Superadmin (telegram) ---------------------------------------------------
TG_SUPERADMIN    ?=
SUPERADMIN_EMAIL ?= dev-superadmin@example.test
SUPERADMIN_NAME  ?= Dev Superadmin

# --- Services ----------------------------------------------------------------
HZ_SVC          ?= kudab-horizon
API_SVC         ?= kudab-api
DB_SVC          ?= kudab-db
PARSER_CLI_SVC  ?= kudab-parser

# -----------------------------
# sugar: allow `make city-on voronezh` instead of `make city-on CITY=voronezh`
# and `make posts-refresh-city voronezh`
# and `make link-ban 123`
ARG2 := $(word 2,$(MAKECMDGOALS))
ifneq ($(ARG2),)
  ifneq ($(filter city-on city-off city-info city-toggle posts-refresh-city,$(firstword $(MAKECMDGOALS))),)
    CITY ?= $(ARG2)
    $(eval $(ARG2):;@:)
  endif
  ifneq ($(filter link-info link-ban link-unban link-gray link-set link-toggle,$(firstword $(MAKECMDGOALS))),)
    LID ?= $(ARG2)
    $(eval $(ARG2):;@:)
  endif
endif

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
.PHONY: errors parsing-errors outbox-retry community-links url-classify
.PHONY: docker-df docker-gc docker-gc-volumes
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
.PHONY: cities city-info city-on city-off city-set city-toggle
.PHONY: posts-refresh posts-refresh-city
.PHONY: links link-info link-ban link-unban link-gray link-set link-toggle

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
	@printf " \033[1;36m%-18s\033[0m %s\n" "docker-df"     "💽  Диск + Docker usage (df -h / + docker system df)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "docker-gc"     "🧹  Docker GC: prune (until=$(DOCKER_GC_UNTIL)) без volumes"
	@printf " \033[1;36m%-18s\033[0m %s\n" "docker-gc-volumes" "🧹  Docker GC: prune dangling volumes (осторожно, но обычно безопасно)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "rebuild"       "🔁  Пересборка всех сервисов (no-cache)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "down"          "🛑  Остановить и удалить все контейнеры"
	@printf " \033[1;36m%-18s\033[0m %s\n" "logs"          "📜  Хвост логов всех сервисов (tail -f)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "ps"            "🔍  Статус всех контейнеров"
	@printf " \033[1;36m%-18s\033[0m %s\n" "errors"        "🧯  parsing: сводка (STACK=dev|prod)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "parsing-errors" "🧯  parsing: список ошибок (STACK=dev|prod, LIMIT=50)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "outbox-retry"  "🔁  parsing: переочередить outbox (STACK=dev|prod, ID=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "community-links" "🔎  parsing: ссылки сообщества (STACK=dev|prod, CID=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "url-classify"  "🔎  parsing: url:classify (STACK=dev|prod, URL=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "links"        "🔗  Источники: список ссылок (CID=..., STATUS=active|gray|black, Q=..., LIMIT=50)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "link-info"    "🔗  Источник: подробности + freeze (LID=<id>)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "link-ban"     "⛔  Источник: в black-list (LID=<id>)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "link-unban"   "✅  Источник: вернуть в active (LID=<id>)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "link-gray"    "🩶  Источник: поставить gray (LID=<id>)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "posts-refresh" "📰  Посты: освежить (enqueue) для всех активных городов (STACK=dev|prod)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "posts-refresh-city" "📰  Посты: освежить по городу (CITY=slug|id, STACK=dev|prod)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "cities"        "🏙️  Города: список + счётчики (STACK=dev|prod, STATUS=..., Q=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "city-info"     "🏙️  Город: подробности + frozen по причинам (STACK=dev|prod, CITY=slug|id)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "city-on"       "✅  Город: включить (active) + разморозить city_inactive (STACK=dev|prod, CITY=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "city-off"      "⛔  Город: выключить (disabled) + заморозить city_inactive (STACK=dev|prod, CITY=...)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "city-set"      "🎚️  Город: выставить статус (STACK=dev|prod, CITY=..., STATUS=active|disabled|limited)"
	@printf " \033[1;36m%-18s\033[0m %s\n" "city-toggle"   "🔁  Город: toggle (осторожно) (STACK=dev|prod, CITY=...)"
	@printf " \033[90m%-18s\033[0m %s\n" "" "пример: make posts-refresh | make posts-refresh-city CITY=voronezh"
	@printf " \033[90m%-18s\033[0m %s\n" "" "пример: make cities STATUS=active | make city-off CITY=voronezh STACK=prod"
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
	$(PROD) up -d --build --remove-orphans --force-recreate
	$(MAKE) docker-gc || true

prod-deploy-service: prod-pull
	@test -n "$(SVC)" || (echo "SVC is required: make prod-deploy-service SVC=<service-name>"; exit 1)
	$(PROD) up -d --no-deps --build --force-recreate $(SVC)
	$(MAKE) docker-gc || true

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

# -----------------------------
# Docker: диск / GC
# -----------------------------

docker-df:
	@df -h / | sed -n '1,2p'
	@docker system df

docker-gc:
	@set -e; \
	UNTIL="$${UNTIL:-$(DOCKER_GC_UNTIL)}"; \
	echo "== docker gc (until=$$UNTIL) =="; \
	docker builder prune -af --filter "until=$$UNTIL" || true; \
	docker system prune  -af --filter "until=$$UNTIL" || true; \
	echo "== docker df =="; \
	docker system df || true

docker-gc-volumes:
	@docker volume prune -f

rollback:
	bash scripts/rollback.sh

backup:
	bash scripts/backup_db.sh

# -----------------------------
# Posts: refresh (enqueue fetch posts)
# -----------------------------

posts-refresh:
	@echo "== STACK=$(STACK) | posts-refresh (enqueue communities posts) =="; \
	$(DC) exec -T $(PARSER_CLI_SVC) php artisan parser:enqueue:communities

posts-refresh-city:
	@test -n "$(CITY)" || (echo "CITY is required: make posts-refresh-city CITY=<slug-or-id> [STACK=dev|prod]"; exit 1)
	@set -e; \
	CITY_IN="$(CITY)"; \
	if echo "$$CITY_IN" | grep -Eq '^[0-9]+$$'; then \
	  CITY_ID="$$CITY_IN"; \
	else \
	  CITY_ESC=$$(printf "%s" "$$CITY_IN" | sed "s/'/''/g"); \
	  CITY_ID=$$($(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select id from cities where slug='$$CITY_ESC' limit 1;"); \
	fi; \
	test -n "$$CITY_ID" || (echo "City not found: $$CITY_IN"; exit 1); \
	STATUS=$$($(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select status from cities where id=$$CITY_ID;"); \
	if [ "$$STATUS" != "active" ]; then \
	  echo "== city_id=$$CITY_ID status=$$STATUS => skip (enable city first) =="; \
	  exit 0; \
	fi; \
	IDS=$$($(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select id from communities where deleted_at is null and city_id=$$CITY_ID order by id;"); \
	test -n "$$IDS" || (echo "No communities for city_id=$$CITY_ID"; exit 0); \
	echo "== posts-refresh-city city_id=$$CITY_ID (communities=$$(echo "$$IDS" | wc -l | tr -d ' ')) =="; \
	printf "%s\n" $$IDS | $(DC) exec -T $(PARSER_CLI_SVC) php -r 'require "vendor/autoload.php"; $$app=require "bootstrap/app.php"; $$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap(); while(($$l=fgets(STDIN))!==false){ $$id=(int)trim($$l); if($$id>0){ App\Jobs\CollectCommunityPostsJob::dispatch($$id); echo "enqueued community $$id\n"; } }'

# -----------------------------
# Cities: управление статусом + парсинг (STACK=dev|prod)
# -----------------------------

cities:
	@set -e; \
	Q="$${Q:-}"; \
	STATUS="$${STATUS:-}"; \
	echo "== STACK=$(STACK) | cities (STATUS=$$STATUS Q=$$Q) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
with \
cc as (select city_id, count(*) cnt from communities where deleted_at is null group by city_id), \
lc as (select c.city_id, count(*) cnt from community_social_links csl join communities c on c.id=csl.community_id where c.deleted_at is null group by c.city_id), \
ec as (select city_id, count(*) cnt from events where deleted_at is null group by city_id), \
fz as ( \
  select c.city_id, count(*) cnt \
  from parsing_statuses ps \
  join community_social_links csl on csl.id=ps.community_social_link_id \
  join communities c on c.id=csl.community_id \
  where ps.is_frozen=true and ps.frozen_reason='city_inactive' and c.deleted_at is null \
  group by c.city_id \
) \
select \
  ct.id, ct.slug, ct.name, ct.status, \
  coalesce(cc.cnt,0) as communities, \
  coalesce(lc.cnt,0) as links, \
  coalesce(ec.cnt,0) as events, \
  coalesce(fz.cnt,0) as frozen_city \
from cities ct \
left join cc on cc.city_id=ct.id \
left join lc on lc.city_id=ct.id \
left join ec on ec.city_id=ct.id \
left join fz on fz.city_id=ct.id \
where (case when '$$STATUS'='' then true else ct.status='$$STATUS' end) \
  and (case when '$$Q'='' then true else (ct.slug ilike '%'||'$$Q'||'%' or ct.name ilike '%'||'$$Q'||'%') end) \
order by ct.status, ct.name;"

city-info:
	@test -n "$(CITY)" || (echo "CITY is required: make city-info CITY=<slug-or-id> [STACK=dev|prod]"; exit 1)
	@set -e; \
	CITY_IN="$(CITY)"; \
	if echo "$$CITY_IN" | grep -Eq '^[0-9]+$$'; then \
	  CID="$$CITY_IN"; \
	else \
	  CITY_ESC=$$(printf "%s" "$$CITY_IN" | sed "s/'/''/g"); \
	  CID=$$($(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -Atc "select id from cities where slug='$$CITY_ESC' limit 1;"); \
	fi; \
	test -n "$$CID" || (echo "City not found: $$CITY_IN"; exit 1); \
	echo "== STACK=$(STACK) | city-info CITY=$$CITY_IN (id=$$CID) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select \
  ct.id, ct.slug, ct.name, ct.status, \
  (select count(*) from communities c where c.deleted_at is null and c.city_id=ct.id) as communities, \
  (select count(*) from community_social_links csl join communities c on c.id=csl.community_id where c.deleted_at is null and c.city_id=ct.id) as links, \
  (select count(*) from events e where e.deleted_at is null and e.city_id=ct.id) as events \
from cities ct \
where ct.id=$$CID;"; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select ps.frozen_reason, count(*) as cnt \
from parsing_statuses ps \
join community_social_links csl on csl.id = ps.community_social_link_id \
join communities c on c.id = csl.community_id \
where c.deleted_at is null \
  and c.city_id = $$CID \
  and ps.is_frozen = true \
group by ps.frozen_reason \
order by cnt desc;"

# Явные команды безопаснее toggle
city-on:
	@test -n "$(CITY)" || (echo "CITY is required: make city-on CITY=<slug-or-id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan city:toggle "$(CITY)" --set=active

city-off:
	@test -n "$(CITY)" || (echo "CITY is required: make city-off CITY=<slug-or-id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan city:toggle "$(CITY)" --set=disabled

city-set:
	@test -n "$(CITY)" || (echo "CITY is required: make city-set CITY=<slug-or-id> STATUS=active|disabled|limited [STACK=dev|prod]"; exit 1)
	@test -n "$(STATUS)" || (echo "STATUS is required: make city-set CITY=<slug-or-id> STATUS=active|disabled|limited"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan city:toggle "$(CITY)" --set="$(STATUS)"

city-toggle:
	@test -n "$(CITY)" || (echo "CITY is required: make city-toggle CITY=<slug-or-id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan city:toggle "$(CITY)"

# -----------------------------
# Parsing: универсальные команды (STACK=dev|prod)
# -----------------------------

errors:
	@set -e; \
	echo "== STACK=$(STACK) =="; \
	echo "== failed jobs =="; \
	$(DC) exec -T $(HZ_SVC) php artisan queue:failed --no-ansi || true; \
	echo ""; \
	echo "== outbox errors (last 30) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -c "\
select id, topic, status, meta, left(coalesce(error_message,''),140) as err, created_at \
from outbox_messages \
where error_message is not null or status='failed' \
order by id desc limit 30;"; \
	echo ""; \
	echo "== parsing_statuses frozen/errored =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -c "\
select frozen_reason, count(*) as cnt \
from parsing_statuses \
where is_frozen=true or last_error is not null or last_error_code is not null \
group by 1 order by 2 desc;"

parsing-errors:
	@set -e; \
	LIMIT=$${LIMIT:-50}; \
	echo "== STACK=$(STACK) | parsing_statuses (limit=$$LIMIT) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select \
  ps.community_social_link_id, \
  csl.community_id, \
  sn.slug as network, \
  csl.url, \
  ps.frozen_reason, \
  ps.unfreeze_at, \
  ps.last_error_code, \
  left(coalesce(ps.last_error,''), 220) as last_error, \
  ps.updated_at \
from parsing_statuses ps \
join community_social_links csl on csl.id = ps.community_social_link_id \
join social_networks sn on sn.id = csl.social_network_id \
where ps.is_frozen=true \
   or ps.last_error is not null \
   or ps.last_error_code is not null \
order by ps.updated_at desc \
limit $$LIMIT;"

outbox-retry:
	@test -n "$(ID)" || (echo "ID is required: make outbox-retry ID=<outbox_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -v ON_ERROR_STOP=1 -c "\
update outbox_messages set \
 status='queued', attempt=0, retry_at=null, started_at=null, finished_at=null, \
 locked_at=null, locked_by=null, error_code=null, error_message=null, updated_at=now() \
where id=$(ID);"

community-links:
	@test -n "$(CID)" || (echo "CID is required: make community-links CID=<community_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -c "\
select csl.id, sn.slug as network, csl.url, csl.external_community_id, csl.created_at \
from community_social_links csl \
join social_networks sn on sn.id=csl.social_network_id \
where csl.community_id=$(CID) \
order by csl.id desc;"

url-classify:
	@test -n "$(URL)" || (echo "URL is required: make url-classify URL=<url> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) sh -lc 'php artisan url:classify "$(URL)"'

# -----------------------------
# Links: black/gray list (community_social_links.status)
# -----------------------------

links:
	@set -e; \
	CID="$${CID:-}"; \
	STATUS="$${STATUS:-}"; \
	Q="$${Q:-}"; \
	LIMIT="$${LIMIT:-50}"; \
	LIMIT=$$( [ "$$LIMIT" -gt 0 ] 2>/dev/null && [ "$$LIMIT" -le 500 ] && echo "$$LIMIT" || echo 50 ); \
	echo "== STACK=$(STACK) | links (CID=$$CID STATUS=$$STATUS Q=$$Q LIMIT=$$LIMIT) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select \
  csl.id as lid, \
  csl.community_id as cid, \
  left(coalesce(c.name,''), 28) as community, \
  coalesce(ct.slug,'-') as city, \
  sn.slug as network, \
  coalesce(csl.status,'active') as status, \
  left(coalesce(csl.external_community_id,''), 22) as ext, \
  left(csl.url, 70) as url \
from community_social_links csl \
join communities c on c.id=csl.community_id and c.deleted_at is null \
join social_networks sn on sn.id=csl.social_network_id \
left join cities ct on ct.id=c.city_id \
where (NULLIF('$$CID','') is null OR csl.community_id = NULLIF('$$CID','')::int) \
  and (case when '$$STATUS'='' then true else coalesce(csl.status,'active') = '$$STATUS' end) \
  and (case when '$$Q'='' then true else (csl.url ilike '%'||'$$Q'||'%' or coalesce(csl.external_community_id,'') ilike '%'||'$$Q'||'%' or c.name ilike '%'||'$$Q'||'%') end) \
order by csl.id desc \
limit $$LIMIT;"

link-info:
	@test -n "$(LID)" || (echo "LID is required: make link-info LID=<link_id> [STACK=dev|prod]"; exit 1)
	@set -e; \
	echo "== STACK=$(STACK) | link-info LID=$(LID) =="; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select \
  csl.id as lid, \
  csl.community_id as cid, \
  left(coalesce(c.name,''), 40) as community, \
  coalesce(ct.slug,'-') as city, \
  sn.slug as network, \
  coalesce(csl.status,'active') as status, \
  csl.external_community_id, \
  csl.url, \
  csl.last_checked_at \
from community_social_links csl \
join communities c on c.id=csl.community_id \
join social_networks sn on sn.id=csl.social_network_id \
left join cities ct on ct.id=c.city_id \
where csl.id = $(LID);"; \
	$(DC) exec -T $(DB_SVC) psql -U kudab -d kudab -P pager=off -v ON_ERROR_STOP=1 -c "\
select \
  ps.is_frozen, ps.frozen_reason, ps.unfreeze_at, left(coalesce(ps.last_error,''),120) as last_error, ps.updated_at \
from parsing_statuses ps \
where ps.community_social_link_id = $(LID);"

link-ban:
	@test -n "$(LID)" || (echo "LID is required: make link-ban LID=<link_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan link:toggle "$(LID)" --set=black

link-unban:
	@test -n "$(LID)" || (echo "LID is required: make link-unban LID=<link_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan link:toggle "$(LID)" --set=active

link-gray:
	@test -n "$(LID)" || (echo "LID is required: make link-gray LID=<link_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan link:toggle "$(LID)" --set=gray

link-set:
	@test -n "$(LID)" || (echo "LID is required: make link-set LID=<link_id> STATUS=active|gray|black [STACK=dev|prod]"; exit 1)
	@test -n "$(STATUS)" || (echo "STATUS is required: make link-set LID=<id> STATUS=active|gray|black"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan link:toggle "$(LID)" --set="$(STATUS)"

link-toggle:
	@test -n "$(LID)" || (echo "LID is required: make link-toggle LID=<link_id> [STACK=dev|prod]"; exit 1)
	$(DC) exec -T $(API_SVC) php artisan link:toggle "$(LID)"

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

CLEAN     ?= 1
RESET_LLM ?= 1
NO_GEO    ?= 0

dev-smoke-post:
	@test -n "$(POST_ID)" || (echo "POST_ID is required: make dev-smoke-post POST_ID=<id>"; exit 1)
	@test -f scripts/dev/smoke_post.sh || (echo "ERROR: scripts/dev/smoke_post.sh not found"; exit 2)
	@chmod +x scripts/dev/smoke_post.sh
	POST_ID=$(POST_ID) PROMPT_VER=$(PROMPT_VER) CLEAN=$(CLEAN) RESET_LLM=$(RESET_LLM) NO_GEO=$(NO_GEO) \
	  bash scripts/dev/smoke_post.sh

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
	NEW=rel-$(ENV)-$$DATE-$$(printf '%02d' "$$SEQ")"; \
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