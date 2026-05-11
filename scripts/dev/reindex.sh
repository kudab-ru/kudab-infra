#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# Universal reindex script for dev/prod
# ------------------------------------------------------------
# Usage examples:
#   # DEV (full, as before):
#   STACK=dev ./scripts/dev/reindex.sh
#
#   # PROD (safe defaults: no reset/seed/enqueue/verify/assert):
#   STACK=prod ./scripts/dev/reindex.sh
#
#   # PROD with explicit destructive actions (NOT recommended):
#   STACK=prod RESET=1 SEED=1 ENQUEUE=1 CONFIRM_PROD=1 ./scripts/dev/reindex.sh
# ------------------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

# -----------------------------
# pretty output
# -----------------------------
NO_COLOR="${NO_COLOR:-0}"

if [[ "$NO_COLOR" == "1" ]]; then
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
else
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
  C_DIM=$'\033[90m'
  C_RESET=$'\033[0m'
fi

ts() { date +"%H:%M:%S"; }
log()  { echo "${C_DIM}[$(ts)]${C_RESET} $*"; }
ok()   { echo "${C_GREEN}✅${C_RESET} $*"; }
warn() { echo "${C_YELLOW}⚠️${C_RESET} $*" >&2; }
die()  { echo "${C_RED}❌${C_RESET} $*" >&2; exit 2; }

on_err() {
  local code=$?
  warn "script failed (exit=$code) at line=${BASH_LINENO[0]} cmd: ${BASH_COMMAND}"
  exit "$code"
}
trap on_err ERR

is_true() {
  [[ "${1:-0}" == "1" || "${1:-}" == "true" || "${1:-}" == "yes" ]]
}

# -----------------------------
# stack + compose
# -----------------------------
STACK="${STACK:-dev}" # dev|prod
[[ "$STACK" == "dev" || "$STACK" == "prod" ]] || die "STACK must be dev|prod (got: $STACK)"

# Compose command (can be overridden from Makefile by passing DC="docker compose ...")
DC_STR="${DC:-}"
if [[ -z "$DC_STR" ]]; then
  if [[ "$STACK" == "prod" ]]; then
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
  else
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
  fi
fi

# Parse DC_STR into array (OK for our simple tokens like: docker compose -f a -f b)
read -r -a DC_ARR <<<"$DC_STR"
dc() { "${DC_ARR[@]}" "$@"; }

# -----------------------------
# services (can be overridden)
# -----------------------------
HZ_SVC="${HZ_SVC:-kudab-horizon}"
API_SVC="${API_SVC:-kudab-api}"
DB_SVC="${DB_SVC:-kudab-db}"
PARSER_SVC="${PARSER_SVC:-}" # will autodetect if empty

# -----------------------------
# read prompt ver from .env if not set
# -----------------------------
read_env_prompt_ver() {
  local v=""
  if [[ -f ".env" ]]; then
    v="$(sed -n 's/^LLM_EVENTS_PROMPT_VERSION=//p' .env 2>/dev/null | head -n 1 | tr -d '\r' | tr -d '"' | tr -d "'")"
  fi
  echo "$v"
}

PROMPT_VER="${PROMPT_VER:-}"
if [[ -z "$PROMPT_VER" ]]; then
  ENV_PROMPT_VER="$(read_env_prompt_ver)"
  PROMPT_VER="${ENV_PROMPT_VER:-v8}"
fi

# Tunables
VERIFY_LIMIT="${VERIFY_LIMIT:-20}"
EVENTS_EXTRACT_LIMIT="${EVENTS_EXTRACT_LIMIT:-5000}"
POSTS_MIN="${POSTS_MIN:-50}"

# Timeouts
SMOKE_POLL_SEC="${SMOKE_POLL_SEC:-2}"
HZ_ATTEMPTS="${HZ_ATTEMPTS:-60}"         # 120s by default
POSTS_ATTEMPTS="${POSTS_ATTEMPTS:-60}"   # 120s by default
LLM_ATTEMPTS="${LLM_ATTEMPTS:-200}"      # 400s by default

# Defaults depending on stack
if [[ "$STACK" == "dev" ]]; then
  UP="${UP:-1}"
  UP_BUILD="${UP_BUILD:-0}"     # dev: avoid unexpected pulls
  MIGRATE="${MIGRATE:-1}"
  RESET="${RESET:-1}"
  RESTART_HORIZON="${RESTART_HORIZON:-1}"
  SEED="${SEED:-1}"
  ENQUEUE="${ENQUEUE:-1}"
  VERIFY="${VERIFY:-1}"
  ASSERTS="${ASSERTS:-1}"
  EXTRACT="${EXTRACT:-1}"
  WAIT_LLM="${WAIT_LLM:-1}"
  CONSUME="${CONSUME:-1}"
  CONSUME_SYNC="${CONSUME_SYNC:-1}"  # dev: deterministic

  # ✅ groups in dev: run automatically after pipeline
  GROUPS="${GROUPS:-1}"

  # ✅ HQ autofix in dev: locate-by-name + promote-from-events + re-consume
  # needs_geo + geo:backfill. Закрывает гэп для venue_host communities, у
  # которых verify-locate не нашёл адрес в постах (театры, музеи). После
  # reset на dev'е без этого Пиковая дама и т.п. остаются без адреса до
  # scheduler-окна 04:25 (§13q).
  HQ_AUTOFIX="${HQ_AUTOFIX:-1}"
else
  UP="${UP:-0}"                # prod: usually already running; don't touch unless asked
  UP_BUILD="${UP_BUILD:-0}"
  MIGRATE="${MIGRATE:-1}"
  RESET="${RESET:-0}"
  RESTART_HORIZON="${RESTART_HORIZON:-0}"
  SEED="${SEED:-0}"
  ENQUEUE="${ENQUEUE:-0}"
  VERIFY="${VERIFY:-0}"        # prod: can be very long
  ASSERTS="${ASSERTS:-0}"
  EXTRACT="${EXTRACT:-1}"
  WAIT_LLM="${WAIT_LLM:-1}"
  CONSUME="${CONSUME:-1}"
  CONSUME_SYNC="${CONSUME_SYNC:-0}"  # prod: safer to enqueue, not sync-run in one process

  # ✅ groups in prod: off by default (enable manually if needed)
  GROUPS="${GROUPS:-0}"

  # ✅ HQ autofix in prod: off by default — scheduler уже крутит его 04:25
  # ежедневно, и promote-from-events может несущественно тронуть communities.
  # Запускать вручную (HQ_AUTOFIX=1) только если нужно прогнать прямо сейчас.
  HQ_AUTOFIX="${HQ_AUTOFIX:-0}"
fi

CONSUME_LIMIT="${CONSUME_LIMIT:-0}" # 0 = all (IMPORTANT)

# Safety gate for prod destructive actions
CONFIRM_PROD="${CONFIRM_PROD:-0}"
if [[ "$STACK" == "prod" ]]; then
  if is_true "$RESET" || is_true "$SEED" || is_true "$ENQUEUE"; then
    if ! is_true "$CONFIRM_PROD"; then
      die "PROD safety: RESET/SEED/ENQUEUE requested, but CONFIRM_PROD=1 is not set. Refusing."
    fi
  fi
fi

# -----------------------------
# helpers
# -----------------------------
header() {
  echo
  echo "${C_BLUE}╭──────────────────────[ 🔁 REINDEX ]──────────────────────╮${C_RESET}"
  printf "  STACK: %s | DC: %s\n" "$STACK" "$DC_STR"
  printf "  PROMPT_VER: %s\n" "$PROMPT_VER"
  printf "  services: HZ=%s API=%s DB=%s\n" "$HZ_SVC" "$API_SVC" "$DB_SVC"
  echo "  flags: UP=$UP UP_BUILD=$UP_BUILD MIGRATE=$MIGRATE RESET=$RESET RESTART_HZ=$RESTART_HORIZON SEED=$SEED ENQUEUE=$ENQUEUE VERIFY=$VERIFY ASSERTS=$ASSERTS EXTRACT=$EXTRACT WAIT_LLM=$WAIT_LLM CONSUME=$CONSUME CONSUME_SYNC=$CONSUME_SYNC HQ_AUTOFIX=$HQ_AUTOFIX GROUPS=$GROUPS"
  echo "  limits: POSTS_MIN=$POSTS_MIN VERIFY_LIMIT=$VERIFY_LIMIT EXTRACT_LIMIT=$EVENTS_EXTRACT_LIMIT CONSUME_LIMIT=$CONSUME_LIMIT"
  echo "${C_BLUE}╰──────────────────────────────────────────────────────────╯${C_RESET}"
  echo
}

need_container() {
  local svc="$1"
  local id
  id="$(dc ps -q "$svc" 2>/dev/null || true)"
  [[ -n "$id" ]] || die "container for service '$svc' not found (dc ps -q $svc is empty)"
}

wait_horizon() {
  log "== 2) wait horizon healthy =="
  local cid st
  cid="$(dc ps -q "$HZ_SVC" 2>/dev/null || true)"
  [[ -n "$cid" ]] || die "$HZ_SVC container not found"

  for i in $(seq 1 "$HZ_ATTEMPTS"); do
    st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid" 2>/dev/null || true)"
    echo "horizon=$st"
    echo "$st" | grep -Eq 'running (healthy|nohealth)' && { ok "horizon is ready"; return 0; }
    sleep "$SMOKE_POLL_SEC"
  done

  dc logs --tail=200 "$HZ_SVC" || true
  die "horizon not healthy in time (attempts=$HZ_ATTEMPTS)"
}

wait_posts() {
  log "== 5) wait context_posts >= ${POSTS_MIN} =="
  for i in $(seq 1 "$POSTS_ATTEMPTS"); do
    local c
    c="$(dc exec -T "$DB_SVC" sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from context_posts;"')"
    echo "context_posts=$c"
    if [[ "${c:-0}" -ge "$POSTS_MIN" ]]; then
      ok "posts reached threshold ($c >= $POSTS_MIN)"
      return 0
    fi
    sleep "$SMOKE_POLL_SEC"
  done
  dc logs --tail=200 "$HZ_SVC" || true
  die "context_posts did not reach POSTS_MIN=$POSTS_MIN in time (attempts=$POSTS_ATTEMPTS)"
}

wait_llm() {
  log "== 8) wait llm_jobs done (v=${PROMPT_VER}) =="
  for i in $(seq 1 "$LLM_ATTEMPTS"); do
    local row total pend done failed
    row="$(dc exec -T "$DB_SVC" sh -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"
select
  count(*) as total,
  count(*) filter (where status in ('pending','processing')) as pend,
  count(*) filter (where status='completed') as done,
  count(*) filter (where status='failed') as failed
from llm_jobs
where task='events_extract' and prompt_version='${PROMPT_VER}';
\"")"
    echo "llm_jobs => $row"

    IFS='|' read -r total pend done failed <<<"$row"
    total="${total:-0}"; pend="${pend:-999}"

    if [[ "$total" -gt 0 && "$pend" -eq 0 ]]; then
      ok "llm_jobs finished (total=$total done=$done failed=$failed)"
      return 0
    fi
    sleep "$SMOKE_POLL_SEC"
  done

  dc exec -T "$DB_SVC" sh -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -P pager=off -c \"
select id, context_post_id, status, attempt, retry_at, updated_at
from llm_jobs
where task='events_extract' and prompt_version='${PROMPT_VER}'
order by id desc
limit 20;\"" || true

  die "llm_jobs not finished in time (attempts=$LLM_ATTEMPTS)"
}

detect_parser_svc() {
  if [[ -n "${PARSER_SVC:-}" ]]; then
    echo "$PARSER_SVC"
    return 0
  fi
  if [[ -n "$(dc ps -q kudab-parser 2>/dev/null || true)" ]]; then
    echo "kudab-parser"
  else
    echo "$HZ_SVC"
  fi
}

sql_ids() {
  local q="$1"
  dc exec -T "$DB_SVC" sh -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"$q\""
}

# -----------------------------
# run
# -----------------------------
header

if is_true "$UP"; then
  log "== 0) docker compose up =="
  if is_true "$UP_BUILD"; then
    dc up -d --remove-orphans --build
  else
    dc up -d --remove-orphans
  fi
  echo
fi

need_container "$HZ_SVC"
need_container "$API_SVC"
need_container "$DB_SVC"

if is_true "$MIGRATE"; then
  log "== 0.5) MIGRATE ($API_SVC) =="
  dc exec -T "$API_SVC" php artisan migrate --force
  echo
fi

if is_true "$RESET"; then
  log "== 1) RESET (truncate/redis/horizon terminate) =="
  dc exec -T "$HZ_SVC" php artisan dev:reset --seed=0 --redis=1 --horizon=1
  echo
fi

if is_true "$RESTART_HORIZON"; then
  log "== 1.1) restart horizon ($HZ_SVC) =="
  dc restart "$HZ_SVC"
  echo
fi

wait_horizon
echo

if is_true "$SEED"; then
  log "== 3) SEED =="
  dc exec -T "$API_SVC" php artisan db:seed --force
  echo
fi

if is_true "$ENQUEUE"; then
  log "== 4) ENQUEUE communities =="
  PARSER_SVC="$(detect_parser_svc)"
  log "using PARSER_SVC=$PARSER_SVC"
  dc exec -T "$PARSER_SVC" php artisan parser:enqueue:communities
  echo

  wait_posts
  echo
fi

if is_true "$VERIFY"; then
  log "== 6) VERIFY communities (3 attempts each) =="
  ids="$(sql_ids 'select id from communities order by id;')"
  n=0
  for cid in $ids; do
    n=$((n+1))
    echo
    echo "-- verify [$n] community_id=$cid --"
    okk=0
    for a in 1 2 3; do
      echo "attempt=$a"
      if dc exec -T "$HZ_SVC" php artisan parser:verify:community:verify-locate "$cid" --limit="$VERIFY_LIMIT" --save --overwrite --clear-on-aggregator; then
        okk=1
        break
      fi
      sleep "$SMOKE_POLL_SEC"
    done
    [[ "$okk" -eq 1 ]] || die "verify failed for community_id=$cid after 3 attempts"
  done
  echo
fi

if is_true "$ASSERTS"; then
  log "== 6.1) ASSERT: communities.city_id is filled =="
  dc exec -T "$HZ_SVC" php -r '
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
  echo
fi

if is_true "$EXTRACT"; then
  log "== 7) parser:events:extract (prompt_version=${PROMPT_VER}) =="
  dc exec -T -e LLM_EVENTS_PROMPT_VERSION="$PROMPT_VER" "$HZ_SVC" \
    php artisan parser:events:extract --limit="$EVENTS_EXTRACT_LIMIT"
  echo
fi

if is_true "$WAIT_LLM"; then
  wait_llm
  echo
fi

if is_true "$CONSUME"; then
  log "== 9) CONSUME llm_jobs(v=${PROMPT_VER}) -> events =="

  limit_sql=""
  if [[ "${CONSUME_LIMIT:-0}" =~ ^[0-9]+$ ]] && [[ "${CONSUME_LIMIT:-0}" -gt 0 ]]; then
    limit_sql="limit ${CONSUME_LIMIT}"
  fi

  LIDS="$(sql_ids "
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
    echo "-- consume [$k] llm_job_id=$lid --"
    if is_true "$CONSUME_SYNC"; then
      dc exec -T -e LID="$lid" "$HZ_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$id = (int) getenv("LID");
\Illuminate\Support\Facades\Bus::dispatchSync(new \App\Jobs\ConsumeLlmEventsJob($id, false));
echo "OK consumed {$id}\n";
'
    else
      dc exec -T -e LID="$lid" "$HZ_SVC" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$id = (int) getenv("LID");
\Illuminate\Support\Facades\Bus::dispatch(new \App\Jobs\ConsumeLlmEventsJob($id, false));
echo "OK enqueued consume {$id}\n";
'
    fi
  done
  echo
fi

# ✅ HQ-AUTOFIX stage (§13q): locate-by-name + promote-from-events +
# re-consume needs_geo posts + geo:backfill. Запускается ПОСЛЕ consume
# (нужны events для promote-from-events) и ДО groups (чтобы groups
# индексировали обновлённые events после re-consume).
if is_true "$HQ_AUTOFIX"; then
  log "== 9.4) HQ AUTOFIX (locate-by-name + promote + re-consume needs_geo + geo:backfill) =="
  PARSER_SVC="$(detect_parser_svc)"
  log "using PARSER_SVC=$PARSER_SVC"
  dc exec -T "$PARSER_SVC" php artisan parser:hq:autofix --quiet-subcommands
  echo
fi

# ✅ GROUPS stage: relink -> index -> prune -> check
if is_true "$GROUPS"; then
  log "== 9.5) GROUPS (relink/index/prune/check) =="

  PARSER_SVC="$(detect_parser_svc)"
  log "using PARSER_SVC=$PARSER_SVC"

  dc exec -T "$PARSER_SVC" php artisan events:groups:relink
  dc exec -T "$PARSER_SVC" php artisan events:groups:index
  dc exec -T "$PARSER_SVC" php artisan events:groups:prune
  dc exec -T "$PARSER_SVC" php artisan events:groups:check --show-mismatches --limit=50

  echo
fi

if is_true "$ASSERTS"; then
  log "== 9.1) ASSERT: events.city_id filled when city present =="
  dc exec -T "$HZ_SVC" php -r '
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
  echo
fi

log "== 10) SUMMARY =="
cat <<'SQL' | dc exec -T "$DB_SVC" sh -lc 'psql -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /dev/stdin'
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

ok "DONE."
