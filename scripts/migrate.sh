#!/bin/bash
set -e

docker-compose exec -T kudab-api php artisan migrate --force
docker-compose exec -T kudab-parser php artisan migrate --force
