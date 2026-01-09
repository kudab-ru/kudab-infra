#!/usr/bin/env bash
set -euo pipefail

DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"

PROMPT_VER="${PROMPT_VER:-v5}"
VERIFY_LIMIT="${VERIFY_LIMIT:-20}"
EVENTS_EXTRACT_LIMIT="${EVENTS_EXTRACT_LIMIT:-5000}"
POSTS_MIN="${POSTS_MIN:-50}"

echo "== 0) Поднимаем dev окружение (БЕЗ build, чтобы не упасть на Docker Hub) =="
$DC up -d --remove-orphans

echo
echo "== 1) RESET: truncate tables + clear redis + horizon terminate =="
$DC exec -T kudab-horizon php artisan dev:reset --seed=0 --redis=1 --horizon=1

echo
echo "== 2) Ждём horizon healthy =="
cid="$($DC ps -q kudab-horizon)"
test -n "$cid" || (echo "ERROR: kudab-horizon container not found"; exit 2)

for i in $(seq 1 60); do
  st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid" 2>/dev/null || true)"
  echo "horizon=$st"
  echo "$st" | grep -Eq 'running (healthy|nohealth)' && break
  sleep 2
done

echo
echo "== 3) SEED =="
$DC exec -T kudab-api php artisan db:seed --force

echo
echo "== 4) ENQUEUE communities (через kudab-parser) =="
$DC exec -T kudab-parser php artisan parser:enqueue:communities

echo
echo "== 5) Ждём context_posts >= ${POSTS_MIN} =="
for i in $(seq 1 60); do
  c="$($DC exec -T kudab-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from context_posts;"')"
  echo "context_posts=$c"
  if [ "$c" -ge "$POSTS_MIN" ]; then break; fi
  sleep 2
done

echo
echo "== 6) VERIFY communities (3 попытки на каждое) =="
ids="$($DC exec -T kudab-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select id from communities order by id;"')"

n=0
for cid in $ids; do
  n=$((n+1))
  echo
  echo "-- verify [$n] community_id=$cid --"
  ok=0
  for a in 1 2 3; do
    echo "attempt=$a"
    if $DC exec -T kudab-horizon php artisan parser:verify:community:verify-locate "$cid" --limit="$VERIFY_LIMIT" --save --overwrite --clear-on-aggregator; then
      ok=1
      break
    fi
    sleep 2
  done
  if [ "$ok" -ne 1 ]; then
    echo "ERROR: verify failed for community_id=$cid after 3 attempts"
    exit 1
  fi
done

echo
echo "== 7) parser:events:extract (prompt_version=${PROMPT_VER}) =="
$DC exec -T -e LLM_EVENTS_PROMPT_VERSION="$PROMPT_VER" kudab-horizon \
  php artisan parser:events:extract --limit="$EVENTS_EXTRACT_LIMIT"

echo
echo "== 8) Ждём окончания llm_jobs(v=${PROMPT_VER}) =="
for i in $(seq 1 200); do
  row="$($DC exec -T kudab-db bash -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"
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
  if [ "${total:-0}" -gt 0 ] && [ "${pend:-999}" -eq 0 ]; then break; fi
  sleep 2
done

echo
echo "== 9) CONSUME синхронно: llm_jobs(v=${PROMPT_VER}) -> events =="
LIDS="$($DC exec -T kudab-db bash -lc "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Atc \"
select lj.id
from llm_jobs lj
left join events e
  on e.original_post_id = lj.context_post_id
 and e.deleted_at is null
where lj.task='events_extract'
  and lj.prompt_version='${PROMPT_VER}'
  and lj.status='completed'
  and e.id is null
order by lj.id;
\"")"

k=0
for lid in $LIDS; do
  k=$((k+1))
  echo "-- consume [$k] llm_job_id=$lid --"
  $DC exec -T -e LID="$lid" kudab-horizon php -r '
    require "vendor/autoload.php";
    $app = require "bootstrap/app.php";
    $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
    $id = (int) getenv("LID");
    \Illuminate\Support\Facades\Bus::dispatchSync(new \App\Jobs\ConsumeLlmEventsJob($id, false));
    echo "OK consumed {$id}\n";
  '
done

echo
echo "== 10) ИТОГ =="
cat <<'SQL' | $DC exec -T kudab-db bash -lc 'psql -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /dev/stdin'
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

select community_id, count(*) as cnt
from events
where deleted_at is null
group by 1
order by 1;
SQL

echo "DONE."
