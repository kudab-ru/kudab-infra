#### KUDAB: СТРУКТУРА БАЗЫ ДАННЫХ

---

#### ОБЩЕЕ ОПИСАНИЕ

База данных kudab.ru построена для масштабируемой, расширяемой агрегации событий, пользователей, интересов, парсинга контента из соцсетей и сайтов.  
Все связи реализованы по best-practices: строгие FK для основных сущностей, morphTo-отношения для универсальных связей, индексация по ключевым полям.

---

#### МОДУЛЬ ПОЛЬЗОВАТЕЛИ И TELEGRAM

##### users

| Поле             | Тип        | Описание                                 |
|------------------|------------|------------------------------------------|
| id               | bigserial  | PRIMARY KEY                              |
| name             | varchar    | Имя                                      |
| email            | varchar    | Email (уникальный)                       |
| password         | varchar    | Пароль (хеш)                             |
| avatar           | varchar    | Ссылка на аватар (опционально)           |
| bio              | text       | Биография                                |
| email_verified_at| timestamp  | Дата подтверждения email                 |
| remember_token   | varchar    | Для восстановления сессии                |
| created_at       | timestamp  |                                          |
| updated_at       | timestamp  |                                          |
| deleted_at       | timestamp  | Мягкое удаление (soft delete)            |

##### telegram_users

| Поле         | Тип        | Описание                                   |
|--------------|------------|--------------------------------------------|
| id           | bigserial  | PRIMARY KEY                                |
| user_id      | bigint     | FK → users.id, nullable                    |
| telegram_id  | bigint     | Telegram user ID (уникальный)              |
| username     | varchar    | Telegram username (nullable)                |
| first_name   | varchar    | Имя Telegram (nullable)                    |
| last_name    | varchar    | Фамилия Telegram (nullable)                |
| language_code| varchar    | Язык Telegram                              |
| chat_id      | bigint     | Активный чат пользователя                  |
| is_bot       | boolean    | Это бот-пользователь                       |
| registered_at| timestamp  | Когда впервые зашёл                        |
| last_active  | timestamp  | Последняя активность                       |
| created_at   | timestamp  |                                           |
| updated_at   | timestamp  |                                           |

- Все входящие сообщения через Telegram-бота автоматически ищут (или создают) запись telegram_users.
- Связь с таблицей users опциональна (user_id может быть null, если пользователь только в Telegram).
- Для полной синхронизации профиля пользователь должен выполнить привязку — ввести уникальный код из личного кабинета платформы.

---

#### ИНТЕРЕСЫ И СВЯЗИ

##### interests

| Поле      | Тип       | Описание                      |
|-----------|-----------|-------------------------------|
| id        | bigserial | PRIMARY KEY                   |
| name      | varchar   | Название интереса             |
| parent_id | bigint    | FK → interests.id, nullable   |
| is_paid   | boolean   | Платный интерес?              |
| created_at| timestamp |                               |
| updated_at| timestamp |                               |

##### interest_user

| Поле       | Тип    | Описание                |
|------------|--------|-------------------------|
| user_id    | bigint | FK → users.id           |
| interest_id| bigint | FK → interests.id       |
| created_at | timestamp |                      |
| updated_at | timestamp |                      |

- Можно добавить weight/priority для рейтинга

*PRIMARY KEY (user_id, interest_id)*

##### interest_relations

| Поле               | Тип    | Описание              |
|--------------------|--------|-----------------------|
| id                 | bigserial | PRIMARY KEY       |
| parent_interest_id | bigint | FK → interests.id     |
| child_interest_id  | bigint | FK → interests.id     |
| created_at         | timestamp |                   |
| updated_at         | timestamp |                   |

---

#### Особенности и рекомендации

- Использовать Soft Deletes (deleted_at) для users, если нужна безопасная деактивация.
- Для interests рекомендуется создать индекс на parent_id.
- Таблица interest_relations оптимальна для построения графов и рекомендательных систем.
- Можно расширять interests локализацией (добавить отдельную таблицу interest_translations).

---

#### СООБЩЕСТВА И СОЦСЕТИ

##### communities

| Поле        | Тип       | Описание                          |
|-------------|-----------|-----------------------------------|
| id          | bigserial | PRIMARY KEY                       |
| name        | varchar   | Название                          |
| description | text      | Описание                          |
| source      | varchar   | Источник (vk, tg, сайт)           |
| avatar_url  | varchar   | Ссылка на аватар                  |
| external_id | varchar   | Внешний id                        |
| created_at  | timestamp |                                   |
| updated_at  | timestamp |                                   |

##### community_social_links

| Поле                       | Тип        | Описание                                                         |
|----------------------------|------------|------------------------------------------------------------------|
| id                         | bigserial  | PRIMARY KEY                                                      |
| community_id               | bigint     | FK → communities.id                                              |
| social_network_id          | bigint     | FK → social_networks.id                                          |
| social_network_community_id| varchar    | Идентификатор сообщества в соцсети (handle/slug/id/username)     |
| path                       | varchar    | Ссылка на профиль, паблик, канал или группу в соцсети            |
| created_at                 | timestamp  | Дата создания записи                                             |
| updated_at                 | timestamp  | Дата последнего изменения записи                                 |

- `social_network_community_id` — это идентификатор, ник или id сообщества в конкретной соцсети.  
  Используется для быстрого поиска, генерации ссылки или интеграции с API соцсетей.  
  Например:
    - Telegram: kudab (https://t.me/kudab)
    - VK: club123456 или kudab (https://vk.com/club123456 или https://vk.com/kudab)
    - Instagram: mypage (https://instagram.com/mypage)
- В одной таблице может быть несколько ссылок для одного сообщества (например, основной канал и чат в Telegram).

##### community_interest

| Поле         | Тип      | Описание                    |
|--------------|----------|-----------------------------|
| id           | bigserial| PRIMARY KEY                 |
| community_id | bigint   | FK → communities.id         |
| interest_id  | bigint   | FK → interests.id           |
| created_at   | timestamp|                             |
| updated_at   | timestamp|                             |

##### social_networks

| Поле     | Тип        | Описание               |
|----------|------------|------------------------|
| id       | bigserial  | PRIMARY KEY            |
| name     | varchar    | Название               |
| slug     | varchar    | Слаг                   |
| icon     | varchar    | Иконка/emoji           |
| url_mask | varchar    | Шаблон URL             |
| created_at | timestamp|                        |

---

#### СОБЫТИЯ И УЧАСТНИКИ

##### events

| Поле             | Тип        | Описание                            |
|------------------|------------|-------------------------------------|
| id               | bigserial  | PRIMARY KEY                         |
| original_post_id | bigint     | FK → context_posts.id (nullable)    |
| community_id     | bigint     | FK → communities.id                 |
| title            | varchar    | Название                            |
| start_time       | timestamp  | Дата и время начала                 |
| end_time         | timestamp  | Дата и время окончания (nullable)   |
| location         | varchar    | Место                               |
| description      | text       | Описание                            |
| status           | varchar    | Статус (active, canceled, ...)      |
| external_url     | varchar    | Ссылка на источник                  |
| created_at       | timestamp  |                                     |
| updated_at       | timestamp  |                                     |

##### event_interest

| Поле       | Тип    | Описание                   |
|------------|--------|----------------------------|
| id         | bigserial | PRIMARY KEY            |
| event_id   | bigint | FK → events.id             |
| interest_id| bigint | FK → interests.id          |
| created_at | timestamp |                         |

##### event_attendees

| Поле      | Тип      | Описание                          |
|-----------|----------|-----------------------------------|
| id        | bigserial| PRIMARY KEY                       |
| event_id  | bigint   | FK → events.id                    |
| user_id   | bigint   | FK → users.id                     |
| status    | varchar  | going, interested, rejected и др. |
| joined_at | timestamp| Дата присоединения                |
| created_at| timestamp|                                   |

---

#### КОНТЕНТ, ВЛОЖЕНИЯ, ИНТЕРЕСЫ КОНТЕНТА

##### context_posts

| Поле         | Тип        | Описание                                 |
|--------------|------------|------------------------------------------|
| id           | bigserial  | PRIMARY KEY                              |
| external_id  | varchar    | Внешний id VK/TG/сайта                   |
| source       | varchar    | Источник (“vk”, “tg”, “site”, ...)       |
| author_id    | bigint     | FK/внешний id автора                     |
| author_type  | varchar    | Тип автора (user, community, external)   |
| community_id | bigint     | FK → communities.id (nullable)           |
| title        | varchar    | Заголовок/тема (nullable)                |
| text         | text       | Основной текст                           |
| published_at | timestamp  | Дата публикации                          |
| status       | varchar    | active, flagged, hidden, удалён          |
| created_at   | timestamp  |                                          |
| updated_at   | timestamp  |                                          |

##### attachments

| Поле        | Тип       | Описание                                  |
|-------------|-----------|-------------------------------------------|
| id          | bigserial | PRIMARY KEY                               |
| parent_type | varchar   | Тип (“context_post”, “event”, ...)        |
| parent_id   | bigint    | ID объекта                                |
| type        | varchar   | Тип вложения (“image”, “video”, ...)      |
| url         | varchar   | Ссылка на файл                            |
| preview_url | varchar   | Превью (nullable)                         |
| order       | integer   | Порядок                                   |
| created_at  | timestamp |                                           |
| updated_at  | timestamp |                                           |

##### interest_links

| Поле        | Тип       | Описание                                  |
|-------------|-----------|-------------------------------------------|
| id          | bigserial | PRIMARY KEY                               |
| parent_type | varchar   | Тип (“context_post”, “event”, ...)        |
| parent_id   | bigint    | ID объекта                                |
| interest_id | bigint    | FK → interests.id                         |
| created_at  | timestamp |                                           |
| updated_at  | timestamp |                                           |

##### context_interactions

| Поле      | Тип       | Описание                                     |
|-----------|-----------|-----------------------------------------------|
| id        | bigserial | PRIMARY KEY                                   |
| post_id   | bigint    | FK → context_posts.id                         |
| user_id   | bigint    | FK → users.id                                 |
| type      | varchar   | request, response, flag, comment, ...         |
| status    | varchar   | Статус действия                               |
| message   | text      | Сообщение/комментарий                         |
| reason    | varchar   | Причина (nullable)                            |
| created_at| timestamp |                                               |
| updated_at| timestamp |                                               |

---

#### ДОПОЛНИТЕЛЬНЫЕ ВОЗМОЖНОСТИ

*Смотри `database.dbml` для полного списка таблиц: модерация, напоминания, achievements, логи, admins.*

---

#### BEST PRACTICES

- Везде, где используются morph-связи (parent_type/parent_id), указывать в документации список поддерживаемых сущностей.
- Для всех универсальных связей (attachments, interest_links) — обеспечить консистентность на уровне приложения и ORM.
- Всегда индексировать внешние ключи и основные поля поиска (status, start_time, external_id+source).
- Использовать soft delete для ключевых сущностей, где это критично (users, events, posts).

---

#### ВИЗУАЛИЗАЦИЯ

- ER-диаграмму можно сгенерировать через [dbdiagram.io](https://dbdiagram.io/d/kudab-ru-686af0aef413ba350884721e) на основе файла `database.dbml`.
- Любую новую таблицу или связь сразу добавляй сюда и в dbml, чтобы не потерять контекст.

---

#### ОБНОВЛЕНИЕ

- Любые изменения/расширения структуры фиксируются здесь, с версией и датой.
- При необходимости — см. раздел `migrations.md` для истории крупных изменений.

---
