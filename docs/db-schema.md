# DB-SCHEMA.md

## Описание структуры базы данных KUDAB

База данных построена для масштабируемого хранения событий, пользователей, сообществ, интересов и универсального контента. Используются best practices для именования, связей, индексирования и поддержки geo-запросов (PostGIS).

---

## Основные сущности и связи

### USERS

| Поле           | Тип         | Описание                   |
|----------------|-------------|----------------------------|
| id             | bigserial   | PRIMARY KEY                |
| name           | varchar     | Имя пользователя           |
| email          | varchar     | Email (уникальный)         |
| password       | varchar     | Пароль (хеш)               |
| avatar_url     | varchar     | Ссылка на аватар           |
| bio            | text        | О себе                     |
| email_verified_at | timestamp| Время подтверждения email  |
| remember_token | varchar     | Для восстановления сессии  |
| created_at     | timestamp   |                            |
| updated_at     | timestamp   |                            |
| deleted_at     | timestamp   | Soft delete                |

#### telegram_users

| Поле             | Тип        | Описание                  |
|------------------|------------|---------------------------|
| id               | bigserial  | PRIMARY KEY               |
| user_id          | bigint     | FK → users.id (nullable)  |
| telegram_id      | bigint     | Telegram user ID (unique) |
| telegram_username| varchar    | username Telegram         |
| first_name       | varchar    | Имя Telegram              |
| last_name        | varchar    | Фамилия Telegram          |
| language_code    | varchar    | Язык                      |
| chat_id          | bigint     | ID чата                   |
| is_bot           | boolean    | Бот?                      |
| registered_at    | timestamp  | Первое посещение          |
| last_active      | timestamp  | Последняя активность      |
| created_at       | timestamp  |                           |
| updated_at       | timestamp  |                           |

---

### INTERESTS

| Поле      | Тип      | Описание                      |
|-----------|----------|-------------------------------|
| id        | bigserial| PRIMARY KEY                   |
| name      | varchar  | Название интереса             |
| parent_id | bigint   | FK → interests.id (nullable)  |
| is_paid   | boolean  | Платный интерес               |
| created_at| timestamp|                               |
| updated_at| timestamp|                               |

#### interest_user

| Поле       | Тип     | Описание                     |
|------------|---------|------------------------------|
| user_id    | bigint  | FK → users.id                |
| interest_id| bigint  | FK → interests.id            |
| created_at | timestamp|                             |
| updated_at | timestamp|                             |
**PRIMARY KEY (user_id, interest_id)**

#### interest_relations

| Поле               | Тип     | Описание               |
|--------------------|---------|------------------------|
| id                 | bigserial| PRIMARY KEY           |
| parent_interest_id | bigint  | FK → interests.id      |
| child_interest_id  | bigint  | FK → interests.id      |
| created_at         | timestamp|                       |
| updated_at         | timestamp|                       |

---

### COMMUNITIES

| Поле        | Тип      | Описание                   |
|-------------|----------|----------------------------|
| id          | bigserial| PRIMARY KEY                |
| name        | varchar  | Название                   |
| description | text     | Описание                   |
| source      | varchar  | vk, tg, site и др.         |
| avatar_url  | varchar  | Ссылка на аватар           |
| external_id | varchar  | ID в исходной соцсети      |
| created_at  | timestamp|                            |
| updated_at  | timestamp|                            |

#### community_social_links

| Поле                 | Тип      | Описание                       |
|----------------------|----------|--------------------------------|
| id                   | bigserial| PRIMARY KEY                    |
| community_id         | bigint   | FK → communities.id            |
| social_network_id    | bigint   | FK → social_networks.id        |
| external_community_id| varchar  | ID/slug в соцсети              |
| url                  | varchar  | Ссылка на профиль              |
| created_at           | timestamp|                                |
| updated_at           | timestamp|                                |

#### community_interest

| Поле         | Тип    | Описание                |
|--------------|--------|-------------------------|
| community_id | bigint | FK → communities.id     |
| interest_id  | bigint | FK → interests.id       |
| created_at   | timestamp|                       |
| updated_at   | timestamp|                       |
**PRIMARY KEY (community_id, interest_id)**

#### social_networks

| Поле     | Тип      | Описание                   |
|----------|----------|----------------------------|
| id       | bigserial| PRIMARY KEY                |
| name     | varchar  | vk, telegram, instagram    |
| slug     | varchar  | Короткое имя               |
| icon     | varchar  | emoji или URL              |
| url_mask | varchar  | Шаблон для генерации ссылок|
| created_at| timestamp|                           |

---

### EVENTS

| Поле           | Тип         | Описание                                  |
|----------------|-------------|-------------------------------------------|
| id             | bigserial   | PRIMARY KEY                               |
| original_post_id| bigint     | FK → context_posts.id (nullable)          |
| community_id   | bigint      | FK → communities.id                       |
| title          | varchar     | Название события                          |
| start_time     | timestamp   | Начало                                    |
| end_time       | timestamp   | Окончание                                 |
| location       | geometry    | Point(4326), PostGIS                      |
| latitude       | decimal(9,6)| STORED, ST_Y(location)                    |
| longitude      | decimal(9,6)| STORED, ST_X(location)                    |
| city           | varchar     | Город                                     |
| address        | varchar     | Адрес                                     |
| description    | text        | Описание                                  |
| status         | varchar     | active, canceled, draft и др.             |
| external_url   | varchar     | Ссылка на источник                        |
| created_at     | timestamp   |                                           |
| updated_at     | timestamp   |                                           |
| deleted_at     | timestamp   | Soft delete                               |

**Spatial Index:**  
`CREATE INDEX events_location_gix ON events USING GIST (location);`

#### event_interest

| Поле       | Тип     | Описание                      |
|------------|---------|-------------------------------|
| event_id   | bigint  | FK → events.id                |
| interest_id| bigint  | FK → interests.id             |
| created_at | timestamp|                              |
**PRIMARY KEY (event_id, interest_id)**

#### event_attendees

| Поле      | Тип      | Описание                                   |
|-----------|----------|--------------------------------------------|
| event_id  | bigint   | FK → events.id                             |
| user_id   | bigint   | FK → users.id                              |
| status    | varchar  | going, interested, rejected и др.          |
| joined_at | timestamp| Когда присоединился                        |
| created_at| timestamp|                                            |
| updated_at| timestamp|                                            |
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
| message   | text      | Текст комментария, запроса, жалобы            |
| reason    | varchar   | Причина/категория (если применимо)            |
| created_at| timestamp |                                               |
| updated_at| timestamp |                                               |

---

## Best practices и особенности

- Все ключевые поля имеют уникальные индексы и внешние ключи.
- Geo-запросы делаются через PostGIS-поле location, быстрые выборки — через STORED lat/lon.
- Вложения и связи интересов реализованы через morphTo (parent_type/parent_id).
- junction-таблицы (`event_interest`, `interest_user`, `community_interest`, `interest_links`) — с составными PK.
- Soft delete в users, events, context_posts (deleted_at).
- Все временные поля единообразно `*_at`.

---

## Примеры запросов

```sql
-- Найти события в радиусе 3км от точки
SELECT * FROM events
WHERE ST_DWithin(location, ST_MakePoint(37.620393, 55.75396)::geography, 3000);

-- Получить интересы пользователя
SELECT i.* FROM interests i
JOIN interest_user iu ON iu.interest_id = i.id
WHERE iu.user_id = :user_id;

-- Получить вложения к событию
SELECT * FROM attachments
WHERE parent_type = 'event' AND parent_id = :event_id;
```