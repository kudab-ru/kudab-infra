# Описание структуры базы данных KUDAB — домен (схема `public`, 2025)

Схема `public` хранит доменные данные: города, сообщества/источники, сырые посты, события, интересы, пользователей.

Служебные таблицы (очереди Laravel, кэш, права, статусы парсинга, логи ошибок, LLM jobs) вынесены в `database/20-public-technical.md`.  
Telegram-таблицы находятся в схеме `telegram` и описаны в `database/30-telegram.md`.

---

## Группы таблиц (домен)

- Пользователи: `users`
- Города и площадки: `cities`, `communities`, `social_networks`, `community_social_links`, `community_interest`, `social_link_verifications`
- Контент: `context_posts`, `attachments`, `context_interactions`
- События и участие: `events`, `event_sources`, `event_attendees`, `event_interest`
- Интересы: `interests`, `interest_aliases`, `interest_relations`, `interest_user`, `interest_links`

Дальше — кратко и по делу по каждой сущности.

---

## 1. Пользователи

### `users`

Основная учётная запись приложения (не Telegram).

Важно:
- email уникален.
- soft delete: `deleted_at`.

| Поле              | Тип                                      | Описание                     |
|-------------------|------------------------------------------|------------------------------|
| id                | bigint, PK                               | Идентификатор пользователя   |
| name              | varchar(255) NOT NULL                    | Имя                          |
| email             | varchar(255) NOT NULL, UNIQUE            | Email                        |
| email_verified_at | timestamp(0)                             | Подтверждение email          |
| password          | varchar(255) NOT NULL                    | Хэш пароля                   |
| remember_token    | varchar(100)                             | Токен “запомнить меня”       |
| avatar_url        | varchar(255)                             | URL аватара                  |
| bio               | text                                     | О себе                       |
| deleted_at        | timestamp(0)                             | Soft delete                  |
| created_at        | timestamp(0)                             |                              |
| updated_at        | timestamp(0)                             |                              |

---

## 2. Города и площадки

### `cities`

Города с геоточкой (PostGIS). Используются для фильтрации/карты и для нормализации `city_id` в сущностях.

Важно:
- `location` — точка (Point,4326).
- `latitude/longitude` — GENERATED.
- `slug` уникален (nullable, но если задан — должен быть уникальным).
- `(country_code, name_ci)` уникальны.

| Поле        | Тип                                      | Описание                         |
|-------------|------------------------------------------|----------------------------------|
| id          | bigint, PK                               |                                  |
| name        | varchar(255) NOT NULL                    | Название города                  |
| slug        | varchar(64), UNIQUE                      | Слаг города                      |
| country_code| varchar(2)                               | ISO-код страны                   |
| location    | geometry(Point, 4326) NOT NULL           | Точка центра                     |
| latitude    | numeric(9,6), GENERATED                  | ST_Y(location)                   |
| longitude   | numeric(9,6), GENERATED                  | ST_X(location)                   |
| status      | varchar(16) DEFAULT 'active' NOT NULL    | Статус записи                    |
| name_ci     | text, GENERATED                          | lower(name)                      |
| created_at  | timestamp(0)                             |                                  |
| updated_at  | timestamp(0)                             |                                  |

---

### `communities`

Сообщества / площадки (источник событий). Может быть “организатором”, “площадкой”, “агрегатором”.

Важно:
- `city` — город строкой (сырьё/наследие).
- `city_id` — нормализованный город (FK → `cities.id`, ON DELETE SET NULL).
- `verification_*` — состояние верификации.

| Поле               | Тип                                        | Описание                                      |
|--------------------|--------------------------------------------|-----------------------------------------------|
| id                 | bigint, PK                                 |                                               |
| name               | varchar(255) NOT NULL                      | Название                                      |
| description        | text                                       | Описание                                      |
| city               | varchar(255)                               | Город (строкой)                               |
| street             | varchar(255)                               | Улица                                         |
| house              | varchar(255)                               | Дом                                           |
| avatar_url         | varchar(255)                               | Аватар                                        |
| image_url          | varchar(255)                               | Доп. картинка / постер                        |
| last_checked_at    | timestamp(0)                               | Последняя проверка (парсинг/валидность)       |
| verification_status| varchar(255) DEFAULT 'pending'             | pending/approved/rejected (и др. статусы)     |
| is_verified        | boolean DEFAULT false NOT NULL             | Флаг “верифицировано”                         |
| verification_meta  | jsonb                                      | Сводка/мета проверки                           |
| city_id            | bigint, FK → cities.id (ON DELETE SET NULL)| Нормализованный город                         |
| created_at         | timestamp(0)                               |                                               |
| updated_at         | timestamp(0)                               |                                               |

---

### `social_networks`

Справочник соцсетей / типов источников (VK, Telegram, сайт и т.п.).

| Поле      | Тип               | Описание              |
|-----------|-------------------|-----------------------|
| id        | bigint, PK        |                       |
| name      | varchar(64) NOT NULL | Название           |
| slug      | varchar(32) NOT NULL | Код (vk/telegram/…)|
| icon      | varchar(255)      | Иконка (UI)           |
| url_mask  | varchar(255)      | Маска ссылок (UI)     |
| created_at| timestamp(0)      |                       |
| updated_at| timestamp(0)      |                       |

---

### `community_social_links`

Ссылки сообществ в соцсетях (одна ссылка на одну соцсеть в рамках сообщества).

Важно:
- UNIQUE (community_id, social_network_id).
- `last_*` — “последний результат проверки” для быстрых списков.

| Поле                  | Тип                                                | Описание                              |
|-----------------------|----------------------------------------------------|---------------------------------------|
| id                    | bigint, PK                                         |                                       |
| community_id          | bigint NOT NULL, FK → communities.id (CASCADE)     | Сообщество                            |
| social_network_id     | bigint NOT NULL, FK → social_networks.id (CASCADE) | Соцсеть                               |
| external_community_id | varchar(128)                                       | ID/slug в соцсети                     |
| url                   | varchar(512) NOT NULL                              | Полный URL                            |
| last_verification_id  | bigint, FK → social_link_verifications.id (SET NULL) | Последняя проверка (история)       |
| last_checked_at       | timestamp(0)                                       | Когда проверяли                       |
| last_is_active        | boolean                                            | Активна ли ссылка                     |
| last_has_events       | boolean                                            | Есть ли посты с событиями             |
| last_kind             | varchar(16)                                        | aggregator / venue_host / org         |
| last_hq_city          | varchar(255)                                       | HQ-город по ссылке                    |
| last_hq_street        | varchar(255)                                       | HQ-улица                              |
| last_hq_house         | varchar(255)                                       | HQ-дом                                |
| last_hq_confidence    | numeric(3,2)                                       | Уверенность HQ (0..1)                 |
| created_at            | timestamp(0)                                       |                                       |
| updated_at            | timestamp(0)                                       |                                       |

---

### `community_interest`

Сообщества ↔ интересы.

PK составной: (community_id, interest_id).

| Поле         | Тип                                      | Описание        |
|--------------|------------------------------------------|-----------------|
| community_id | bigint NOT NULL, FK → communities.id (CASCADE) | Сообщество |
| interest_id  | bigint NOT NULL, FK → interests.id (CASCADE)   | Интерес    |
| created_at   | timestamp(0)                             |                 |
| updated_at   | timestamp(0)                             |                 |

---

### `social_link_verifications`

История проверок соц-ссылок (обычно LLM). Это “лог” по каждой проверке.

Важно:
- `checked_at` по умолчанию CURRENT_TIMESTAMP.
- FK на community / link / social_network.

| Поле                    | Тип                                                | Описание                      |
|-------------------------|----------------------------------------------------|-------------------------------|
| id                      | bigint, PK                                         |                               |
| community_id            | bigint NOT NULL, FK → communities.id (CASCADE)     |                               |
| community_social_link_id| bigint NOT NULL, FK → community_social_links.id (CASCADE) |                           |
| social_network_id       | bigint NOT NULL, FK → social_networks.id (CASCADE) |                               |
| checked_at              | timestamp(0) DEFAULT CURRENT_TIMESTAMP NOT NULL    | Время проверки                |
| status                  | varchar(16) DEFAULT 'ok' NOT NULL                  | ok / error / skipped …        |
| latency_ms              | integer                                            | Время ответа                  |
| model                   | varchar(64)                                        | Модель LLM                    |
| prompt_version          | integer DEFAULT 1 NOT NULL                         | Версия промпта                |
| error_code              | varchar(64)                                        | Код ошибки                    |
| error_message           | text                                               | Текст ошибки                  |
| is_active               | boolean                                            | Активность                    |
| has_events_posts        | boolean                                            | Есть ли посты с событиями     |
| activity_score          | numeric(3,2)                                       | 0..1                          |
| events_score            | numeric(3,2)                                       | 0..1                          |
| kind                    | varchar(16)                                        | Тип источника                 |
| has_fixed_place         | boolean                                            | Есть ли “своя площадка”       |
| hq_city                 | varchar(255)                                       | HQ-город                      |
| hq_street               | varchar(255)                                       | HQ-улица                      |
| hq_house                | varchar(255)                                       | HQ-дом                        |
| hq_confidence           | numeric(3,2)                                       | Уверенность HQ                |
| examples                | jsonb                                              | Примеры постов                |
| events_locations        | jsonb                                              | Извлечённые адреса            |
| raw                     | jsonb                                              | Полный сырой ответ            |
| created_at              | timestamp(0)                                       |                               |
| updated_at              | timestamp(0)                                       |                               |

---

## 3. Контент

### `context_posts`

Сырые посты (VK/TG/сайты). Это вход для извлечения событий.

Важно:
- soft delete: `deleted_at`.
- защита от дублей: UNIQUE (source, external_id, social_link_id) WHERE social_link_id IS NOT NULL.
- FK: `community_id` и `social_link_id` (оба SET NULL).

| Поле         | Тип                                                     | Описание                         |
|--------------|----------------------------------------------------------|----------------------------------|
| id           | bigint, PK                                               |                                  |
| external_id  | varchar(255)                                             | ID поста в источнике             |
| source       | varchar(255)                                             | vk / tg / site и т.п.            |
| external_url | text                                                     | URL исходного поста              |
| author_id    | bigint                                                   | Полиморфный автор (если используем) |
| author_type  | varchar(255)                                             | user / community / external      |
| community_id | bigint, FK → communities.id (ON DELETE SET NULL)         | Сообщество (если есть)           |
| social_link_id| bigint, FK → community_social_links.id (ON DELETE SET NULL) | Конкретная ссылка-источник   |
| title        | varchar(255)                                             | Заголовок                        |
| text         | text                                                     | Текст                            |
| published_at | timestamp(0)                                             | Время публикации                 |
| status       | varchar(255) DEFAULT 'active' NOT NULL                   | Статус                           |
| deleted_at   | timestamp(0)                                             | Soft delete                      |
| created_at   | timestamp(0)                                             |                                  |
| updated_at   | timestamp(0)                                             |                                  |

---

### `attachments`

Вложения к постам/событиям (полиморфно через parent_type/parent_id).

Важно:
- UNIQUE (parent_type, parent_id, type, url) WHERE url IS NOT NULL.

| Поле       | Тип                                | Описание                                     |
|------------|------------------------------------|----------------------------------------------|
| id         | bigint, PK                         |                                              |
| parent_type| varchar(255) NOT NULL              | Тип родителя (context_post, event, …)        |
| parent_id  | bigint NOT NULL                    | ID родителя                                  |
| type       | varchar(255) NOT NULL              | image / video / file / …                     |
| url        | text NOT NULL                      | URL файла                                     |
| preview_url| varchar(255)                       | Превью                                        |
| order      | integer DEFAULT 0 NOT NULL         | Порядок                                       |
| created_at | timestamp(0)                       |                                              |
| updated_at | timestamp(0)                       |                                              |

---

### `context_interactions`

Взаимодействия пользователей с контентом (флаг/коммент/запрос и т.п.).

| Поле      | Тип                                         | Описание                    |
|-----------|---------------------------------------------|-----------------------------|
| id        | bigint, PK                                  |                             |
| post_id   | bigint NOT NULL, FK → context_posts.id (CASCADE) |                         |
| user_id   | bigint NOT NULL, FK → users.id (CASCADE)    |                             |
| type      | varchar(255) NOT NULL                       | request / flag / comment…   |
| status    | varchar(255)                                | Статус обработки            |
| message   | text                                        | Текст                       |
| reason    | varchar(255)                                | Причина/категория           |
| created_at| timestamp(0)                                |                             |
| updated_at| timestamp(0)                                |                             |

---

## 4. Интересы

### `interests`

Справочник интересов (дерево).

| Поле      | Тип                        | Описание                      |
|-----------|----------------------------|-------------------------------|
| id        | bigint, PK                 |                               |
| name      | varchar(255) NOT NULL      | Название интереса             |
| slug      | varchar(64) NOT NULL       | Код/слаг                      |
| parent_id | bigint, FK → interests.id  | Родитель (дерево), nullable   |
| created_at| timestamp(0)               |                               |
| updated_at| timestamp(0)               |                               |

---

### `interest_aliases`

Синонимы интересов.

| Поле       | Тип                                     | Описание     |
|------------|-----------------------------------------|--------------|
| id         | bigint, PK                              |              |
| interest_id| bigint NOT NULL, FK → interests.id (CASCADE) |          |
| alias      | varchar(64) NOT NULL                    | Синоним      |
| locale     | varchar(8)                              | Язык/локаль  |
| created_at | timestamp(0)                            |              |
| updated_at | timestamp(0)                            |              |

---

### `interest_relations`

Явные связи интересов (граф), помимо parent_id.

| Поле              | Тип                                           | Описание |
|-------------------|-----------------------------------------------|----------|
| id                | bigint, PK                                    |          |
| parent_interest_id| bigint NOT NULL, FK → interests.id (CASCADE) |          |
| child_interest_id | bigint NOT NULL, FK → interests.id (CASCADE) |          |
| created_at        | timestamp(0)                                  |          |
| updated_at        | timestamp(0)                                  |          |

---

### `interest_user`

Интересы пользователя.

PK: (user_id, interest_id).

| Поле       | Тип                                      | Описание |
|------------|------------------------------------------|----------|
| user_id    | bigint NOT NULL, FK → users.id (CASCADE) |          |
| interest_id| bigint NOT NULL, FK → interests.id (CASCADE) |       |
| created_at | timestamp(0)                             |          |
| updated_at | timestamp(0)                             |          |

---

### `interest_links`

Полиморфная связь интересов с объектами (context_post/event/…).

PK: (parent_type, parent_id, interest_id).

| Поле       | Тип                                  | Описание                         |
|------------|--------------------------------------|----------------------------------|
| parent_type| varchar(255) NOT NULL                | Тип: context_post, event, …      |
| parent_id  | bigint NOT NULL                      | ID объекта                       |
| interest_id| bigint NOT NULL, FK → interests.id (CASCADE) | Интерес                  |
| created_at | timestamp(0)                         |                                  |
| updated_at | timestamp(0)                         |                                  |

---

## 5. События и участие

### `events`

Нормализованные события.

Важно:
- `start_time/end_time` — timestamptz и **могут быть NULL**.
- `start_date` — date для дневных фильтров.
- `time_precision/time_text/timezone` — как извлекли время из текста.
- Цена: `price_*`.
- Дедуп: UNIQUE `dedup_key` только для активных (WHERE deleted_at IS NULL).

| Поле          | Тип                                                     | Описание                         |
|---------------|----------------------------------------------------------|----------------------------------|
| id            | bigint, PK                                               |                                  |
| original_post_id| bigint, FK → context_posts.id (ON DELETE SET NULL)     | Исходный пост (nullable)         |
| community_id  | bigint NOT NULL, FK → communities.id (CASCADE)           | Площадка                         |
| title         | varchar(255) NOT NULL                                    | Название события                 |
| description   | text                                                     | Описание                         |
| status        | varchar(255) DEFAULT 'active' NOT NULL                   | Статус                           |
| external_url  | varchar(255)                                             | Ссылка на источник               |
| city          | varchar(255)                                             | Город (строкой)                  |
| address       | varchar(255)                                             | Адрес (строкой)                  |
| city_id       | bigint, FK → cities.id (ON DELETE SET NULL)              | Нормализованный город            |
| location      | geometry(Point,4326)                                     | Геоточка                         |
| latitude      | numeric(9,6), GENERATED                                  | ST_Y(location)                   |
| longitude     | numeric(9,6), GENERATED                                  | ST_X(location)                   |
| lat_round     | numeric(9,3), GENERATED                                  | Округлённая широта               |
| lon_round     | numeric(9,3), GENERATED                                  | Округлённая долгота              |
| house_fias_id | varchar(36)                                              | FIAS-идентификатор дома          |
| start_time    | timestamptz                                              | Начало (может быть NULL)         |
| end_time      | timestamptz                                              | Окончание (может быть NULL)      |
| start_date    | date                                                     | Дата (для фильтров)              |
| time_precision| varchar(16) DEFAULT 'datetime' NOT NULL                  | datetime/date/time/…             |
| time_text     | varchar(80)                                              | Время как в тексте               |
| timezone      | varchar(64)                                              | Таймзона (если извлечена)        |
| price_status  | varchar(32) DEFAULT 'unknown' NOT NULL                   | unknown/free/paid/…              |
| price_min     | integer                                                  | Мин. цена                        |
| price_max     | integer                                                  | Макс. цена                       |
| price_currency| varchar(8)                                               | Валюта                           |
| price_text    | varchar(255)                                             | Цена как в тексте                |
| price_url     | text                                                     | Ссылка на билеты/оплату          |
| dedup_key     | varchar(66)                                              | Ключ дедупликации                |
| deleted_at    | timestamp(0)                                             | Soft delete                      |
| created_at    | timestamp(0)                                             |                                  |
| updated_at    | timestamp(0)                                             |                                  |

---

### `event_sources`

Привязка события к исходным источникам/постам.

Важно:
- UNIQUE (source, post_external_id, event_id)
- UNIQUE (event_id, context_post_id) WHERE context_post_id IS NOT NULL

| Поле           | Тип                                                     | Описание                          |
|----------------|----------------------------------------------------------|-----------------------------------|
| id             | bigint, PK                                               |                                   |
| event_id       | bigint NOT NULL, FK → events.id (CASCADE)                |                                   |
| social_link_id | bigint NOT NULL, FK → community_social_links.id (CASCADE)|                                   |
| context_post_id| bigint, FK → context_posts.id (ON DELETE SET NULL)       | Исходный пост (nullable)          |
| source         | text NOT NULL                                            | Тип/провайдер источника           |
| post_external_id| text NOT NULL                                           | Внешний ID поста                  |
| external_url   | text                                                     | URL поста                         |
| published_at   | timestamptz                                              | Время публикации                  |
| images         | json DEFAULT '[]' NOT NULL                               | Список картинок                   |
| meta           | json                                                     | Доп. мета                         |
| generated_link | text                                                     | Сгенерированная ссылка (если есть)|
| created_at     | timestamp(0)                                             |                                   |
| updated_at     | timestamp(0)                                             |                                   |

---

### `event_attendees`

Участники события.

PK: (event_id, user_id).

| Поле      | Тип                                      | Описание |
|-----------|------------------------------------------|----------|
| event_id  | bigint NOT NULL, FK → events.id (CASCADE)|          |
| user_id   | bigint NOT NULL, FK → users.id (CASCADE) |          |
| status    | varchar(255) DEFAULT 'going' NOT NULL    | going/…  |
| joined_at | timestamp(0)                             |          |
| created_at| timestamp(0)                             |          |
| updated_at| timestamp(0)                             |          |

---

### `event_interest`

Событие ↔ интересы.

PK: (event_id, interest_id).

| Поле       | Тип                                          | Описание |
|------------|----------------------------------------------|----------|
| event_id   | bigint NOT NULL, FK → events.id (CASCADE)    |          |
| interest_id| bigint NOT NULL, FK → interests.id (CASCADE) |          |
| created_at | timestamp(0)                                 |          |
| updated_at | timestamp(0)                                 |          |

---

## 6. Примеры запросов

```sql
-- 1) События по городу и дате (использует индекс (city_id, start_date))
SELECT e.*
FROM events e
WHERE e.city_id = :city_id
  AND e.start_date BETWEEN :d1 AND :d2
  AND e.deleted_at IS NULL
ORDER BY e.start_date, e.start_time NULLS LAST;

-- 2) События в радиусе 3 км от точки (геопоиск)
SELECT e.*
FROM events e
WHERE e.location IS NOT NULL
  AND e.deleted_at IS NULL
  AND ST_DWithin(
        e.location::geography,
        ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
        3000
      );

-- 3) Источники события
SELECT es.*
FROM event_sources es
WHERE es.event_id = :event_id
ORDER BY es.published_at DESC NULLS LAST;

-- 4) Сырые посты по ссылке-источнику
SELECT cp.*
FROM context_posts cp
WHERE cp.social_link_id = :social_link_id
  AND cp.deleted_at IS NULL
ORDER BY cp.published_at DESC NULLS LAST;

-- 5) Последняя проверка ссылок сообщества
SELECT csl.*, slv.status, slv.checked_at
FROM community_social_links csl
LEFT JOIN social_link_verifications slv
  ON slv.id = csl.last_verification_id
WHERE csl.community_id = :community_id
ORDER BY csl.id;
