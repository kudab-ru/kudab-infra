#!/bin/bash
set -e

cd "$(dirname "$0")/.." # Переход в корень проекта

# 1. Откатить git-репозиторий к предыдущему рабочему коммиту (если файл есть)
if [ -f .last_deployed_commit ]; then
  echo "[rollback] Откат к коммиту $(cat .last_deployed_commit)"
  git checkout $(cat .last_deployed_commit)
  git submodule update --init --recursive
else
  echo "[rollback] Файл .last_deployed_commit не найден! Код не откатан!"
fi

# 2. Остановить все сервисы
docker compose -f docker-compose.yml -f docker-compose.prod.yml down

# 3. Формируем временный override-файл с тегами :previous
cp docker-compose.prod.yml docker-compose.prod.yml.rollback

services=$(docker compose -f docker-compose.yml -f docker-compose.prod.yml config --services)
for service in $services; do
  # Заменяем :latest на :previous только для текущего сервиса (если есть в файле)
  sed -i "s|\(image:.*$service.*\):latest|\1:previous|g" docker-compose.prod.yml.rollback
done

# 4. Поднимаем всё из rollback-override
docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback up -d

# 5. Восстанавливаем БД из последнего бэкапа (очищая схему перед этим)
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

# 6. Убираем временный файл override
rm docker-compose.prod.yml.rollback

echo "[rollback] Rollback complete"
