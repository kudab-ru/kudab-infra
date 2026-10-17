#!/usr/bin/env bash
# Копия базы прода на стенд без новых вызовов модели. Прежняя база стенда остаётся как `kudab_prev`,
# `--rollback` возвращает её. Запуск — цели `stand-pull-prod` и `stand-db-rollback` в Makefile.
set -euo pipefail
cd "$(dirname "$0")/../.."

DOCKER="${DOCKER:-docker}"
if ! command -v "$DOCKER" >/dev/null 2>&1 && [ -x /Docker/host/bin/docker.exe ]; then
  DOCKER=/Docker/host/bin/docker.exe # в WSL `docker` иногда пропадает, а `docker.exe` из Windows работает
fi
DB_CONTAINER="${DB_CONTAINER:-kudab-db}"
DB="${DB_NAME:-kudab}"
PROD_DIR="${PROD_DIR:-/var/www/kudab-infra}"

# строки этих таблиц стенду не нужны: очереди, кэш (в нём окно модели), сессии и входы админов, журнал ошибок
SKIP_DATA=(cache cache_locks jobs job_batches failed_jobs sessions personal_access_tokens error_logs)

pg() { "$DOCKER" exec -i "$DB_CONTAINER" psql -U kudab -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

swap() { # $1 — какая база станет рабочей, $2 — куда убрать нынешнюю
  pg <<SQL
ALTER DATABASE $DB WITH ALLOW_CONNECTIONS false;
SELECT count(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE datname = '$DB' AND pid <> pg_backend_pid();
SELECT pg_sleep(1);
DROP DATABASE IF EXISTS $2;
ALTER DATABASE $DB RENAME TO $2;
ALTER DATABASE $1 RENAME TO $DB;
ALTER DATABASE $DB WITH ALLOW_CONNECTIONS true;
SQL
}

after_swap() {
  echo "Довожу схему и сбрасываю кэши…"
  "$DOCKER" exec kudab-api php artisan migrate --force
  "$DOCKER" exec kudab-api php artisan cache:clear
  "$DOCKER" exec kudab-parser php artisan cache:clear
  "$DOCKER" restart kudab-horizon >/dev/null
}

if [ "${1:-}" = "--rollback" ]; then
  exists=$(pg -At -c "SELECT 1 FROM pg_database WHERE datname = '${DB}_prev'")
  [ "$exists" = "1" ] || { echo "Прежней базы ${DB}_prev нет — откатывать нечего"; exit 1; }
  pg -c "ALTER DATABASE ${DB}_prev WITH ALLOW_CONNECTIONS true"
  swap "${DB}_prev" "${DB}_rolled_back"
  pg -c "DROP DATABASE IF EXISTS ${DB}_rolled_back"
  after_swap
  echo "Стенд снова на прежней базе."
  exit 0
fi

DUMP="${DUMP:-}"
if [ -z "$DUMP" ]; then
  PROD_SSH="${PROD_SSH:-$(grep -E '^PROD_SSH=' .env 2>/dev/null | cut -d= -f2- || true)}"
  [ -n "$PROD_SSH" ] || { echo "Нужен PROD_SSH=user@host (или строка PROD_SSH= в .env), либо DUMP=файл"; exit 1; }
  mkdir -p backups
  DUMP="backups/prod_$(date +%Y-%m-%d_%H-%M).dump"
  excl=""
  for t in "${SKIP_DATA[@]}"; do excl="$excl --exclude-table-data=$t"; done
  echo "Снимаю дамп прода ($PROD_SSH)…"
  ssh "$PROD_SSH" "cd $PROD_DIR && docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T kudab-db pg_dump -U kudab -Fc$excl kudab" > "$DUMP"
fi
[ -s "$DUMP" ] || { echo "Дамп пустой или не найден: $DUMP"; exit 1; }
echo "Дамп: $DUMP ($(du -h "$DUMP" | cut -f1))"

if [ "${YES:-0}" != "1" ]; then
  read -r -p "База стенда заменится копией прода, прежняя останется как ${DB}_prev. Продолжить? [y/N] " ans
  case "$ans" in y|Y|д|Д) ;; *) echo "Отменено"; exit 1 ;; esac
fi

echo "Разворачиваю дамп во временную базу (рабочая пока не тронута)…"
pg -c "DROP DATABASE IF EXISTS ${DB}_restore" -c "CREATE DATABASE ${DB}_restore"
if ! "$DOCKER" exec -i "$DB_CONTAINER" pg_restore -U kudab -d "${DB}_restore" --no-owner --no-privileges < "$DUMP"; then
  echo "pg_restore сообщил об ошибках — рабочая база не тронута, временную ${DB}_restore можно осмотреть"
  exit 1
fi

echo "Меняю базы местами…"
swap "${DB}_restore" "${DB}_prev"
pg -c "ALTER DATABASE ${DB}_prev WITH ALLOW_CONNECTIONS true"
after_swap

"$DOCKER" exec -i "$DB_CONTAINER" psql -U kudab -d "$DB" -At -c "
  SELECT 'событий впереди: ' || count(*) FROM events WHERE deleted_at IS NULL AND start_date >= current_date
  UNION ALL SELECT 'последний пост: ' || coalesce(max(published_at)::text, '—') FROM context_posts"
echo "Готово. Вернуть прежнюю базу: make stand-db-rollback"
