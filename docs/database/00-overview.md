# Описание структуры базы данных KUDAB — обзор (2025)

Этот файл — “карта” базы данных: что за что отвечает, как идут данные, и куда смотреть при проблемах.

Источник истины по структуре/индексам/констрейнтам: `schema.sql`.

## Где что описано

- `database/10-public-domain.md` — доменные таблицы схемы `public` (города, сообщества, посты, события, интересы, пользователи).
- `database/20-public-technical.md` — технические таблицы схемы `public` (парсинг-статусы, error logs, LLM jobs, очереди/кэш Laravel, роли/права и т.п.).
- `database/30-telegram.md` — таблицы схемы `telegram` (привязка чатов, настройки рассылки, очередь отправок, шаблоны).
- `database/db-schema.md` — оглавление/указатель (если используется в репе).

---

## 1) Какие есть схемы

### `public`
Домен проекта: города, сообщества и источники, сырые посты, события, интересы, пользователи.  
Тут же лежит часть инфраструктуры Laravel (очереди, кэш, сессии, роли/права) — она описана отдельно в `20-public-technical.md`.

### `telegram`
Telegram-слой: Telegram-пользователи, чаты/каналы, настройки рассылки, очередь отправок, шаблоны сообщений.

### PostGIS
В проекте используются геоданные (точки):
- `public.cities.location` — точка города
- `public.events.location` — точка события

---

## 2) Главные сущности (по смыслу)

Костяк системы:

**Город → Сообщество → Соцссылка → Пост → Событие → Рассылка в TG**

Где это в таблицах:
- Город: `public.cities`
- Сообщество: `public.communities`
- Источник/ссылка: `public.community_social_links` + справочник `public.social_networks`
- Сырые посты: `public.context_posts` (+ `public.attachments`)
- События: `public.events` (+ `public.event_sources`)
- Интересы: `public.interests` (+ пивоты)
- Telegram-рассылки: `telegram.chats`, `telegram.chat_broadcasts`, `telegram.chat_broadcast_items`, `telegram.message_templates`

---

## 3) Потоки данных

### A) От источника до события
1) Создаём сообщество: `communities`
2) Привязываем источники: `community_social_links` (+ `social_networks`)
3) Проверяем ссылку: история в `social_link_verifications`, сводка в `community_social_links.last_*`
4) Парсим: статусы/фризы в `parsing_statuses`
5) Сохраняем сырые посты: `context_posts` (+ `attachments`)
6) (Опционально) LLM: `llm_jobs`
7) Создаём событие: `events` (часто `original_post_id` указывает на пост)
8) Фиксируем источники события: `event_sources`

### B) От события до Telegram-рассылки
1) Пользователь TG: `telegram.users` (может быть привязка к `public.users`)
2) Чат/канал: `telegram.chats` (+ выбранный `city_id` для подбора событий)
3) Настройки рассылки: `telegram.chat_broadcasts` (`enabled` + `settings`)
4) Очередь/история отправок: `telegram.chat_broadcast_items` (status/ошибки)
5) Шаблоны сообщений: `telegram.message_templates`

---

## 4) Важные правила (инварианты)

- `events` имеет **soft delete** (`deleted_at`), и `dedup_key` уникален только для активных записей (где `deleted_at IS NULL`).
- `context_posts` защищён от дублей по `(source, external_id, social_link_id)` (когда `social_link_id` задан).
- `community_social_links` — **одна запись на одну соцсеть в рамках сообщества** (UNIQUE `community_id + social_network_id`).
- `parsing_statuses` — **1 запись на 1 ссылку** (UNIQUE `community_social_link_id`).
- `telegram.chat_broadcasts` — **1 запись на 1 чат** (UNIQUE `chat_id`).
- `telegram.chat_broadcast_items` — **одно событие один раз на одну рассылку** (UNIQUE `broadcast_id + event_id`).

---

## 5) Куда смотреть, если что-то сломалось

- Источник не парсится / частые ошибки: `public.parsing_statuses`
- Верификация ссылок: `public.social_link_verifications` и поля `community_social_links.last_*`
- События не извлеклись / извлеклись странно: `public.llm_jobs`
- Рассылка не ушла: `telegram.chat_broadcast_items` (status + `error_message`)
- Общие инциденты: `public.error_logs`
