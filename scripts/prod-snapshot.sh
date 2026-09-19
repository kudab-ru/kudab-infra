#!/usr/bin/env bash
# Снимок состояния прода. ТОЛЬКО ЧТЕНИЕ: ни одной команды, меняющей данные,
# контейнеры или файлы. Запускать на прод-хосте из каталога инфры.
#
#   cd <каталог инфры на сервере> && bash scripts/prod-snapshot.sh
#
# Вывод скопировать целиком и отдать сессии. Секретов не печатает: значения
# переменных окружения показываются как «есть/нет», кроме заведомо публичных.

set -u

DC="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
PSQL="docker exec kudab-db psql -U kudab kudab -tAc"

hr() { printf '\n=== %s ===\n' "$1"; }
try() { "$@" 2>&1 || echo "(не получилось — это тоже ответ)"; }

echo "СНИМОК ПРОДА $(date -Is)"
echo "хост: $(hostname), каталог: $(pwd)"

hr "1. Что реально выкачено"
try git rev-parse HEAD
try git submodule status

hr "2. Флаги в .env — есть или нет (значения не печатаем)"
for k in COMPASS_ENABLED FEDERATION_ENABLED VENUE_NAME_MATCH_ENABLED \
         VENUE_COLD_RESOLVE_ENABLED EVENT_MERGER_V2_ENABLED LLM_CROSS_DEDUP_ENABLED \
         LLM_PREFILTER_ENABLED LLM_CLASSIFY_ENABLED LLM_FOLLOWUP_LINK_ENABLED \
         LLM_EVENTS_PROMPT_VERSION BROADCAST_REVIEW_GATE_ENABLED NUXT_PUBLIC_HOME_V2; do
  v=$(grep -m1 "^${k}=" .env 2>/dev/null | cut -d= -f2-)
  printf '%-34s %s\n' "$k" "${v:-(нет в .env)}"
done

hr "3. Метрика доезжает до планировщика (спрашиваем контейнер, а не файл)"
try $DC exec -T kudab-api-scheduler printenv YANDEX_METRIKA_COUNTER
try $DC exec -T kudab-api printenv YANDEX_METRIKA_COUNTER

hr "4. Яндекс.Афиша: сколько прогонов в сутки (гипотеза двойного обхода)"
try $PSQL "select date_trunc('day', started_at)::date d, count(*) runs
           from source_runs where source_slug='yandex_afisha'
           group by 1 order by 1 desc limit 7;"

hr "5. Прогоны всех источников за сутки"
try $PSQL "select source_slug, count(*) runs, sum(coalesce(urls_total,0)) urls
           from source_runs where started_at > now() - interval '24 hours'
           group by 1 order by 2 desc;"

hr "6. События без координат и по статусам"
try $PSQL "select status, count(*) from events where deleted_at is null group by 1 order by 2 desc;"
try $PSQL "select count(*) from events where status='needs_geo' and deleted_at is null;"

hr "7. Очередь дублей"
try $PSQL "select count(*) total,
                  count(*) filter (where merged_at is null) pending,
                  min(created_at)::date oldest
           from event_duplicate_links;"

hr "8. Расход LLM за 30 дней"
try $PSQL "select date, sum(calls) calls, round(sum(cost_usd)::numeric,4) usd
           from llm_usage_daily where date > current_date - 30
           group by 1 order by 1 desc limit 10;"
try $PSQL "select count(*) filter (where status='failed') failed,
                  count(*) filter (where status='queued') queued
           from llm_jobs where created_at > now() - interval '30 days';"

hr "9. Настройки каналов рассылки (ключи, не содержимое постов)"
try $PSQL "select id, telegram_chat_id, enabled, city_id,
                  settings ? 'feed_limit'  as has_feed_limit,
                  settings ? 'slots'       as has_slots,
                  settings ? 'digest_weekday' as has_digest,
                  telegram_user_id is not null as has_owner
           from telegram.chat_broadcasts order by id;"
try $PSQL "select count(*) from telegram.chat_broadcast_items where publish_at is null and status='open';"

hr "10. Лаг: анонс появился у источника → мы его увидели"
try $PSQL "select percentile_disc(0.5) within group (order by extract(epoch from (created_at - published_at))/3600) as median_hours
           from context_posts where published_at > now() - interval '7 days' and published_at is not null;"

hr "11. Контейнеры живы"
try $DC ps --format 'table {{.Name}}\t{{.Status}}'

hr "12. Размер последнего бэкапа (перед любой выкаткой смотреть глазами)"
try ls -lh backups/ 2>/dev/null | tail -5

echo
echo "СНИМОК ОКОНЧЕН. Ничего не изменено."
