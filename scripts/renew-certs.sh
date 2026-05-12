#!/bin/bash
set -euo pipefail

cd /var/www/kudab-infra

docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  run --rm certbot renew --quiet

docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  exec kudab-nginx nginx -s reload
