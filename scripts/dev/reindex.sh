#!/usr/bin/env bash
set -euo pipefail

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

STACK="${STACK:-dev}" # dev|prod

if [[ "$STACK" != "dev" && "$STACK" != "prod" ]]; then
  echo "[err] STACK must be dev|prod (got: $STACK)" >&2
  exit 2
fi

# Compose command (can be overridden from Makefile by passing DC="docker compose ...")
DC_STR="${DC:-}"
if [[ -z "$DC_STR" ]]; then
  if [[ "$STACK" == "prod" ]]; then
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
  else
    DC_STR="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
  fi
fi

# Parse DC_STR into array safely
read -r -a DC_ARR <<<"$DC_STR"
dc() { "${DC_ARR[@]}" "$@"; }

# Tunables
PROMPT_VER="${PROMPT_VER:-v8}"
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
fi

CONSUME_LIMIT="${CONSUME_LIMIT:-0}" # 0 = all

# Safety gate for prod destructive actions
CONFIRM_PROD="${CONFIRM_PROD:-0}"
if [[ "$STACK" == "prod" ]]; then
  if [[ "$RESET" == "1" || "$SEED" == "1" || "$ENQUEUE" == "1" ]]; then
    if [[ "$CONFIRM_PROD" != "1" ]]; then
      echo "[err] PROD safety: RESET/SEED/ENQUEUE requested, but CONFIRM_PROD=1 is not set." >&2
      echo "      Refusing to run destructive steps on prod." >&2
      exit 2
    fi
  fi
fi

echo "== REINDEX =="
echo "STACK=$STACK"
echo "DC=$DC_STR"
echo "PROMPT_VER=$PROMPT_VER"
echo "FLAGS: UP=$UP UP_BUILD=$UP_BUILD MIGRATE=$MIGRATE RESET=$RESET SEED=$SEED ENQUEUE=$ENQUEUE VERIFY=$VERIFY ASSERTS=$ASSERTS EXTRACT=$EXTRACT WAIT_LLM=$WAIT_LLM CONSUME=$CONSUME CONSUME_SYNC=$CONSUME_SYNC CONSUME_LIMIT=$CONSUME_LIMIT"
echo

if [[ "$UP" == "1" ]]; then
  echo "== 0) docker compose up =="
  if [[ "$UP_BUILD" == "1" ]]; then
    dc up -d --remove-orphans --build
  else
    dc up -d --remove-orphans
  fi
  echo
fi

if [[ "$MIGRATE" == "1" ]]; then
  echo "== 0.5) MIGRATE (kudab-api) =="
  dc exec -T kudab-api php artisan migrate --force
  echo
fi

if [[ "$RESET" == "1" ]]; then
  echo "== 1) RESET (truncate/redis/horizon terminate) =="
  dc exec -T kudab-horizon php artisan dev:reset --seed=0 --redis=1 --horizon=1
  echo
fi

if [[ "$RESTART_HORIZON" == "1" ]]; then
  echo "== 1.1) restart horizon =="
  dc restart kudab-horizon
  echo
fi

echo "== 2) wait horizon healthy =="
cid="$(dc ps -q kudab-horizon || true)"
test -n "${cid:-}" || (echo "[err] kudab-horizon container not found"; exit 2)

for i in $(seq 1 "$HZ_ATTEMPTS"); do
  st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid" 2>/dev/null || true)"
  echo "horizon=$st"
  echo "$st" | grep -Eq 'running (healthy|nohealth)' && break
  sleep "$SMOKE_POLL_SEC"
done
echo

if [[ "$SEED" == "1" ]]; then
  echo "== 3) SEED =="
  dc exec -T kudab-api php artisan db:seed --force
  echo
fi

if [[ "$ENQUEUE" == "1" ]]; then
  echo "== 4) ENQUEUE communities =="
  # Prefer kudab-parser if it's running, else fallback to kudab-horizon (same image/cli in your stack)
  PARSER_SVC="${PARSER_SVC:-}"
  if [[ -z "$PARSER_SVC" ]]; then
    if [[ -n "$(dc ps -q kudab-parser 2>/dev/null || true)" ]]; then
      PARSER_SVC="kudab-parser"
    else
      PARSER_SVC="kudab-horizon"
    fi
  fi
  echo "using PARSER_SVC=$PARSER_SVC"
  dc exec -T "$PARSER_SVC" php artisan parser:enqueue:communities
  echo

  echo "== 5) wait context_posts >= ${POSTS_MIN} =="
  for i in $(seq 1 "$POSTS_ATTEMPTS"); do
    c="$(dc exec -T kudab-db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from context_posts;"')"
    echo "context_posts=$c"
    if [[ "${c:-0}" -ge "$POSTS_MIN" ]]; then break; fi
    sleep "$SMOKE_POLL_SEC"
  done
  echo
fi

if [[ "$VERIFY" == "1" ]]; then
  echo "== 6) VERIFY communities (3 attempts each) =="
  ids="$(dc exec -T kudab-db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select id from communities order by id;"')"
  n=0
  for cid in $ids; do
    n=$((n+1))
    echo
    echo "-- verify [$n] community_id=$cid --"
    ok=0
    for a in 1 2 3; do
      echo "attempt=$a"
      if dc exec -T kudab-horizon php artisan parser:verify:community:verify-locate "$cid" --limit="$VERIFY_LIMIT" --save --overwrite --clear-on-aggregator; then
        ok=1
        break
      fi
      sleep "$SMOKE_POLL_SEC"
    done
    if [[ "$ok" -ne 1 ]]; then
      echo "[err] verify failed for community_id=$cid after 3 attempts" >&2
      exit 1
    fi
  done
  echo
fi

if [[ "$ASSERTS" == "1" ]]; then
  echo "== 6.1) ASSERT: communities.city_id is filled =="
  dc exec -T kudab-horizon php -r '
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

if [[ "$EXTRACT" == "1" ]]; then
  echo "== 7) parser:events:extract (prompt_version=${PROMPT_VER}) =="
  dc exec -T -e LLM_EVENTS_PROMPT_VERSION="$PROMPT_VER" kudab-horizon \
    php artisan parser:events:extract --limit="$EVENTS_EXTRACT_LIMIT"
  echo
fi

if [[ "$WAIT_LLM" == "1" ]]; then
  echo "== 8) wait llm_jobs done (v=${PROMPT_VER}) =="
  for i in $(seq 1 "$LLM_ATTEMPTS"); do
    row="$(dc exec -T kudab-db sh -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"
select
  count(*) as total,
  count(*) filter (where status in ('pending','processing')) as pend,
  count(*) filter (where status='completed') as done,
  count(*) filter (where status='failed') as failed
from llm_jobs
where task='events_extract' and prompt_version='${PROMPT_VER}';
\"")"
    echo "llm_jobs => $row"
    pend="$(echo "$row" | awk -F'|' '{print $2}')"
    total="$(echo "$row" | awk -F'|' '{print $1}')"
    if [[ "${total:-0}" -gt 0 && "${pend:-999}" -eq 0 ]]; then break; fi
    sleep "$SMOKE_POLL_SEC"
  done
  echo
fi

if [[ "$CONSUME" == "1" ]]; then
  echo "== 9) CONSUME llm_jobs(v=${PROMPT_VER}) -> events =="
  LIDS="$(dc exec -T kudab-db sh -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"
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
${CONSUME_LIMIT:+limit ${CONSUME_LIMIT}};
\"")"

  k=0
  for lid in $LIDS; do
    k=$((k+1))
    echo "-- consume [$k] llm_job_id=$lid --"
    if [[ "$CONSUME_SYNC" == "1" ]]; then
      dc exec -T -e LID="$lid" kudab-horizon php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$id = (int) getenv("LID");
\Illuminate\Support\Facades\Bus::dispatchSync(new \App\Jobs\ConsumeLlmEventsJob($id, false));
echo "OK consumed {$id}\n";
'
    else
      dc exec -T -e LID="$lid" kudab-horizon php -r '
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

if [[ "$ASSERTS" == "1" ]]; then
  echo "== 9.1) ASSERT: events.city_id filled when city present =="
  dc exec -T kudab-horizon php -r '
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

echo "== 10) SUMMARY =="
cat <<'SQL' | dc exec -T kudab-db sh -lc 'psql -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /dev/stdin'
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

echo "DONE."
