#!/bin/bash
docker-compose exec kudab-api php artisan migrate --force
docker-compose exec kudab-parser php artisan migrate --force