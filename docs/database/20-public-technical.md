# Описание структуры базы данных KUDAB — технические таблицы (схема `public`, 2025)

В этом файле — **технические** таблицы схемы `public`: статусы парсинга, инциденты/ошибки, LLM-джобы, права (Spatie), очереди/кэш Laravel, миграции/сиды, токены и сессии.

Доменные сущности (города/сообщества/посты/события/интересы) — в `database/10-public-domain.md`.  
Telegram-таблицы — в `database/30-telegram.md`.

---

## Группы таблиц

- Парсинг и инциденты: `parsing_statuses`, `error_logs`
- LLM/ML пайплайн: `llm_jobs`
- Роли и права (Spatie): `roles`, `permissions`, `role_has_permissions`, `model_has_roles`, `model_has_permissions`
- Очереди Laravel: `jobs`, `job_batches`, `failed_jobs`
- Кэш Laravel: `cache`, `cache_locks`
- Миграции и сиды: `migrations`, `seeders`, `alembic_version`
- Токены и сессии: `personal_access_tokens`, `password_reset_tokens`, `sessions`

---

## 1. Парсинг и инциденты

### `parsing_statuses`

Статус парсинга по каждой ссылке-источнику (`community_social_links`): заморозка, ошибки, ретраи.

Важно:
- **1 запись на 1 ссылку**: UNIQUE (`community_social_link_id`)
- FK: `community_social_link_id` → `community_social_links.id` (ON DELETE CASCADE)
- Индекс: (`is_frozen`, `unfreeze_at`) — удобно “кого пора разморозить”.

| Поле                    | Тип                               | Описание |
|-------------------------|------------------------------------|----------|
| id                      | bigint, PK                         |          |
| community_social_link_id| bigint NOT NULL, FK → community_social_links.id | Источник парсинга |
| is_frozen               | boolean DEFAULT false NOT NULL     | Заморожен ли источник |
| frozen_reason           | varchar(64)                        | Причина: rate_limit/ban/captcha/error/manual |
| unfreeze_at             | timestamp(0) without time zone     | Когда можно/нужно разморозить |
| last_error              | text                               | Последняя ошибка (текст) |
| last_error_code         | varchar(16)                        | Код ошибки (429/403/timeout/…) |
| last_success_at         | timestamp(0) without time zone     | Последний успешный парсинг |
| total_failures          | integer DEFAULT 0 NOT NULL         | Неудач подряд (после успеха) |
| retry_count             | integer DEFAULT 0 NOT NULL         | Количество ретраев подряд |
| created_at              | timestamp(0) without time zone     |          |
| updated_at              | timestamp(0) without time zone     |          |

---

### `error_logs`

Технический лог ошибок/инцидентов (с контекстом). Используется для наблюдения и дебага.

Важно:
- `community_id` и `community_social_link_id` — **логические связи** (FK в дампе нет).
- Индексы: по `type`, `job`, `community_id`, `community_social_link_id`, и составной (`type`, `job`).

| Поле                    | Тип                                                | Описание |
|-------------------------|----------------------------------------------------|----------|
| id                      | bigint, PK                                         |          |
| type                    | varchar(64) NOT NULL                               | Категория: vk_api/job_error/frozen/ml_error/… |
| community_id            | bigint                                             | Логическая ссылка на `communities.id` |
| community_social_link_id| bigint                                             | Логическая ссылка на `community_social_links.id` |
| job                     | varchar(128)                                       | Класс/имя задания, где упало |
| error_text              | text NOT NULL                                      | Текст ошибки |
| error_code              | varchar(32)                                        | Код ошибки (если есть) |
| logged_at               | timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL | Время записи |
| resolved                | boolean DEFAULT false NOT NULL                     | Ошибка закрыта/неактуальна |
| meta                    | jsonb                                              | Доп. контекст (json) |
| created_at              | timestamp(0) without time zone                     |          |
| updated_at              | timestamp(0) without time zone                     |          |

---

## 2. LLM / ML пайплайн

### `llm_jobs`

Очередь/история LLM-задач (например, извлечение событий из `context_posts`).

Важно:
- FK: `context_post_id` → `context_posts.id` (ON DELETE SET NULL)
- Индексы:
    - (`status`, `created_at`) — “что сейчас в каком статусе”
    - `retry_at` — “что пора перезапускать”
    - `task` и `prompt_version` — удобно фильтровать
- Уникальный индекс (частичный): (`context_post_id`, `task`, `prompt_version`) WHERE все три не NULL  
  Это защита от дублей одного и того же запуска на один пост.

| Поле           | Тип                                     | Описание |
|----------------|------------------------------------------|----------|
| id             | bigint, PK                               |          |
| type           | varchar(32) DEFAULT 'chat' NOT NULL      | Тип задачи (условно “чат/прочее”) |
| status         | varchar(24) DEFAULT 'pending' NOT NULL   | pending / completed / error / … |
| context_post_id| bigint, FK → context_posts.id            | Пост-источник (nullable) |
| task           | varchar(64)                              | Имя задачи (например `events_extract`) |
| prompt_version | varchar(32)                              | Версия промпта (строкой) |
| input          | jsonb                                    | Входные данные |
| options        | jsonb                                    | Настройки |
| result         | jsonb                                    | Результат |
| error_code     | integer                                  | Код ошибки |
| error_message  | varchar(1024)                            | Сообщение ошибки |
| started_at     | timestamp(0) without time zone           | Старт выполнения |
| finished_at    | timestamp(0) without time zone           | Окончание |
| attempt        | smallint DEFAULT 0 NOT NULL              | Номер попытки |
| retry_at       | timestamp(0) with time zone              | Когда можно повторить |
| created_at     | timestamp(0) without time zone           |          |
| updated_at     | timestamp(0) without time zone           |          |

---

## 3. Роли и права (Spatie)

### `roles`

Справочник ролей.

Важно:
- UNIQUE (`name`, `guard_name`)

| Поле       | Тип                               | Описание |
|------------|------------------------------------|----------|
| id         | bigint, PK                         |          |
| name       | varchar(255) NOT NULL              | Название роли |
| guard_name | varchar(255) NOT NULL              | Guard (обычно `web`) |
| created_at | timestamp(0) without time zone     |          |
| updated_at | timestamp(0) without time zone     |          |

---

### `permissions`

Справочник прав.

Важно:
- UNIQUE (`name`, `guard_name`)

| Поле       | Тип                               | Описание |
|------------|------------------------------------|----------|
| id         | bigint, PK                         |          |
| name       | varchar(255) NOT NULL              | Имя права |
| guard_name | varchar(255) NOT NULL              | Guard |
| created_at | timestamp(0) without time zone     |          |
| updated_at | timestamp(0) without time zone     |          |

---

### `role_has_permissions`

Связь многие-ко-многим: роли ↔ права.

Важно:
- PK составной: (`permission_id`, `role_id`)
- FK:
    - `permission_id` → `permissions.id` (ON DELETE CASCADE)
    - `role_id` → `roles.id` (ON DELETE CASCADE)

| Поле          | Тип                       | Описание |
|---------------|---------------------------|----------|
| permission_id | bigint NOT NULL, FK → permissions.id |          |
| role_id       | bigint NOT NULL, FK → roles.id       |          |

---

### `model_has_roles`

Роли на моделях (обычно `users`).

Важно:
- PK: (`role_id`, `model_id`, `model_type`)
- Индекс: (`model_id`, `model_type`)
- FK: `role_id` → `roles.id` (ON DELETE CASCADE)

| Поле       | Тип                          | Описание |
|------------|------------------------------|----------|
| role_id    | bigint NOT NULL, FK → roles.id |          |
| model_type | varchar(255) NOT NULL        | Тип модели (например `App\\Models\\User`) |
| model_id   | bigint NOT NULL              | ID модели |

---

### `model_has_permissions`

Права на моделях.

Важно:
- PK: (`permission_id`, `model_id`, `model_type`)
- Индекс: (`model_id`, `model_type`)
- FK: `permission_id` → `permissions.id` (ON DELETE CASCADE)

| Поле          | Тип                              | Описание |
|---------------|----------------------------------|----------|
| permission_id | bigint NOT NULL, FK → permissions.id |          |
| model_type    | varchar(255) NOT NULL            | Тип модели |
| model_id      | bigint NOT NULL                  | ID модели |

---

## 4. Очереди (Laravel)

### `jobs`

Основная очередь задач.

Важно:
- `created_at/available_at/reserved_at` — **integer** (обычно unix time).
- Индекс: `jobs_queue_index` по `queue`.

| Поле        | Тип                        | Описание |
|-------------|----------------------------|----------|
| id          | bigint, PK                 |          |
| queue       | varchar(255) NOT NULL      | Имя очереди |
| payload     | text NOT NULL              | Полезная нагрузка |
| attempts    | smallint NOT NULL          | Попытки |
| reserved_at | integer                    | Когда взяли в работу |
| available_at| integer NOT NULL           | Когда доступно |
| created_at  | integer NOT NULL           | Когда создано |

---

### `job_batches`

Пакеты задач (Laravel batches).

| Поле          | Тип                    | Описание |
|---------------|------------------------|----------|
| id            | varchar(255), PK       | ID батча |
| name          | varchar(255) NOT NULL  | Имя батча |
| total_jobs    | integer NOT NULL       | Всего задач |
| pending_jobs  | integer NOT NULL       | Ожидают |
| failed_jobs   | integer NOT NULL       | Упали |
| failed_job_ids| text NOT NULL          | Список id упавших |
| options       | text                   | Опции (json/текст) |
| cancelled_at  | integer                | Когда отменили |
| created_at    | integer NOT NULL       | Когда создали |
| finished_at   | integer                | Когда завершили |

---

### `failed_jobs`

Упавшие задания очереди.

Важно:
- UNIQUE (`uuid`)

| Поле      | Тип                                                | Описание |
|-----------|-----------------------------------------------------|----------|
| id        | bigint, PK                                          |          |
| uuid      | varchar(255) NOT NULL, UNIQUE                       | UUID джобы |
| connection| text NOT NULL                                       | Соединение |
| queue     | text NOT NULL                                       | Очередь |
| payload   | text NOT NULL                                       | Payload |
| exception | text NOT NULL                                       | Исключение |
| failed_at | timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL | Когда упало |

---

## 5. Кэш (Laravel)

### `cache`

| Поле       | Тип                      | Описание |
|------------|--------------------------|----------|
| key        | varchar(255), PK         | Ключ |
| value      | text NOT NULL            | Значение |
| expiration | integer NOT NULL         | Время истечения (unix time) |

---

### `cache_locks`

| Поле       | Тип                      | Описание |
|------------|--------------------------|----------|
| key        | varchar(255), PK         | Ключ |
| owner      | varchar(255) NOT NULL    | Владелец лока |
| expiration | integer NOT NULL         | Истечение (unix time) |

---

## 6. Миграции и сиды

### `migrations`

Список применённых миграций Laravel.

| Поле      | Тип                       | Описание |
|-----------|---------------------------|----------|
| id        | integer, PK               |          |
| migration | varchar(255) NOT NULL     | Имя миграции |
| batch     | integer NOT NULL          | Номер батча |

---

### `seeders`

Список применённых сидеров.

Важно:
- UNIQUE (`seeder_name`)

| Поле        | Тип                               | Описание |
|-------------|------------------------------------|----------|
| id          | bigint, PK                         |          |
| seeder_name | varchar(255) NOT NULL, UNIQUE      | Имя сидера |
| created_at  | timestamp(0) without time zone     |          |
| updated_at  | timestamp(0) without time zone     |          |

---

### `alembic_version`

След Alembic (Python-миграции). Обычно это “какая версия схемы применена” для python-части.

| Поле       | Тип                         | Описание |
|------------|-----------------------------|----------|
| version_num| varchar(32), PK             | Версия Alembic |

---

## 7. Токены и сессии

### `personal_access_tokens` (Laravel Sanctum)

API-токены (личные токены доступа).

Важно:
- UNIQUE (`token`)
- Индекс: (`tokenable_type`, `tokenable_id`)

| Поле          | Тип                               | Описание |
|---------------|------------------------------------|----------|
| id            | bigint, PK                         |          |
| tokenable_type| varchar(255) NOT NULL              | Модель-владелец токена |
| tokenable_id  | bigint NOT NULL                    | ID владельца |
| name          | text NOT NULL                      | Название токена |
| token         | varchar(64) NOT NULL, UNIQUE       | Хэш токена |
| abilities     | text                               | Права (обычно json строкой) |
| last_used_at  | timestamp(0) without time zone     | Последнее использование |
| expires_at    | timestamp(0) without time zone     | Истекает (если задано) |
| created_at    | timestamp(0) without time zone     |          |
| updated_at    | timestamp(0) without time zone     |          |

---

### `password_reset_tokens`

Токены сброса пароля.

Важно:
- PK: `email`

| Поле      | Тип                               | Описание |
|-----------|------------------------------------|----------|
| email     | varchar(255), PK                   | Email |
| token     | varchar(255) NOT NULL              | Токен |
| created_at| timestamp(0) without time zone     | Когда создан |

---

### `sessions`

Сессии Laravel (если используется драйвер БД).

Важно:
- Индексы: `user_id`, `last_activity`

| Поле         | Тип                 | Описание |
|--------------|---------------------|----------|
| id           | varchar(255), PK    | ID сессии |
| user_id      | bigint              | Пользователь (nullable) |
| ip_address   | varchar(45)         | IP |
| user_agent   | text                | User-Agent |
| payload      | text NOT NULL       | Данные сессии |
| last_activity| integer NOT NULL    | Последняя активность (unix time) |

---
