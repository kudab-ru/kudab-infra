#!/usr/bin/env bash
# Базовые образы сборки — до сборки и с повтором. Docker Hub временами по нескольку минут не выдаёт
# токен («TLS handshake timeout» на auth.docker.io), и `up --build` падает целиком. Образ, который уже
# лежит на сервере, не скачивается: сборка идёт без --pull и берёт его, не выходя в сеть.
set -uo pipefail
cd "$(dirname "$0")/.."

# Dockerfile каждого сервиса, который собирает compose
dirs=$(grep -hoE '(build|context):[[:space:]]*\./services/[A-Za-z0-9_-]+' docker-compose.yml docker-compose.prod.yml \
  | grep -oE '\./services/[A-Za-z0-9_-]+' | sort -u)

images=$(for d in $dirs; do
  f="$d/Dockerfile"
  [ -f "$f" ] || continue
  # имена стадий («AS build») — не образы, их отбрасываем
  stages=$(grep -ioE '^FROM[[:space:]]+[^[:space:]]+[[:space:]]+AS[[:space:]]+[^[:space:]]+' "$f" | awk '{print tolower($NF)}')
  grep -ioE '^FROM[[:space:]]+[^[:space:]]+|COPY[[:space:]]+--from=[^[:space:]]+' "$f" \
    | sed -E 's/^FROM[[:space:]]+//I; s/^COPY[[:space:]]+--from=//I' \
    | while read -r ref; do
        printf '%s\n' "$stages" | grep -qx "$(printf '%s' "$ref" | tr '[:upper:]' '[:lower:]')" || printf '%s\n' "$ref"
      done
done | sort -u)

failed=0
for img in $images; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    continue
  fi
  ok=0
  for pause in 10 20 40 60 90 0; do
    if docker pull -q "$img" >/dev/null 2>&1; then
      echo "   базовый образ скачан: $img"
      ok=1
      break
    fi
    [ "$pause" -gt 0 ] && { echo "   $img не скачался, повтор через ${pause} с"; sleep "$pause"; }
  done
  [ "$ok" = 1 ] || { echo "❌ $img не скачался за ~4 минуты: Docker Hub недоступен, выкат стоит повторить позже"; failed=1; }
done

exit "$failed"
