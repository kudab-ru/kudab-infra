#!/bin/bash

# Пример переменных (подставь свои значения или экспортируй их из .env)
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-kudab}
DB_PASS=${DB_PASS:-kudab}
DB_NAME=${DB_NAME:-kudab}

echo "Enabling PostGIS extension in $DB_NAME..."

PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

echo "PostGIS enabled (or already present)."
