#!/bin/bash
set -e

cd "$(dirname "$0")/.."

if [ -f .last_deployed_commit ]; then
  echo "[rollback] Откат к коммиту $(cat .last_deployed_commit)"
  git checkout $(cat .last_deployed_commit)
  git submodule update --init --recursive
else
  echo "[rollback] Файл .last_deployed_commit не найден! Код не откатан!"
fi

docker compose -f docker-compose.yml -f docker-compose.prod.yml down

cp docker-compose.prod.yml docker-compose.prod.yml.rollback

for service in kudab-api kudab-nginx kudab-frontend kudab-parser; do
  sed -i "s|\(image:.*$service.*\):latest|\1:previous|g" docker-compose.prod.yml.rollback
done

docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback up -d

LATEST_DUMP=$(ls -1t backups/db_backup_*.sql 2>/dev/null | head -n 1)
if [ -f "$LATEST_DUMP" ]; then
  echo "[rollback] Чистим схему public перед восстановлением БД..."
  docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback exec -T kudab-db psql -U kudab kudab -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  echo "[rollback] Восстанавливаем БД из $LATEST_DUMP"
  docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback exec -T kudab-db psql -U kudab kudab < "$LATEST_DUMP"
  echo "[rollback] DB restored from $LATEST_DUMP"
else
  echo "[rollback] No DB backup found (skip DB restore)"
fi

rm docker-compose.prod.yml.rollback

echo "[rollback] Rollback complete"
