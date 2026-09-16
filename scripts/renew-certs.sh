#!/bin/bash
set -euo pipefail

cd /var/www/kudab-infra

# Лог пишем в storage/ (gitignored, владелец maks). НЕ в /var/log — туда у maks
# нет прав, и cron-редирект падал ДО запуска скрипта, из-за чего продление
# молча не работало и сертификаты протухли (сентябрь 2026).
LOG=/var/www/kudab-infra/storage/cert-renew.log
exec >>"$LOG" 2>&1

echo "=== $(date -u '+%Y-%m-%d %H:%M:%S UTC') renew start ==="

docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  run --rm certbot renew --quiet

# -T обязателен: в cron нет TTY, без него docker compose exec падает.
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  exec -T kudab-nginx nginx -s reload

# Самопроверка: сколько дней реально осталось у боевых сертификатов.
# Смотрим снаружи, по живому TLS — так видно именно то, что отдаёт nginx.
for host in kudab.ru admin.kudab.ru; do
  end=$(echo | timeout 15 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2) || end=""
  if [ -z "$end" ]; then
    echo "WARN $host: не удалось прочитать сертификат"
    continue
  fi
  left=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
  if [ "$left" -lt 15 ]; then
    echo "WARN $host: осталось $left дн. (до $end) — продление не сработало!"
  else
    echo "ok   $host: осталось $left дн. (до $end)"
  fi
done

echo "=== $(date -u '+%Y-%m-%d %H:%M:%S UTC') renew done ==="
