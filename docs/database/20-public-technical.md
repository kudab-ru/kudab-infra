### Пограничные

### `parsing_statuses`

Статусы парсинга по ссылкам.

| Поле                    | Тип                          | Описание                    |
|-------------------------|------------------------------|-----------------------------|
| id                      | bigint, PK                   |                             |
| community_social_link_id| bigint NOT NULL, FK → community_social_links.id |
| is_frozen               | boolean DEFAULT false NOT NULL | Заморожен ли источник    |
| frozen_reason           | varchar(64)                  | Причина заморозки           |
| unfreeze_at             | timestamp                    | Когда можно разморозить     |
| last_error              | text                         | Последняя ошибка            |
| last_error_code         | varchar(16)                  | Код ошибки                  |
| last_success_at         | timestamp                    | Последний успешный парсинг  |
| total_failures          | integer DEFAULT 0 NOT NULL   | Суммарные провалы           |
| retry_count             | integer DEFAULT 0 NOT NULL   | Кол-во ретраев              |
| created_at              | timestamp                    |                             |
| updated_at              | timestamp                    |                             |

### `error_logs`

Тех.логи.

| Поле                    | Тип                   | Описание                    |
|-------------------------|-----------------------|-----------------------------|
| id                      | bigint, PK            |                             |
| type                    | varchar(64) NOT NULL  | Тип ошибки/категория        |
| community_id            | bigint                | Логическая FK → communities |
| community_social_link_id| bigint                | Логическая FK → community_social_links |
| job                     | varchar(128)          | Имя задания                 |
| error_text              | text NOT NULL         | Текст ошибки                |
| error_code              | varchar(32)           | Код/HTTP и т.п.             |
| logged_at               | timestamp DEFAULT now() NOT NULL | Момент логирования |
| resolved                | boolean DEFAULT false NOT NULL | Закрыта ли ошибка     |
| meta                    | jsonb                 | Доп. структура              |
| created_at              | timestamp             |                             |
| updated_at              | timestamp             |                             |

### `llm_jobs`

Задачи для LLM.

| Поле          | Тип                                  | Описание                       |
|---------------|--------------------------------------|--------------------------------|
| id            | bigint, PK                           |                                |
| type          | varchar(32) DEFAULT 'chat' NOT NULL  | Тип задачи                     |
| status        | varchar(24) DEFAULT 'pending' NOT NULL | pending / done / error и т.п.|
| context_post_id| bigint, FK → context_posts.id       | Пост-источник (nullable)       |
| input         | jsonb                                | Входные данные                 |
| options       | jsonb                                | Настройки                      |
| result        | jsonb                                | Результат                      |
| error_code    | integer                              | Код ошибки                     |
| error_message | varchar(1024)                        | Сообщение ошибки               |
| started_at    | timestamp                            | Старт выполнения               |
| finished_at   | timestamp                            | Окончание                      |
| created_at    | timestamp                            |                                |
| updated_at    | timestamp                            |                                |


### Очереди (Laravel)

#### `jobs`

Основная очередь.

| Поле       | Тип               |
|------------|-------------------|
| id         | bigint, PK        |
| queue      | varchar(255)      |
| payload    | text              |
| attempts   | smallint          |
| reserved_at| integer           |
| available_at| integer          |
| created_at | integer           |

#### `job_batches`

Пакеты джобов.

| Поле        | Тип         |
|-------------|-------------|
| id          | varchar(255), PK |
| name        | varchar(255) |
| total_jobs  | integer     |
| pending_jobs| integer     |
| failed_jobs | integer     |
| failed_job_ids| text      |
| options     | text        |
| cancelled_at| integer     |
| created_at  | integer     |
| finished_at | integer     |

#### `failed_jobs`

Упавшие задачи.

| Поле      | Тип                |
|-----------|--------------------|
| id        | bigint, PK         |
| uuid      | varchar(255)       |
| connection| text               |
| queue     | text               |
| payload   | text               |
| exception | text               |
| failed_at | timestamp DEFAULT now() |

### Кэш

#### `cache`

| Поле      | Тип               |
|-----------|-------------------|
| key       | varchar(255), PK  |
| value     | text              |
| expiration| integer           |

#### `cache_locks`

| Поле      | Тип               |
|-----------|-------------------|
| key       | varchar(255), PK  |
| owner     | varchar(255)      |
| expiration| integer           |

### Миграции и сиды

#### `migrations`

| Поле     | Тип             |
|----------|-----------------|
| id       | integer, PK     |
| migration| varchar(255)    |
| batch    | integer         |

#### `seeders`

| Поле       | Тип             |
|------------|-----------------|
| id         | bigint, PK      |
| seeder_name| varchar(255)    |
| created_at | timestamp       |
| updated_at | timestamp       |

#### `alembic_version`

Для Alembic (Python-миграции).

| Поле       | Тип               |
|------------|-------------------|
| version_num| varchar(32), PK   |

### Токены и сессии

#### `personal_access_tokens` (Laravel Sanctum)

| Поле          | Тип                      | Описание                      |
|---------------|--------------------------|-------------------------------|
| id            | bigint, PK               |                               |
| tokenable_type| varchar(255) NOT NULL    | Модель-владелец токена       |
| tokenable_id  | bigint NOT NULL          | ID владельца                  |
| name          | text NOT NULL            | Название токена               |
| token         | varchar(64) NOT NULL     | Хэш токена                    |
| abilities     | text                     | JSON-строка с правами         |
| last_used_at  | timestamp                |                               |
| expires_at    | timestamp                |                               |
| created_at    | timestamp                |                               |
| updated_at    | timestamp                |                               |

#### `password_reset_tokens`

| Поле      | Тип                |
|-----------|--------------------|
| email     | varchar(255), PK   |
| token     | varchar(255)       |
| created_at| timestamp          |

#### `sessions`

Хранилище сессий Laravel.

| Поле        | Тип                |
|-------------|--------------------|
| id          | varchar(255), PK   |
| user_id     | bigint             |
| ip_address  | varchar(45)        |
| user_agent  | text               |
| payload     | text NOT NULL      |
| last_activity| integer NOT NULL  |

---