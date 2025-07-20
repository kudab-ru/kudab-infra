#!/bin/bash
set -e

cd "$(dirname "$0")/.." # Запускать из корня проекта

# 1. Останавливаем все сервисы
docker compose -f docker-compose.yml -f docker-compose.prod.yml down

# 2. Формируем временный override-файл с тегами :previous
cp docker-compose.prod.yml docker-compose.prod.yml.rollback

services=$(docker compose -f docker-compose.yml -f docker-compose.prod.yml config --services)
for service in $services; do
  # Заменяем :latest на :previous только для текущего сервиса (если есть в файле)
  sed -i "s|\(image:.*$service.*\):latest|\1:previous|g" docker-compose.prod.yml.rollback
done

# 3. Поднимаем всё из rollback-override
docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback up -d

# 4. Восстанавливаем БД из последнего бэкапа (опционально)
LATEST_DUMP=$(ls -1t backups/db_backup_*.sql 2>/dev/null | head -n 1)
if [ -f "$LATEST_DUMP" ]; then
  docker compose -f docker-compose.yml -f docker-compose.prod.yml.rollback exec -T kudab-db psql -U kudab kudab < "$LATEST_DUMP"
  echo "DB restored from $LATEST_DUMP"
else
  echo "No DB backup found (skip DB restore)"
fi

# 5. Убираем временный файл
rm docker-compose.prod.yml.rollback

echo "[rollback] Rollback complete"