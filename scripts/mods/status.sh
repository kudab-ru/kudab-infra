#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ошибка] Это не git-репозиторий"
  exit 2
fi

# Цвета (только если есть TTY)
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""
fi

ts() { date +"%H:%M:%S"; }
info() { printf "%s[%s]%s %s\n" "$C_DIM" "$(ts)" "$C_RESET" "$*"; }
ok()   { printf "%s✅%s %s\n" "$C_GREEN$C_BOLD" "$C_RESET" "$*"; }
warn() { printf "%s⚠️%s %s\n" "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
err()  { printf "%s❌%s %s\n" "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; }

die() { err "$*"; exit 2; }

on_err() {
  local code=$?
  err "Скрипт завершился с ошибкой (exit=$code) на строке ${BASH_LINENO[0]}"
  err "Команда: ${BASH_COMMAND}"
  echo
  echo "Подсказка: запусти с трассировкой:"
  echo "  bash -x scripts/dev/reindex.sh"
  exit "$code"
}
trap on_err ERR

is_true() { [[ "${1:-0}" == "1" || "${1:-}" == "true" || "${1:-}" == "yes" ]]; }

# -----------------------------
# STACK + DC
# -----------------------------
STACK="${STACK:-dev}" # dev|prod
[[ "$STACK" == "dev" || "$STACK" == "prod" ]] || die "STACK должен быть dev|prod (получил: $STACK)"

DC_STR="${DC:-}"
if [[ -z "$DC_STR" ]]; then
  if [[ "$STACK" == "prod" ]]; then
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
  else
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
  fi
fi
read -r -a DC_ARR <<<"$DC_STR"
dc() { "${DC_ARR[@]}" "$@"; }

# -----------------------------
# Сервисы (можно переопределять)
# -----------------------------
HZ_SVC="${HZ_SVC:-kudab-horizon}"
API_SVC="${API_SVC:-kudab-api}"
DB_SVC="${DB_SVC:-kudab-db}"

# Где выполнять dev:reset (по умолчанию через API — надежнее, чем через воркеры)
RESET_SVC="${RESET_SVC:-$API_SVC}"

# Где выполнять php -r (assert/consume). Обычно horizon, но можно API.
PHP_SVC="${PHP_SVC:-$HZ_SVC}"

# enqueue communities: если не задан — определим автоматически
PARSER_SVC="${PARSER_SVC:-}"

# -----------------------------
# PROMPT_VER: из env -> из .env -> дефолт
# -----------------------------
read_env_prompt_ver() {
  local v=""
  if [[ -f ".env" ]]; then
    v="$(sed -n 's/^LLM_EVENTS_PROMPT_VERSION=//p' .env 2>/dev/null | head -n 1 | tr -d '\r' | tr -d '"' | tr -d "'")"
  fi
  echo "$v"
}

PROMPT_VER_SRC="(переопределено)"
PROMPT_VER="${PROMPT_VER:-}"
if [[ -z "$PROMPT_VER" ]]; then
  ENV_PROMPT_VER="$(read_env_prompt_ver)"
  if [[ -n "$ENV_PROMPT_VER" ]]; then
    PROMPT_VER="$ENV_PROMPT_VER"
    PROMPT_VER_SRC="(из .env)"
  else
    PROMPT_VER="v8"
    PROMPT_VER_SRC="(по умолчанию)"
  fi
fi

# -----------------------------
# Параметры
# -----------------------------
VERIFY_LIMIT="${VERIFY_LIMIT:-20}"
EVENTS_EXTRACT_LIMIT="${EVENTS_EXTRACT_LIMIT:-5000}"
POSTS_MIN="${POSTS_MIN:-50}"

# Таймауты/паузы
POLL_SEC="${POLL_SEC:-2}"
HZ_ATTEMPTS="${HZ_ATTEMPTS:-60}"         # ~120с
POSTS_ATTEMPTS="${POSTS_ATTEMPTS:-60}"   # ~120с
LLM_ATTEMPTS="${LLM_ATTEMPTS:-200}"      # ~400с

# Шаги: значения по умолчанию зависят от STACK
if [[ "$STACK" == "dev" ]]; then
  UP="${UP:-1}"
  UP_BUILD="${UP_BUILD:-0}"   # dev: без внезапных pull
  MIGRATE="${MIGRATE:-1}"
  RESET="${RESET:-1}"
  RESTART_HZ="${RESTART_HZ:-1}"
  SEED="${SEED:-1}"
  ENQUEUE="${ENQUEUE:-1}"
  VERIFY="${VERIFY:-1}"
  ASSERTS="${ASSERTS:-1}"
  EXTRACT="${EXTRACT:-1}"
  WAIT_LLM="${WAIT_LLM:-1}"
  CONSUME="${CONSUME:-1}"
  CONSUME_SYNC="${CONSUME_SYNC:-1}" # dev: синхронно
else
  UP="${UP:-0}"              # prod: обычно уже поднято
  UP_BUILD="${UP_BUILD:-0}"
  MIGRATE="${MIGRATE:-1}"
  RESET="${RESET:-0}"
  RESTART_HZ="${RESTART_HZ:-0}"
  SEED="${SEED:-0}"
  ENQUEUE="${ENQUEUE:-0}"
  VERIFY="${VERIFY:-0}"
  ASSERTS="${ASSERTS:-0}"
  EXTRACT="${EXTRACT:-1}"
  WAIT_LLM="${WAIT_LLM:-1}"
  CONSUME="${CONSUME:-1}"
  CONSUME_SYNC="${CONSUME_SYNC:-0}" # prod: лучше в очередь
fi

# 0 = всё (ВАЖНО: не превращаем в LIMIT 0)
CONSUME_LIMIT="${CONSUME_LIMIT:-0}"

# Предохранитель на проде
CONFIRM_PROD="${CONFIRM_PROD:-0}"
if [[ "$STACK" == "prod" ]]; then
  if is_true "$RESET" || is_true "$SEED" || is_true "$ENQUEUE"; then
    is_true "$CONFIRM_PROD" || die "Предохранитель PROD: запрошены RESET/SEED/ENQUEUE, но нет CONFIRM_PROD=1. Отказываюсь."
  fi
fi

# -----------------------------
# Вспомогалки
# -----------------------------
step() { printf "\n%s== %s ==%s\n" "$C_BOLD$C_CYAN" "$*" "$C_RESET"; }

need_container() {
  local svc="$1"
  local id
  id="$(dc ps -q "$svc" 2>/dev/null || true)"
  [[ -n "$id" ]] || die "Контейнер сервиса '$svc' не найден (dc ps -q $svc пусто)"
}

detect_parser_svc() {
  if [[ -n "${PARSER_SVC:-}" ]]; then
    echo "$PARSER_SVC"
    return 0
  fi
  if [[ -n "$(dc ps -q kudab-parser 2>/dev/null || true)" ]]; then
    echo "kudab-parser"
  else
    echo "$PHP_SVC"
  fi
}

psql_atc() {
  local q="$1"
  dc exec -T "$DB_SVC" bash -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"$q\""
}

psql_c() {
  local q="$1"
  dc exec -T "$DB_SVC" bash -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -P pager=off -c \"$q\""
}

wait_horizon() {
  step "Ждём, пока $HZ_SVC станет healthy"
  local cid st
  cid="$(dc ps -q "$HZ_SVC" 2>/dev/null || true)"
  [[ -n "$cid" ]] || die "Контейнер $HZ_SVC не найден"

  for i in $(seq 1 "$HZ_ATTEMPTS"); do
    st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid" 2>/dev/null || true)"
    printf "horizon=%s\n" "$st"
    echo "$st" | grep -Eq 'running (healthy|nohealth)' && { ok "$HZ_SVC готов"; return 0; }
    sleep "$POLL_SEC"
  done

  warn "$HZ_SVC не стал healthy вовремя — покажу хвост логов"
  dc logs --tail=200 "$HZ_SVC" || true
  die "$HZ_SVC не стал healthy (попыток: $HZ_ATTEMPTS)"
}

wait_posts() {
  step "Ждём posts: context_posts >= ${POSTS_MIN}"
  for i in $(seq 1 "$POSTS_ATTEMPTS"); do
    c="$(psql_atc 'select count(*) from context_posts;')"
    printf "context_posts=%s\n" "$c"
    [[ "${c:-0}" -ge "$POSTS_MIN" ]] && { ok "Постов достаточно: $c"; return 0; }
    sleep "$POLL_SEC"
  done
  warn "Посты не набрались вовремя — покажу логи $HZ_SVC"
  dc logs --tail=200 "$HZ_SVC" || true
  die "context_posts < POSTS_MIN=$POSTS_MIN (попыток: $POSTS_ATTEMPTS)"
}

wait_llm() {
  step "Ждём, пока завершатся llm_jobs (events_extract, версия=${PROMPT_VER})"
  for i in $(seq 1 "$LLM_ATTEMPTS"); do
    row="$(psql_atc "
select
  count(*) as total,
  count(*) filter (where status in ('pending','processing')) as pend,
  count(*) filter (where status='completed') as done,
  count(*) filter (where status='failed') as failed
from llm_jobs
where task='events_extract' and prompt_version='${PROMPT_VER}';
")"
    printf "llm_jobs => %s\n" "$row"

    IFS='|' read -r total pend done failed <<<"$row"
    total="${total:-0}"; pend="${pend:-999}"

    [[ "$total" -gt 0 && "$pend" -eq 0 ]] && { ok "LLM готово: total=$total done=$done failed=$failed"; return 0; }
    sleep "$POLL_SEC"
  done

  warn "LLM не завершилось вовремя — последние 20 задач"
  psql_c "
select id, context_post_id, status, attempt, retry_at, updated_at
from llm_jobs
where task='events_extract' and prompt_version='${PROMPT_VER}'
order by id desc
limit 20;
" || true

  die "Таймаут ожидания llm_jobs (попыток: $LLM_ATTEMPTS)"
}

# -----------------------------
# Шапка (как в mods-*)
# -----------------------------
printf "\n%s╭──────────────────────────[ 🔁 РЕИНДЕКС ]──────────────────────────╮%s\n" "$C_CYAN$C_BOLD" "$C_RESET"
printf "  %sСреда:%s %s%s%s   |   %sВерсия промпта:%s %s%s%s %s\n" \
  "$C_BOLD" "$C_RESET" "$C_CYAN" "$STACK" "$C_RESET" \
  "$C_BOLD" "$C_RESET" "$C_CYAN" "$PROMPT_VER" "$C_RESET" "$C_DIM$PROMPT_VER_SRC$C_RESET"
printf "  %sDC:%s %s\n" "$C_BOLD" "$C_RESET" "$DC_STR"
printf "  %sСервисы:%s HZ=%s API=%s DB=%s RESET=%s PHP=%s\n" \
  "$C_BOLD" "$C_RESET" "$HZ_SVC" "$API_SVC" "$DB_SVC" "$RESET_SVC" "$PHP_SVC"
printf "  %sФлаги:%s UP=%s BUILD=%s MIGRATE=%s RESET=%s SEED=%s ENQUEUE=%s VERIFY=%s ASSERTS=%s EXTRACT=%s WAIT_LLM=%s CONSUME=%s SYNC=%s\n" \
  "$C_BOLD" "$C_RESET" "$UP" "$UP_BUILD" "$MIGRATE" "$RESET" "$SEED" "$ENQUEUE" "$VERIFY" "$ASSERTS" "$EXTRACT" "$WAIT_LLM" "$CONSUME" "$CONSUME_SYNC"
printf "  %sЛимиты:%s POSTS_MIN=%s VERIFY_LIMIT=%s EXTRACT_LIMIT=%s CONSUME_LIMIT=%s\n" \
  "$C_BOLD" "$C_RESET" "$POSTS_MIN" "$VERIFY_LIMIT" "$EVENTS_EXTRACT_LIMIT" "$CONSUME_LIMIT"
printf "%s╰───────────────────────────────────────────────────────────────────╯%s\n\n" "$C_CYAN$C_BOLD" "$C_RESET"

# -----------------------------
# Запуск
# -----------------------------
need_container "$API_SVC"
need_container "$DB_SVC"
need_container "$HZ_SVC"

if is_true "$UP"; then
  step "Поднимаем docker compose"
  if is_true "$UP_BUILD"; then
    dc up -d --remove-orphans --build
  else
    dc up -d --remove-orphans
  fi
fi

if is_true "$MIGRATE"; then
  step "Миграции (migrate --force) в $API_SVC"
  dc exec -T "$API_SVC" php artisan migrate --force
fi

if is_true "$RESET"; then
  step "Сброс (dev:reset) через $RESET_SVC"
  dc exec -T "$RESET_SVC" php artisan dev:reset --seed=0 --redis=1 --horizon=1
fi

if is_true "$RESTART_HZ"; then
  step "Перезапуск $HZ_SVC (чтобы воркеры перечитали код)"
  dc restart "$HZ_SVC"
fi

wait_horizon

if is_true "$SEED"; then
  step "Сиды (db:seed --force)"
  dc exec -T "$API_SVC" php artisan db:seed --force
fi

if is_true "$ENQUEUE"; then
  step "Постановка задач: communities → очередь"
  PARSER_SVC="$(detect_parser_svc)"
  info "Использую CLI-сервис: PARSER_SVC=$PARSER_SVC"
  dc exec -T "$PARSER_SVC" php artisan parser:enqueue:communities
  wait_posts
fi

if is_true "$VERIFY"; then
  step "Проверка сообществ (VERIFY) — до 3 попыток на каждое"
  ids="$(psql_atc 'select id from communities order by id;')"
  n=0
  for cid in $ids; do
    n=$((n+1))
    printf "\n-- verify [%s] community_id=%s --\n" "$n" "$cid"
    okk=0
    for a in 1 2 3; do
      printf "попытка=%s\n" "$a"
      if dc exec -T "$PHP_SVC" php artisan parser:verify:community:verify-locate "$cid" --limit="$VERIFY_LIMIT" --save --overwrite --clear-on-aggregator; then
        okk=1
        break
      fi
      sleep "$POLL_SEC"
    done
    [[ "$okk" -eq 1 ]] || die "VERIFY провалился для community_id=$cid после 3 попыток"
  done
fi

if is_true "$ASSERTS"; then
  step "Проверки (ASSERT): у communities заполнен city_id"
  dc exec -T "$PHP_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;

$n = DB::table("communities")->whereNull("city_id")->count();
echo "communities_null_city_id={$n}\n";
if ($n > 0) {
  $rows = DB::table("communities")->select("id","name","city","city_id")->whereNull("city_id")->limit(20)->get();
  foreach ($rows as $r) {
    echo "  id={$r->id} city={$r->city} name={$r->name}\n";
  }
  exit(2);
}
'
fi

if is_true "$EXTRACT"; then
  step "Извлечение событий (parser:events:extract), версия=${PROMPT_VER}"
  dc exec -T -e LLM_EVENTS_PROMPT_VERSION="$PROMPT_VER" "$PHP_SVC" \
    php artisan parser:events:extract --limit="$EVENTS_EXTRACT_LIMIT"
fi

if is_true "$WAIT_LLM"; then
  wait_llm
fi

if is_true "$CONSUME"; then
  step "Загрузка результатов: llm_jobs → events (версия=${PROMPT_VER})"

  limit_sql=""
  if [[ "${CONSUME_LIMIT:-0}" =~ ^[0-9]+$ ]] && [[ "${CONSUME_LIMIT:-0}" -gt 0 ]]; then
    limit_sql="limit ${CONSUME_LIMIT}"
  fi

  LIDS="$(psql_atc "
select lj.id
from llm_jobs lj
left join events e
  on e.original_post_id = lj.context_post_id
 and e.deleted_at is null
where lj.task='events_extract'
  and lj.prompt_version='${PROMPT_VER}'
  and lj.status='completed'
  and e.id is null
order by lj.id
${limit_sql};
")"

  k=0
  for lid in $LIDS; do
    k=$((k+1))
    printf "-- обработка [%s] llm_job_id=%s --\n" "$k" "$lid"
    if is_true "$CONSUME_SYNC"; then
      dc exec -T -e LID="$lid" "$PHP_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$id = (int) getenv("LID");
\Illuminate\Support\Facades\Bus::dispatchSync(new \App\Jobs\ConsumeLlmEventsJob($id, false));
echo "OK: синхронно обработано {$id}\n";
'
    else
      dc exec -T -e LID="$lid" "$PHP_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$id = (int) getenv("LID");
\Illuminate\Support\Facades\Bus::dispatch(new \App\Jobs\ConsumeLlmEventsJob($id, false));
echo "OK: поставлено в очередь на обработку {$id}\n";
'
    fi
  done
fi

if is_true "$ASSERTS"; then
  step "Проверки (ASSERT): events.city_id заполнен, если city указан"
  dc exec -T "$PHP_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;

$n = DB::table("events")
  ->whereNull("deleted_at")
  ->whereNotNull("city")
  ->where("city","<>","")
  ->whereNull("city_id")
  ->count();

echo "events_null_city_id_with_city={$n}\n";
if ($n > 0) {
  $rows = DB::table("events")
    ->select("id","community_id","original_post_id","city","city_id","status","updated_at")
    ->whereNull("deleted_at")
    ->whereNotNull("city")
    ->where("city","<>","")
    ->whereNull("city_id")
    ->orderBy("id","desc")
    ->limit(20)
    ->get();

  foreach ($rows as $r) {
    echo "  id={$r->id} community_id={$r->community_id} post={$r->original_post_id} city={$r->city} status={$r->status} updated_at={$r->updated_at}\n";
  }
  exit(2);
}
'
fi

step "Итоги"
cat <<'SQL' | dc exec -T "$DB_SVC" bash -lc 'psql -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /dev/stdin'
select prompt_version, status, count(*) as cnt
from llm_jobs
where task='events_extract'
group by 1,2
order by 1,2;

select status, count(*) as cnt
from context_posts
group by 1
order by 1;

select count(*) as events_total
from events
where deleted_at is null;
SQL

echo
ok "Готово."

echo
printf "%sПодсказки:%s\n" "$C_BOLD" "$C_RESET"
printf "  1) DEV полный прогон:   %sSTACK=dev ./scripts/dev/reindex.sh%s\n" "$C_CYAN" "$C_RESET"
printf "  2) PROD безопасно:      %sSTACK=prod ./scripts/dev/reindex.sh%s\n" "$C_CYAN" "$C_RESET"
printf "  3) PROD с reset/seed:   %sSTACK=prod RESET=1 SEED=1 ENQUEUE=1 CONFIRM_PROD=1 ./scripts/dev/reindex.sh%s\n" "$C_CYAN" "$C_RESET"
printf "  4) Явно версия промпта: %sPROMPT_VER=v8 STACK=dev ./scripts/dev/reindex.sh%s\n\n" "$C_CYAN" "$C_RESET"
