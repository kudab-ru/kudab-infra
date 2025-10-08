## Описание структуры базы данных KUDAB (2025)

Архитектура БД рассчитана на масштабируемое хранение событий, пользователей, сообществ, интересов и универсального контента с поддержкой гибкой фильтрации, гео-запросов (PostGIS) и интеграции с соцсетями. Структура нормализована (3НФ), индексы оптимизированы под основные запросы.

---

## Основные сущности и связи

### USERS

| Поле              | Тип         | Описание                      |
|-------------------|-------------|-------------------------------|
| id                | bigserial   | PRIMARY KEY                   |
| name              | varchar     | Имя пользователя              |
| email             | varchar     | Email (уникальный)            |
| password          | varchar     | Пароль (hash)                 |
| avatar_url        | varchar     | Ссылка на аватар              |
| bio               | text        | О себе                        |
| email_verified_at | timestamp   | Время подтверждения email     |
| remember_token    | varchar     | Токен для восстановления      |
| created_at        | timestamp   |                               |
| updated_at        | timestamp   |                               |
| deleted_at        | timestamp   | Soft delete                   |

#### telegram_users

| Поле               | Тип        | Описание                  |
|--------------------|------------|---------------------------|
| id                 | bigserial  | PRIMARY KEY               |
| user_id            | bigint     | FK → users.id (nullable)  |
| telegram_id        | bigint     | Telegram user ID (unique) |
| telegram_username  | varchar    | username Telegram         |
| first_name         | varchar    | Имя Telegram              |
| last_name          | varchar    | Фамилия Telegram          |
| language_code      | varchar    | Язык                      |
| chat_id            | bigint     | ID чата                   |
| is_bot             | boolean    | Бот?                      |
| registered_at      | timestamp  | Первое посещение          |
| last_active        | timestamp  | Последняя активность      |
| created_at         | timestamp  |                           |
| updated_at         | timestamp  |                           |

---

### INTERESTS

| Поле      | Тип       | Описание                        |
|-----------|-----------|---------------------------------|
| id        | bigserial | PRIMARY KEY                     |
| name      | varchar   | Название интереса               |
| parent_id | bigint    | FK → interests.id (nullable)    |
| is_paid   | boolean   | Платный интерес                 |
| created_at| timestamp |                                 |
| updated_at| timestamp |                                 |

#### interest_user

| Поле        | Тип      | Описание                     |
|-------------|----------|------------------------------|
| user_id     | bigint   | FK → users.id                |
| interest_id | bigint   | FK → interests.id            |
| created_at  | timestamp|                              |
| updated_at  | timestamp|                              |
**PRIMARY KEY (user_id, interest_id)**

#### interest_relations

| Поле               | Тип       | Описание                    |
|--------------------|-----------|-----------------------------|
| id                 | bigserial | PRIMARY KEY                 |
| parent_interest_id | bigint    | FK → interests.id           |
| child_interest_id  | bigint    | FK → interests.id           |
| created_at         | timestamp |                             |
| updated_at         | timestamp |                             |

---

### COMMUNITIES

| Поле                 | Тип       | Описание                                   |
|----------------------|-----------|--------------------------------------------|
| id                   | bigserial | PRIMARY KEY                                |
| name                 | varchar   | Название                                   |
| description          | text      | Описание                                   |
| city                 | varchar   | Город                                      |
| street               | varchar   | Улица                                      |
| house                | varchar   | Дом/корпус                                 |
| avatar_url           | varchar   | Ссылка на аватар                           |
| image_url            | varchar   | Доп. изображение/постер                    |
| last_checked_at      | timestamp | Время последней проверки                   |
| verification_status  | varchar   | pending/completed/failed                   |
| is_verified          | boolean   | Верифицировано                             |
| **verification_meta**| **jsonb** | Сводка верификации (per-link + final)      |
| created_at           | timestamp |                                            |
| updated_at           | timestamp |                                            |

#### community_social_links

| Поле                      | Тип        | Описание                                      |
|---------------------------|------------|-----------------------------------------------|
| id                        | bigserial  | PRIMARY KEY                                   |
| community_id              | bigint     | FK → communities.id                           |
| social_network_id         | bigint     | FK → social_networks.id                       |
| external_community_id     | varchar    | ID/slug в соцсети                             |
| url                       | varchar    | Ссылка на профиль                             |
| created_at                | timestamp  |                                               |
| updated_at                | timestamp  |                                               |
| **last_verification_id**  | bigint     | FK → social_link_verifications.id (nullable)  |
| **last_checked_at**       | timestamp  | Последняя удачная проверка                    |
| **last_is_active**        | boolean    | Итог активности по ссылке                     |
| **last_has_events**       | boolean    | Есть «мероприятные» посты по ссылке           |
| **last_kind**             | varchar    | aggregator/venue_host/org                     |
| **last_hq_city**          | varchar    | Город HQ, по этой ссылке                      |
| **last_hq_street**        | varchar    | Улица HQ                                      |
| **last_hq_house**         | varchar    | Дом HQ                                        |
| **last_hq_confidence**    | numeric(3,2) | Уверенность HQ (0..1)                       |

Индексы (рекомендуется):
```sql
CREATE INDEX IF NOT EXISTS idx_csl_comm ON community_social_links (community_id);
CREATE INDEX IF NOT EXISTS idx_csl_last_checked_at ON community_social_links (last_checked_at DESC);
```

#### community_interest

| Поле        | Тип      | Описание                |
|-------------|----------|-------------------------|
| community_id| bigint   | FK → communities.id     |
| interest_id | bigint   | FK → interests.id       |
| created_at  | timestamp|                         |
| updated_at  | timestamp|                         |
**PRIMARY KEY (community_id, interest_id)**

#### social_networks

| Поле      | Тип       | Описание                         |
|-----------|-----------|----------------------------------|
| id        | bigserial | PRIMARY KEY                      |
| name      | varchar   | VK / Telegram / Афиша/Сайт и т.п.|
| slug      | varchar   | vk / telegram / site             |
| icon      | varchar   | emoji или URL                    |
| url_mask  | varchar   | Шаблон генерации ссылок          |
| created_at| timestamp |                                  |
| updated_at| timestamp |                                  |

---

### VERIFICATION (новое)

#### social_link_verifications — **история верификаций по каждой ссылке**

| Поле                     | Тип           | Описание                                              |
|--------------------------|---------------|-------------------------------------------------------|
| id                       | bigserial     | PRIMARY KEY                                           |
| community_id             | bigint        | FK → communities.id                                   |
| community_social_link_id | bigint        | FK → community_social_links.id                        |
| social_network_id        | bigint        | FK → social_networks.id                               |
| status                   | varchar       | **ok / error / skipped**                              |
| checked_at               | timestamp     | Момент проверки                                       |
| latency_ms               | integer       | Время ответа LLM/API                                  |
| model                    | varchar       | Модель LLM                                            |
| prompt_version           | integer       | Версия промпта                                        |
| is_active                | boolean       | Активность                                            |
| has_events_posts         | boolean       | Есть «мероприятные» посты                             |
| activity_score           | numeric(3,2)  | 0..1                                                  |
| events_score             | numeric(3,2)  | 0..1                                                  |
| kind                     | varchar       | aggregator / venue_host / org                         |
| has_fixed_place          | boolean       | Есть собственная площадка                             |
| hq_city                  | varchar       | Город HQ                                              |
| hq_street                | varchar       | Улица HQ                                              |
| hq_house                 | varchar       | Дом HQ                                                |
| hq_confidence            | numeric(3,2)  | Уверенность HQ (0..1)                                 |
| examples                 | jsonb         | Примеры найденных «мероприятий»                       |
| events_locations         | jsonb         | Извлечённые адреса мероприятий                        |
| raw                      | jsonb         | Полный ответ/сырой снэпшот                            |
| error_code               | varchar       | Код ошибки (если есть)                                |
| error_message            | text          | Текст ошибки (если есть)                              |
| created_at               | timestamp     |                                                       |
| updated_at               | timestamp     |                                                       |

Ограничения/индексы:
```sql
ALTER TABLE social_link_verifications
  ADD CONSTRAINT chk_activity_score CHECK (activity_score IS NULL OR (activity_score >= 0 AND activity_score <= 1)),
  ADD CONSTRAINT chk_events_score   CHECK (events_score   IS NULL OR (events_score   >= 0 AND events_score   <= 1));

CREATE INDEX IF NOT EXISTS idx_slv_comm      ON social_link_verifications (community_id);
CREATE INDEX IF NOT EXISTS idx_slv_link      ON social_link_verifications (community_social_link_id);
CREATE INDEX IF NOT EXISTS idx_slv_checked   ON social_link_verifications (checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_slv_status    ON social_link_verifications (status);
```

#### error_logs (технические логи)

| Поле        | Тип       | Описание                                    |
|-------------|-----------|---------------------------------------------|
| id          | bigserial | PRIMARY KEY                                 |
| type        | varchar   | Короткий код типа ошибки                    |
| community_id| bigint    | FK → communities.id (nullable)              |
| link_id     | bigint    | FK → community_social_links.id (nullable)   |
| job         | varchar   | Имя задания                                 |
| error_text  | text      | Описание ошибки                             |
| error_code  | varchar   | Код/HTTP                                    |
| created_at  | timestamp |                                             |

Индексы: `(community_id)`, `(link_id)`, `(created_at)`.

#### parsing_statuses (заморозки/баны источников)

| Поле          | Тип       | Описание                          |
|---------------|-----------|-----------------------------------|
| id            | bigserial | PRIMARY KEY                       |
| link_id       | bigint    | FK → community_social_links.id    |
| status        | varchar   | active/frozen                     |
| reason        | varchar   | Причина                           |
| frozen_until  | timestamp | До какого времени заморожен       |
| meta          | jsonb     | Доп. данные                       |
| created_at    | timestamp |                                   |
| updated_at    | timestamp |                                   |

Индексы: `(link_id)`, `(status)`, `(frozen_until)`.

---

### EVENTS

| Поле            | Тип          | Описание                                  |
|-----------------|--------------|-------------------------------------------|
| id              | bigserial    | PRIMARY KEY                               |
| original_post_id| bigint       | FK → context_posts.id (nullable)          |
| community_id    | bigint       | FK → communities.id                       |
| title           | varchar      | Название события                          |
| start_time      | timestamp    | Начало                                    |
| end_time        | timestamp    | Окончание                                 |
| location        | geometry     | Point(4326), PostGIS                      |
| latitude        | decimal(9,6) | STORED, ST_Y(location)                    |
| longitude       | decimal(9,6) | STORED, ST_X(location)                    |
| city            | varchar      | Город                                     |
| address         | varchar      | Адрес                                     |
| description     | text         | Описание                                  |
| status          | varchar      | active, canceled, draft и др.             |
| external_url    | varchar      | Ссылка на источник                        |
| created_at      | timestamp    |                                           |
| updated_at      | timestamp    |                                           |
| deleted_at      | timestamp    | Soft delete                               |

Spatial index:
```sql
CREATE INDEX IF NOT EXISTS events_location_gix ON events USING GIST (location);
```

#### event_interest

| Поле        | Тип       | Описание                  |
|-------------|-----------|---------------------------|
| event_id    | bigint    | FK → events.id            |
| interest_id | bigint    | FK → interests.id         |
| created_at  | timestamp |                           |
**PRIMARY KEY (event_id, interest_id)**

#### event_attendees

| Поле      | Тип       | Описание                                   |
|-----------|-----------|--------------------------------------------|
| event_id  | bigint    | FK → events.id                             |
| user_id   | bigint    | FK → users.id                              |
| status    | varchar   | going, interested, rejected и др.          |
| joined_at | timestamp | Когда присоединился                        |
| created_at| timestamp |                                            |
| updated_at| timestamp |                                            |
**PRIMARY KEY (event_id, user_id)**

---

### CONTENT & PARSING

#### context_posts

| Поле         | Тип        | Описание                                 |
|--------------|------------|------------------------------------------|
| id           | bigserial  | PRIMARY KEY                              |
| external_id  | varchar    | ID исходного поста VK/TG/сайта           |
| source       | varchar    | vk, tg, site и др.                       |
| author_id    | bigint     | ID автора (user/community/external)      |
| author_type  | varchar    | user, community, external                |
| community_id | bigint     | FK → communities.id (nullable)           |
| title        | varchar    | Заголовок                                |
| text         | text       | Основной текст                           |
| published_at | timestamp  | Дата публикации                          |
| status       | varchar    | active, flagged, hidden и др.            |
| created_at   | timestamp  |                                          |
| updated_at   | timestamp  |                                          |

#### attachments

| Поле        | Тип       | Описание                                  |
|-------------|-----------|-------------------------------------------|
| id          | bigserial | PRIMARY KEY                               |
| parent_type | varchar   | context_post, event и др.                 |
| parent_id   | bigint    | ID объекта                                |
| type        | varchar   | image, video, file и др.                  |
| url         | varchar   | Ссылка на файл                            |
| preview_url | varchar   | Превью                                    |
| order       | integer   | Порядок                                   |
| created_at  | timestamp |                                           |
| updated_at  | timestamp |                                           |
**MorphTo: parent_type, parent_id**

#### interest_links

| Поле        | Тип       | Описание                                  |
|-------------|-----------|-------------------------------------------|
| parent_type | varchar   | context_post, event и др.                 |
| parent_id   | bigint    | ID объекта                                |
| interest_id | bigint    | FK → interests.id                         |
| created_at  | timestamp |                                           |
| updated_at  | timestamp |                                           |
**PRIMARY KEY (parent_type, parent_id, interest_id)**

#### context_interactions

| Поле      | Тип       | Описание                                     |
|-----------|-----------|-----------------------------------------------|
| id        | bigserial | PRIMARY KEY                                   |
| post_id   | bigint    | FK → context_posts.id                         |
| user_id   | bigint    | FK → users.id                                 |
| type      | varchar   | request, response, flag, comment и др.        |
| status    | varchar   | active, reviewed, flagged и др.               |
| message   | text      | Текст комментария/запроса/жалобы              |
| reason    | varchar   | Причина/категория (если применимо)            |
| created_at| timestamp |                                               |
| updated_at| timestamp |                                               |

---

## Telegram Layer

### telegram_chats

Карточка чата.

| Поле                       | Тип                                                                      |
| -------------------------- | ------------------------------------------------------------------------ |
| id PK                      | bigint                                                                   |
| tg_chat_id                 | bigint UNIQUE                                                            |
| type                       | varchar(20) CHECK in (private,group,supergroup,channel)                  |
| title/username/invite_link | varchar                                                                  |
| is_member                  | boolean DEFAULT true NOT NULL                                            |
| timezone                   | varchar                                                                  |
| left_at/last_activity_at   | timestamp                                                                |
| link_status                | varchar(16) CHECK in (linked,unlinked,kicked,unknown) DEFAULT 'unlinked' |
| linked_at/unlinked_at      | timestamptz                                                              |
| created_at/updated_at      | timestamp                                                                |

Индексы: по `link_status`.

### telegram_users

Телеграм-пользователи (связь на `users` опционально). Поля: `telegram_id UNIQUE`, `telegram_username`, `first/last_name`, метки времени.

### telegram_chat_members

Состав чатов: PK `(chat_id, user_id)`, `role` CHECK (creator/admin/member/left/kicked), `joined_at/left_at`.

### tg_message_templates

Шаблоны сообщений: `name UNIQUE`, `locale (default ru)`, `body_markdown`, `show_images/max_images`.

### tg_broadcast_rules

Правила рассылки на чат.

| Поле                  | Тип                                                                   |                                        |
| --------------------- | --------------------------------------------------------------------- | -------------------------------------- |
| id PK                 | bigint                                                                |                                        |
| chat_id               | bigint FK→telegram_chats NOT NULL                                     |                                        |
| enabled               | boolean DEFAULT true NOT NULL                                         |                                        |
| cities                | jsonb DEFAULT '[]' NOT NULL                                           |                                        |
| interest_slugs        | jsonb DEFAULT '[]'                                                    |                                        |
| window_hours          | int DEFAULT 72 NOT NULL                                               |                                        |
| not_before/not_after  | timestamptz                                                           | окна активности                        |
| interval_minutes      | int DEFAULT 15 NOT NULL                                               |                                        |
| burst_limit           | int DEFAULT 1 NOT NULL                                                |                                        |
| dedup_window_days     | int DEFAULT 7 NOT NULL                                                |                                        |
| update_mode           | varchar(10) CHECK in (edit,resend,skip) DEFAULT 'edit' NOT NULL       |                                        |
| template_mode         | varchar(10) CHECK in (static,rotate,random) DEFAULT 'static' NOT NULL |                                        |
| template_id           | bigint FK→tg_message_templates NOT NULL                               |                                        |
| template_ids          | json                                                                  | список альтернатив (для rotate/random) |
| created_by_user_id    | bigint FK→telegram_users SET NULL                                     |                                        |
| created_at/updated_at | timestamp                                                             |                                        |

Уникальность: `UNIQUE(chat_id) WHERE enabled = true` (одна активная rule на чат).

### tg_broadcast_state

Состояние планировщика по rule (PK=rule_id). Поля: `enabled`, **last_run_at/last_sent_at/cursor_start_time (timestamp → рекоменд. timestamptz)**, `backlog_count`, `next_template_idx`.

### tg_outbox

Очередь отправок в Telegram.

| Поле                  | Тип                                                                                      |                                     |
| --------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------- |
| id PK                 | bigint                                                                                   |                                     |
| rule_id               | bigint FK→tg_broadcast_rules NOT NULL                                                    |                                     |
| chat_id               | bigint FK→telegram_chats NOT NULL                                                        |                                     |
| event_id              | bigint FK→events NOT NULL                                                                |                                     |
| scheduled_at          | timestamp (**реком. timestamptz**)                                                       |                                     |
| status                | varchar(20) CHECK in (pending,sent,failed,skipped_dup,edited) DEFAULT 'pending' NOT NULL |                                     |
| attempts              | int DEFAULT 0 NOT NULL                                                                   |                                     |
| last_error            | text                                                                                     |                                     |
| message_id            | bigint                                                                                   |                                     |
| payload_hash          | varchar(64) NOT NULL                                                                     |                                     |
| sent_at               | timestamp                                                                                |                                     |
| template_id           | bigint FK→tg_message_templates                                                           | (nullable сейчас; см. рекомендации) |
| created_at/updated_at | timestamp                                                                                |                                     |

Индексы: `(status, scheduled_at)`, `(chat_id, scheduled_at)`, `(rule_id, status)`.

Дедуп: `UNIQUE(chat_id, event_id) WHERE status='pending'`.

### tg_event_deliveries

Факты доставок.

| Поле                       | Тип                                   |   |
| -------------------------- | ------------------------------------- | - |
| chat_id,event_id           | bigint PK                             |   |
| rule_id                    | bigint FK→tg_broadcast_rules SET NULL |   |
| dedup_key                  | varchar(255)                          |   |
| first_sent_at/last_sent_at | timestamp (**реком. timestamptz**)    |   |
| message_id                 | bigint                                |   |
| content_hash               | varchar(64)                           |   |

Индекс: `(chat_id, dedup_key)`.

### tg_user_sessions

Короткоживущие сессии.

| Поле                  | Тип                                      |
| --------------------- | ---------------------------------------- |
| id PK                 | bigint                                   |
| user_id               | bigint FK→telegram_users UNIQUE NOT NULL |
| selected_chat_id      | bigint FK→telegram_chats SET NULL        |
| selected_label        | varchar(255)                             |
| expires_at            | timestamptz                              |
| created_at/updated_at | timestamp                                |

Индекс: `expires_at`.

---

## Особенности и best practices

- Все PK — `bigserial`, связи через FK, где важно — `ON DELETE CASCADE/SET NULL`.
- Junction-таблицы с составными PK.
- Soft delete (`deleted_at`) для ключевых сущностей.
- Универсальные связи через MorphTo (attachments, interest_links).
- Гео — PostGIS + GIST индексы.
- Верификация:
    - История — `social_link_verifications`.
    - Снэпшот по ссылке — `community_social_links.last_*`.
    - Итог по сообществу и объяснение — `communities.verification_meta`.
    - Скоринги храним в 0..1 (CHECK-ограничения).
    - Неподдержанные источники маркируем `status='skipped'` (без обновления snapshot).
- Все временные поля стандартизированы: `*_at`.

---

## Примеры запросов

```sql
-- Найти события в радиусе 3 км
SELECT * FROM events
WHERE ST_DWithin(location, ST_MakePoint(37.620393,55.75396)::geography, 3000);

-- Интересы пользователя
SELECT i.* FROM interests i
JOIN interest_user iu ON iu.interest_id = i.id
WHERE iu.user_id = :user_id;

-- Вложения к событию
SELECT * FROM attachments
WHERE parent_type = 'event' AND parent_id = :event_id;

-- Сводка статусов верификаций за час
SELECT status, COUNT(*) 
FROM social_link_verifications
WHERE checked_at > now() - interval '1 hour'
GROUP BY status;

-- Итог по конкретному сообществу (с pretty JSON)
SELECT id, is_verified, verification_status, city, street, house, last_checked_at,
       jsonb_pretty(verification_meta) AS meta
FROM communities
WHERE id = :community_id;
```