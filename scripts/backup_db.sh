#!/bin/bash
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p backups
docker-compose exec -T kudab-db pg_dump -U kudab kudab > backups/db_backup_$TIMESTAMP.sql

# Удаляем все, кроме 5 последних дампов
ls -1t backups/db_backup_*.sql | tail -n +6 | xargs -r rm --