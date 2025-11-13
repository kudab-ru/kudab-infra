# Описание структуры базы данных KUDAB (схема `public`, 2025)

Схема `public` хранит доменные данные (города, сообщества, события, интересы, контент), а также служебные таблицы Laravel (очереди, кэш, права).

---

## Группы таблиц

- Пользователи и авторизация: `users`, `telegram_users`, `roles`, `permissions`, `role_has_permissions`, `model_has_roles`, `model_has_permissions`, `personal_access_tokens`, `password_reset_tokens`, `sessions`
- Города и площадки: `cities`, `communities`, `community_social_links`, `social_networks`, `community_interest`, `social_link_verifications`, `parsing_statuses`, `error_logs`
- Интересы: `interests`, `interest_aliases`, `interest_relations`, `interest_user`, `interest_links`
- События и участие: `events`, `event_sources`, `event_attendees`, `event_interest`
- Контент и LLM: `context_posts`, `attachments`, `context_interactions`, `llm_jobs`
- Очереди и инфраструктура: `jobs`, `job_batches`, `failed_jobs`, `cache`, `cache_locks`, `migrations`, `seeders`, `alembic_version`

Дальше — кратко по каждой сущности.

---

## 1. Пользователи и авторизация

### `users`

Основная учетная запись.

| Поле              | Тип                                      | Описание                     |
|-------------------|------------------------------------------|------------------------------|
| id                | bigint, PK                               | Идентификатор пользователя   |
| name              | varchar(255) NOT NULL                    | Имя                          |
| email             | varchar(255) NOT NULL                    | Email                        |
| email_verified_at | timestamp                                | Подтверждение email          |
| password          | varchar(255) NOT NULL                    | Хэш пароля                   |
| remember_token    | varchar(100)                             | Токен “запомнить меня”       |
| avatar_url        | varchar(255)                             | URL аватара                  |
| bio               | text                                     | О себе                       |
| deleted_at        | timestamp                                | Soft delete                  |
| created_at        | timestamp                                |                               |
| updated_at        | timestamp                                |                               |

### Роли и права (Spatie)

#### `roles`

| Поле      | Тип             | Описание          |
|-----------|-----------------|-------------------|
| id        | bigint, PK      |                   |
| name      | varchar(255)    | Название роли     |
| guard_name| varchar(255)    | Guard (обычно web)|
| created_at| timestamp       |                   |
| updated_at| timestamp       |                   |

#### `permissions`

Аналогично `roles`.

| Поле      | Тип             | Описание      |
|-----------|-----------------|---------------|
| id        | bigint, PK      |               |
| name      | varchar(255)    | Имя права     |
| guard_name| varchar(255)    | Guard         |
| created_at| timestamp       |               |
| updated_at| timestamp       |               |

#### `role_has_permissions`

Многие-ко-многим роли ↔ права.

| Поле         | Тип                 |
|--------------|---------------------|
| role_id      | bigint, FK → roles  |
| permission_id| bigint, FK → permissions |

PK составной по (permission_id, role_id).

#### `model_has_roles`

Роли на моделях (обычно `users`).

| Поле      | Тип                        |
|-----------|----------------------------|
| role_id   | bigint, FK → roles         |
| model_type| varchar(255)               |
| model_id  | bigint                     |

PK: (role_id, model_id, model_type).

#### `model_has_permissions`

Права на моделях.

| Поле         | Тип                        |
|--------------|----------------------------|
| permission_id| bigint, FK → permissions   |
| model_type   | varchar(255)               |
| model_id     | bigint                     |

PK: (permission_id, model_id, model_type).



## 2. Города и площадки

### `cities`

Города с геоточкой (PostGIS).

| Поле        | Тип                                 | Описание                         |
|-------------|-------------------------------------|----------------------------------|
| id          | bigint, PK                          |                                  |
| name        | varchar(255) NOT NULL               | Название города                  |
| country_code| varchar(2)                          | ISO-код страны                   |
| location    | geometry(Point, 4326) NOT NULL      | Точка центра                     |
| latitude    | numeric(9,6), GENERATED             | ST_Y(location)                   |
| longitude   | numeric(9,6), GENERATED             | ST_X(location)                   |
| status      | varchar(16) DEFAULT 'active' NOT NULL | Статус записи                 |
| name_ci     | text, GENERATED                     | name в нижнем регистре           |
| created_at  | timestamp                           |                                  |
| updated_at  | timestamp                           |                                  |

### `communities`

Сообщества / площадки.

| Поле               | Тип                          | Описание                         |
|--------------------|------------------------------|----------------------------------|
| id                 | bigint, PK                   |                                  |
| name               | varchar(255) NOT NULL        | Название                         |
| description        | text                         | Описание                         |
| city               | varchar(255)                 | Город (строкой)                  |
| street             | varchar(255)                 | Улица                            |
| house              | varchar(255)                 | Дом                              |
| avatar_url         | varchar(255)                 | Аватар                           |
| image_url          | varchar(255)                 | Доп. картинка                    |
| last_checked_at    | timestamp                    | Последняя проверка               |
| verification_status| varchar(255) DEFAULT 'pending'| pending/completed/failed…      |
| is_verified        | boolean DEFAULT false NOT NULL| Флаг «верифицировано»          |
| verification_meta  | jsonb                        | Сводка LLM-проверок              |
| city_id            | bigint, FK → cities.id       | Нормализованный город            |
| created_at         | timestamp                    |                                  |
| updated_at         | timestamp                    |                                  |

### `social_networks`

Справочник соцсетей.

| Поле      | Тип               |
|-----------|-------------------|
| id        | bigint, PK        |
| name      | varchar(64)       |
| slug      | varchar(32)       |
| icon      | varchar(255)      |
| url_mask  | varchar(255)      |
| created_at| timestamp         |
| updated_at| timestamp         |

### `community_social_links`

Ссылки сообществ в соцсетях.

| Поле                  | Тип                              | Описание                         |
|-----------------------|----------------------------------|----------------------------------|
| id                    | bigint, PK                       |                                  |
| community_id          | bigint NOT NULL, FK → communities.id | Сообщество                  |
| social_network_id     | bigint NOT NULL, FK → social_networks.id | Соцсеть                    |
| external_community_id | varchar(128)                     | ID/slug в соцсети               |
| url                   | varchar(512) NOT NULL            | Полный URL                      |
| last_verification_id  | bigint, FK → social_link_verifications.id | Последняя проверка (история) |
| last_checked_at       | timestamp                        | Когда проверяли                 |
| last_is_active        | boolean                          | Активна ли ссылка               |
| last_has_events       | boolean                          | Есть ли «событийные» посты      |
| last_kind             | varchar(16)                      | aggregator / venue_host / org   |
| last_hq_city          | varchar(255)                     | HQ-город по ссылке              |
| last_hq_street        | varchar(255)                     | HQ-улица                        |
| last_hq_house         | varchar(255)                     | HQ-дом                          |
| last_hq_confidence    | numeric(3,2)                     | Уверенность HQ (0..1)           |
| created_at            | timestamp                        |                                  |
| updated_at            | timestamp                        |                                  |

### `community_interest`

Сообщества ↔ интересы.

| Поле         | Тип                     |
|--------------|-------------------------|
| community_id | bigint, FK → communities.id |
| interest_id  | bigint, FK → interests.id   |
| created_at   | timestamp               |
| updated_at   | timestamp               |

PK составной: (community_id, interest_id).

### `social_link_verifications`

История LLM-проверок соц-ссылок.

| Поле                   | Тип                                | Описание                      |
|------------------------|------------------------------------|-------------------------------|
| id                     | bigint, PK                         |                               |
| community_id           | bigint NOT NULL, FK → communities  |                               |
| community_social_link_id| bigint NOT NULL, FK → community_social_links.id |
| social_network_id      | bigint NOT NULL, FK → social_networks.id |
| checked_at             | timestamp DEFAULT now() NOT NULL   | Время проверки                |
| status                 | varchar(16) DEFAULT 'ok' NOT NULL  | ok / error / skipped …        |
| latency_ms             | integer                            | Время ответа                  |
| model                  | varchar(64)                        | Модель LLM                    |
| prompt_version         | integer DEFAULT 1 NOT NULL         | Версия промпта                |
| error_code             | varchar(64)                        | Код ошибки                    |
| error_message          | text                               | Текст ошибки                  |
| is_active              | boolean                            | Активность                    |
| has_events_posts       | boolean                            | Есть ли посты с событиями     |
| activity_score         | numeric(3,2)                       | 0..1                          |
| events_score           | numeric(3,2)                       | 0..1                          |
| kind                   | varchar(16)                        | Тип источника                 |
| has_fixed_place        | boolean                            | Есть ли своя площадка         |
| hq_city                | varchar(255)                       | HQ-город                      |
| hq_street              | varchar(255)                       | HQ-улица                      |
| hq_house               | varchar(255)                       | HQ-дом                        |
| hq_confidence          | numeric(3,2)                       | Уверенность HQ                |
| examples               | jsonb                              | Примеры постов                |
| events_locations       | jsonb                              | Извлечённые адреса            |
| raw                    | jsonb                              | Полный сырой ответ            |
| created_at             | timestamp                          |                               |
| updated_at             | timestamp                          |                               |

---

## 3. Интересы

### `interests`

| Поле      | Тип               | Описание                      |
|-----------|-------------------|-------------------------------|
| id        | bigint, PK        |                               |
| name      | varchar(255)      | Название интереса             |
| slug      | varchar(64) NOT NULL | Слаг/код                    |
| parent_id | bigint            | FK → interests.id (дерево)    |
| created_at| timestamp         |                               |
| updated_at| timestamp         |                               |

### `interest_aliases`

Синонимы интересов.

| Поле      | Тип                    |
|-----------|------------------------|
| id        | bigint, PK             |
| interest_id| bigint NOT NULL, FK → interests.id |
| alias     | varchar(64) NOT NULL   |
| locale    | varchar(8)             |
| created_at| timestamp              |
| updated_at| timestamp              |

### `interest_relations`

Явные связи интересов (граф).

| Поле              | Тип                    |
|-------------------|------------------------|
| id                | bigint, PK             |
| parent_interest_id| bigint NOT NULL, FK → interests.id |
| child_interest_id | bigint NOT NULL, FK → interests.id |
| created_at        | timestamp              |
| updated_at        | timestamp              |

### `interest_user`

Интересы пользователя.

| Поле       | Тип                    |
|------------|------------------------|
| user_id    | bigint NOT NULL, FK → users.id |
| interest_id| bigint NOT NULL, FK → interests.id |
| created_at | timestamp              |
| updated_at | timestamp              |

PK: (user_id, interest_id).

### `interest_links`

Полиморфная связь интересов с объектами.

| Поле       | Тип               | Описание                         |
|------------|-------------------|----------------------------------|
| parent_type| varchar(255)      | Тип: `context_post`, `event`, …  |
| parent_id  | bigint            | ID объекта                       |
| interest_id| bigint, FK → interests.id | Интерес                    |
| created_at | timestamp         |                                  |
| updated_at | timestamp         |                                  |

PK по дампу — отдельный индекс; логически ключ (parent_type, parent_id, interest_id).

---

## 4. События и участие

### `events`

Нормализованные события.

| Поле          | Тип                               | Описание                         |
|---------------|-----------------------------------|----------------------------------|
| id            | bigint, PK                        |                                  |
| original_post_id| bigint, FK → context_posts.id   | Исходный пост (nullable)         |
| community_id  | bigint NOT NULL, FK → communities.id | Площадка                      |
| title         | varchar(255) NOT NULL             | Название события                |
| start_time    | timestamp NOT NULL                | Начало                          |
| end_time      | timestamp                         | Окончание                       |
| city          | varchar(255)                      | Город (строкой)                 |
| address       | varchar(255)                      | Адрес                           |
| description   | text                              | Описание                        |
| status        | varchar(255) DEFAULT 'active' NOT NULL | Статус                      |
| external_url  | varchar(255)                      | Ссылка на источник             |
| location      | geometry(Point,4326)              | Геоточка                        |
| latitude      | numeric(9,6), GENERATED           | ST_Y(location)                  |
| longitude     | numeric(9,6), GENERATED           | ST_X(location)                  |
| lat_round     | numeric(9,3), GENERATED           | Округлённая широта              |
| lon_round     | numeric(9,3), GENERATED           | Округлённая долгота             |
| dedup_key     | varchar(66)                       | Ключ дедупликации               |
| house_fias_id | varchar(36)                       | FIAS-идентификатор дома         |
| city_id       | bigint, FK → cities.id            | Нормализованный город           |
| deleted_at    | timestamp                         | Soft delete                     |
| created_at    | timestamp                         |                                  |
| updated_at    | timestamp                         |                                  |

### `event_sources`

Привязка события к исходным источникам/постам.

| Поле          | Тип                          | Описание                       |
|---------------|------------------------------|--------------------------------|
| id            | bigint, PK                   |                                |
| event_id      | bigint NOT NULL, FK → events.id |
| social_link_id| bigint NOT NULL, FK → community_social_links.id |
| context_post_id| bigint, FK → context_posts.id | Исходный пост (nullable)    |
| source        | text NOT NULL                | Тип/описание источника        |
| post_external_id| text NOT NULL              | Внешний ID поста              |
| external_url  | text                         | URL поста                      |
| published_at  | timestamptz                  | Время публикации               |
| images        | json DEFAULT '[]' NOT NULL   | Список картинок                |
| meta          | json                         | Доп. мета                      |
| generated_link| text                         | Сгенерированный URL            |
| created_at    | timestamp                    |                                |
| updated_at    | timestamp                    |                                |

### `event_attendees`

Участники события.

| Поле      | Тип                             |
|-----------|---------------------------------|
| event_id  | bigint NOT NULL, FK → events.id |
| user_id   | bigint NOT NULL, FK → users.id  |
| status    | varchar(255) DEFAULT 'going'    |
| joined_at | timestamp                       |
| created_at| timestamp                       |
| updated_at| timestamp                       |

PK: (event_id, user_id).

### `event_interest`

Событие ↔ интересы.

| Поле       | Тип                             |
|------------|---------------------------------|
| event_id   | bigint NOT NULL, FK → events.id |
| interest_id| bigint NOT NULL, FK → interests.id |
| created_at | timestamp                       |
| updated_at | timestamp                       |

PK: (event_id, interest_id).

---

## 5. Контент и LLM

### `context_posts`

Исходные посты (VK/TG/сайты).

| Поле         | Тип                               | Описание                         |
|--------------|-----------------------------------|----------------------------------|
| id           | bigint, PK                        |                                  |
| external_id  | varchar(255)                      | ID поста в источнике            |
| source       | varchar(255)                      | vk / tg / site и т.п.           |
| author_id    | bigint                            | Полиморфный автор               |
| author_type  | varchar(255)                      | user / community / external     |
| community_id | bigint, FK → communities.id       | Сообщество (если есть)          |
| social_link_id| bigint, FK → community_social_links.id | Конкретная ссылка       |
| title        | varchar(255)                      | Заголовок                        |
| text         | text                              | Текст                            |
| published_at | timestamp                         | Время публикации                 |
| status       | varchar(255) DEFAULT 'active' NOT NULL | Статус                      |
| deleted_at   | timestamp                         | Soft delete                      |
| created_at   | timestamp                         |                                  |
| updated_at   | timestamp                         |                                  |

### `attachments`

Вложения к постам/событиям.

| Поле       | Тип               | Описание                        |
|------------|-------------------|---------------------------------|
| id         | bigint, PK        |                                 |
| parent_type| varchar(255)      | Тип родителя (context_post, event, …) |
| parent_id  | bigint            | ID родителя                     |
| type       | varchar(255)      | image / video / file / …        |
| url        | text NOT NULL     | URL файла                       |
| preview_url| varchar(255)      | Превью                          |
| order      | integer DEFAULT 0 | Порядок                         |
| created_at | timestamp         |                                 |
| updated_at | timestamp         |                                 |

### `context_interactions`

Взаимодействия пользователей с контентом.

| Поле      | Тип                               | Описание                    |
|-----------|-----------------------------------|-----------------------------|
| id        | bigint, PK                        |                             |
| post_id   | bigint NOT NULL, FK → context_posts.id |
| user_id   | bigint NOT NULL, FK → users.id    |
| type      | varchar(255) NOT NULL             | request / flag / comment…   |
| status    | varchar(255)                      | Статус обработки            |
| message   | text                              | Текст                       |
| reason    | varchar(255)                      | Причина/категория           |
| created_at| timestamp                         |                             |
| updated_at| timestamp                         |                             |

---

## 6. Примеры запросов

```sql
-- События в радиусе 3 км от точки
SELECT e.*
FROM events e
WHERE e.location IS NOT NULL
  AND ST_DWithin(
        e.location::geography,
        ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
        3000
      );

-- Интересы пользователя
SELECT i.*
FROM interests i
JOIN interest_user iu ON iu.interest_id = i.id
WHERE iu.user_id = :user_id;

-- События по сообществу + город
SELECT e.*, c.name AS community_name, ci.name AS city_name
FROM events e
JOIN communities c ON c.id = e.community_id
LEFT JOIN cities ci ON ci.id = e.city_id
WHERE c.id = :community_id;

-- Источники события
SELECT es.*, cps.source, cps.external_id
FROM event_sources es
LEFT JOIN context_posts cps ON cps.id = es.context_post_id
WHERE es.event_id = :event_id;

-- Последняя проверка ссылок сообщества
SELECT csl.*, slv.status, slv.checked_at
FROM community_social_links csl
LEFT JOIN social_link_verifications slv
  ON slv.id = csl.last_verification_id
WHERE csl.community_id = :community_id;
```