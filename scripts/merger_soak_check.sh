#!/usr/bin/env bash
# EventMerger Phase 2 24h-soak check.
# Запускается через `at` 2026-06-05 06:00 UTC (= 09:00 MSK).
# Pin a9a48aa, EVENT_MERGER_V2_ENABLED=1 включён 2026-06-04.
# Зелёный критерий: fallback=0 AND race_retry=0 AND legacy_used=0.

set -uo pipefail

INFRA=/var/www/kudab-infra
LOG=$INFRA/storage/merger-soak.log
BOT_ENV=$INFRA/services/kudab-bot/.env
TS_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
COMPOSE=(docker compose -f "$INFRA/docker-compose.yml" -f "$INFRA/docker-compose.prod.yml")

cd "$INFRA"

COUNTERS=$("${COMPOSE[@]}" exec -T kudab-horizon php artisan parser:merger:counters --days=1 2>&1)
EXEC_RC=$?

TOTAL_LINE=$(printf '%s\n' "$COUNTERS" | grep -m1 'ИТОГО' || true)

if [[ -z "$TOTAL_LINE" ]] || [[ $EXEC_RC -ne 0 ]]; then
    STATUS="⚠️ FAIL — не удалось снять counters (rc=$EXEC_RC). Проверь horizon контейнер."
    INSERT="-" ; CONFLICT="-" ; RACE="-" ; FALLBACK="-" ; LEGACY="-"
else
    INSERT=$(printf '%s\n' "$TOTAL_LINE" | awk -F'|' '{gsub(/ /,"",$3); print $3}')
    CONFLICT=$(printf '%s\n' "$TOTAL_LINE" | awk -F'|' '{gsub(/ /,"",$4); print $4}')
    RACE=$(printf '%s\n'    "$TOTAL_LINE" | awk -F'|' '{gsub(/ /,"",$5); print $5}')
    FALLBACK=$(printf '%s\n' "$TOTAL_LINE" | awk -F'|' '{gsub(/ /,"",$6); print $6}')
    LEGACY=$(printf '%s\n'  "$TOTAL_LINE" | awk -F'|' '{gsub(/ /,"",$7); print $7}')

    if [[ "$FALLBACK" == "0" && "$RACE" == "0" && "$LEGACY" == "0" ]]; then
        STATUS="✅ CLEAN — soak пройден, можно включать VENUE_NAME_MATCH_ENABLED=1 (Шаг 3)."
    else
        STATUS="❌ DIRTY — fallback=$FALLBACK race_retry=$RACE legacy_used=$LEGACY. НЕ переходить на Шаг 3, копать или откатить EVENT_MERGER_V2_ENABLED=0."
    fi
fi

MSG="🔬 kudab EventMerger soak [$TS_UTC]
$STATUS

insert=$INSERT conflict=$CONFLICT race_retry=$RACE fallback=$FALLBACK legacy_used=$LEGACY

Full log: $LOG"

set +u
# shellcheck disable=SC1090
source <(grep -E '^(BOT_TOKEN|ADMIN_CHAT_ID)=' "$BOT_ENV")
set -u

TG_RESP=""
if [[ -n "${BOT_TOKEN:-}" ]] && [[ -n "${ADMIN_CHAT_ID:-}" ]]; then
    TG_RESP=$(curl -sS --max-time 15 \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$ADMIN_CHAT_ID" \
        --data-urlencode "text=$MSG" 2>&1 || echo "TG_CURL_FAIL")
fi

{
    echo "============================================================"
    echo "[$TS_UTC] EventMerger soak check"
    echo "$COUNTERS"
    echo "---"
    echo "$STATUS"
    echo "Telegram: $TG_RESP"
    echo ""
} >> "$LOG"
