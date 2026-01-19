#!/usr/bin/env bash
set -euo pipefail

DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"

POST_ID="${POST_ID:-}"
if [[ -z "$POST_ID" ]]; then
  echo "ERROR: POST_ID is required"
  echo "Usage: POST_ID=45 bash scripts/dev/smoke_post.sh"
  exit 2
fi
if ! [[ "$POST_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: POST_ID must be numeric"
  exit 2
fi

# PROMPT_VER: берём из env, иначе из .env, иначе v5
PROMPT_VER="${PROMPT_VER:-}"
if [[ -z "$PROMPT_VER" && -f ".env" ]]; then
  PROMPT_VER="$(sed -n 's/^LLM_EVENTS_PROMPT_VERSION=//p' .env 2>/dev/null | head -n 1 | tr -d '\r' | xargs || true)"
fi
PROMPT_VER="${PROMPT_VER:-v5}"

CLEAN="${CLEAN:-1}"
RESET_LLM="${RESET_LLM:-1}"
NO_GEO="${NO_GEO:-0}"

POLL_SEC="${POLL_SEC:-2}"
HZ_ATTEMPTS="${HZ_ATTEMPTS:-60}"
LLM_ATTEMPTS="${LLM_ATTEMPTS:-120}"

BENCH_FILE="llm/bench/smoke_post_${POST_ID}.json"

echo "== DEV smoke by one post =="
echo "POST_ID=$POST_ID"
echo "PROMPT_VER=$PROMPT_VER"
echo "CLEAN=$CLEAN RESET_LLM=$RESET_LLM NO_GEO=$NO_GEO"
echo "BENCH_FILE=$BENCH_FILE"
echo

echo "== 0) Up dev env (no build) =="
$DC up -d --remove-orphans

echo
echo "== 1) Wait horizon healthy =="
cid="$($DC ps -q kudab-horizon)"
test -n "$cid" || (echo "ERROR: kudab-horizon container not found"; exit 2)

st=""
for i in $(seq 1 "$HZ_ATTEMPTS"); do
  st="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid" 2>/dev/null || true)"
  echo "horizon=$st"
  echo "$st" | grep -Eq 'running (healthy|nohealth)' && break
  sleep "$POLL_SEC"
done
echo "$st" | grep -Eq 'running (healthy|nohealth)' || (echo "ERROR: horizon not healthy in time"; exit 2)

echo
echo "== 2) Check post exists (context_posts.id=$POST_ID) =="
exists="$(
  $DC exec -T kudab-db sh -lc \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select 1 from context_posts where id = '"$POST_ID"' limit 1;"'
)"
if [[ "$exists" != "1" ]]; then
  echo "ERROR: context_post not found: id=$POST_ID"
  echo "Tip: check available posts:"
  $DC exec -T kudab-db sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -P pager=off -c "
select id, status, published_at, left(text, 70) as text_head
from context_posts
order by id desc
limit 10;
"'
  exit 2
fi

if [[ "$CLEAN" == "1" ]]; then
  echo
  echo "== 3) Optional CLEAN derived data by this post =="
  cat <<'SQL' | $DC exec -T kudab-db sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -P pager=off -v post_id="'"$POST_ID"'" -f /dev/stdin'
delete from event_interest
where event_id in (
  select id from events
  where deleted_at is null and original_post_id = :post_id
);

delete from event_sources
where context_post_id = :post_id
   or event_id in (
     select id from events
     where deleted_at is null and original_post_id = :post_id
   );

update events
set deleted_at = now(), updated_at = now()
where deleted_at is null and original_post_id = :post_id;
SQL
  echo "OK: cleaned events/event_sources/event_interest for post_id=$POST_ID"
fi

if [[ "$RESET_LLM" == "1" ]]; then
  echo
  echo "== 4) Optional RESET LLM jobs for this post+version =="
  cat <<'SQL' | $DC exec -T kudab-db sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -P pager=off -v post_id="'"$POST_ID"'" -v prompt_ver="'"$PROMPT_VER"'" -f /dev/stdin'
delete from llm_jobs
where task = 'events_extract'
  and context_post_id = :post_id
  and prompt_version = :'prompt_ver';
SQL
  echo "OK: reset llm_jobs for post_id=$POST_ID version=$PROMPT_VER"
fi

echo
echo "== 5) Write bench file with single post id =="
# ВАЖНО:
# 1) формат: {"ids":[POST_ID]} чтобы llm:bench:run точно увидел ids
# 2) пишем в ДВА места: storage/app/<file> и ./<file> — чтобы не зависеть от реализации llm:bench:run
$DC exec -T -e POST_ID="$POST_ID" -e BENCH_FILE="$BENCH_FILE" kudab-horizon php -r '
$p = (int)getenv("POST_ID");
$rel = getenv("BENCH_FILE");
$payload = ["ids" => [$p]];

$paths = [
  "storage/app/".$rel,
  $rel,
];

foreach ($paths as $f) {
  @mkdir(dirname($f), 0777, true);
  file_put_contents($f, json_encode($payload, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
  echo "WROTE {$f}\n";
}

echo "DONE\n";
'

$DC exec -T kudab-horizon php -r '
$rel = "'"$BENCH_FILE"'";
$paths = ["storage/app/".$rel, $rel];
foreach ($paths as $f) {
  $j = json_decode(@file_get_contents($f), true);
  $n = is_array($j) ? count($j["ids"] ?? []) : 0;
  echo "bench_ids[$f]=$n\n";
}
'

echo
echo "== 6) Run LLM bench for this one post (version=$PROMPT_VER) =="
$DC exec -T kudab-horizon php artisan llm:bench:run "$PROMPT_VER" --file="$BENCH_FILE" --reset=0

echo
echo "== 7) Wait llm_jobs finished (post=$POST_ID, version=$PROMPT_VER) =="
for i in $(seq 1 "$LLM_ATTEMPTS"); do
  row="$(
    $DC exec -T kudab-db sh -lc \
    'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "
select
  count(*) as total,
  count(*) filter (where status in ('\''pending'\'','\''processing'\'')) as pend,
  count(*) filter (where status='\''completed'\'') as done,
  count(*) filter (where status='\''failed'\'') as failed
from llm_jobs
where task='\''events_extract'\''
  and context_post_id='"$POST_ID"'
  and prompt_version='\'''"$PROMPT_VER"''\'';
"'
  )"
  echo "llm_jobs => $row"
  pend="$(echo "$row" | awk -F'|' '{print $2}')"
  total="$(echo "$row" | awk -F'|' '{print $1}')"

  if [[ "${pend:-0}" -eq 0 ]]; then
    if [[ "${total:-0}" -eq 0 ]]; then
      echo "WARN: llm_jobs total=0 (nothing to wait)"
    fi
    break
  fi

  sleep "$POLL_SEC"
done

echo
echo "== 8) CONSUME (sync) llm_jobs -> events for this post =="
LIDS="$(
  $DC exec -T kudab-db sh -lc \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "
select lj.id
from llm_jobs lj
left join events e
  on e.original_post_id = lj.context_post_id
 and e.deleted_at is null
where lj.task='\''events_extract'\''
  and lj.context_post_id='"$POST_ID"'
  and lj.prompt_version='\'''"$PROMPT_VER"''\''
  and lj.status='\''completed'\''
  and e.id is null
order by lj.id;
"'
)"
if [[ -z "$LIDS" ]]; then
  echo "WARN: no completed llm_jobs found for post_id=$POST_ID version=$PROMPT_VER (or already consumed)"
else
  k=0
  for lid in $LIDS; do
    k=$((k+1))
    echo "-- consume [$k] llm_job_id=$lid --"
    $DC exec -T -e QUEUE_CONNECTION=sync -e LID="$lid" -e NO_GEO="$NO_GEO" kudab-horizon php -r '
      require "vendor/autoload.php";
      $app = require "bootstrap/app.php";
      $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

      $id = (int)getenv("LID");
      $noGeo = ((int)getenv("NO_GEO") === 1);

      \Illuminate\Support\Facades\Bus::dispatchSync(new \App\Jobs\ConsumeLlmEventsJob($id, $noGeo));
      echo "OK consumed {$id} (no_geo=".($noGeo?1:0).")\n";
    '
  done
fi

echo
echo "== 9) SUMMARY for post_id=$POST_ID =="
cat <<'SQL' | $DC exec -T kudab-db sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -P pager=off -v post_id="'"$POST_ID"'" -v prompt_ver="'"$PROMPT_VER"'" -f /dev/stdin'
select id, status, published_at
from context_posts
where id = :post_id;

select status, count(*) as cnt
from llm_jobs
where task='events_extract'
  and context_post_id = :post_id
  and prompt_version = :'prompt_ver'
group by 1
order by 1;

select id, time_precision, start_date, start_time, status, title
from events
where deleted_at is null and original_post_id = :post_id
order by coalesce(start_time, (start_date::timestamp)) asc, id asc;

select count(*) as events_total
from events
where deleted_at is null and original_post_id = :post_id;
SQL

echo
echo "DONE."
