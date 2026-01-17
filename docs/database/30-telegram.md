# Описание структуры базы данных KUDAB
## Схема `telegram` (2025)

Схема `telegram` хранит всё, что относится к Telegram-слою: Telegram-пользователи, привязанные чаты/каналы, настройки рассылок, очередь публикаций и шаблоны сообщений.

Связи с доменом (`public`):
- `telegram.users.user_id` → `public.users.id` (опциональная привязка аккаунта TG к доменному пользователю)
- `telegram.chats.city_id` → `public.cities.id` (город чата для подбора событий)
- `telegram.chat_broadcast_items.event_id` → `public.events.id` (какие события отправляем)

---

## 1. Список таблиц схемы `telegram`

- `telegram.users` — пользователи Telegram и привязка к доменным пользователям.
- `telegram.chats` — привязанные чаты/каналы (куда делаем рассылки).
- `telegram.chat_broadcasts` — настройки рассылки для конкретного чата.
- `telegram.chat_broadcast_items` — очередь/история отправок событий в чат.
- `telegram.message_templates` — шаблоны сообщений рассылки (текст + параметры картинок).

---

## 2. Таблица `telegram.users`

**Назначение:** учёт Telegram-пользователей, их базового профиля, привязки к доменному пользователю и предпочтений.

### Структура

| Поле               | Тип                                     | Описание                                                                 |
|--------------------|-----------------------------------------|--------------------------------------------------------------------------|
| id                 | bigint, PK (default sequence)           | Уникальный идентификатор записи.                                         |
| user_id            | bigint, FK → `public.users.id`          | ID доменного пользователя; `NULL`, если не привязан.                     |
| telegram_id        | bigint NOT NULL, UNIQUE                 | Уникальный идентификатор пользователя Telegram (`from.id`).              |
| telegram_username  | varchar(255)                            | `@username` (может отсутствовать/меняться).                              |
| first_name         | varchar(255)                            | Имя в Telegram.                                                          |
| last_name          | varchar(255)                            | Фамилия в Telegram.                                                      |
| language_code      | varchar(8)                              | Код языка, например `ru`, `en`, `en-US`.                                 |
| chat_id            | bigint                                  | ID приватного чата с пользователем (`chat.id`).                          |
| is_bot             | boolean DEFAULT false NOT NULL          | Флаг: является ли аккаунт ботом.                                         |
| registered_at      | timestamp(0) without time zone          | Когда пользователь впервые зафиксирован в системе.                       |
| last_active        | timestamp(0) without time zone          | Время последней активности пользователя.                                 |
| created_at         | timestamp(0) without time zone          | Дата создания записи.                                                    |
| updated_at         | timestamp(0) without time zone          | Дата последнего обновления записи.                                       |
| city_id            | bigint                                  | ID города из справочника `public.cities`; связь логическая, без FK.       |
| prefs              | jsonb DEFAULT '{}' NOT NULL             | JSON-настройки/предпочтения пользователя (фильтры, флаги и т.п.).         |

### Ограничения
- `PRIMARY KEY (id)`
- `UNIQUE (telegram_id)`  
  (в дампе два уникальных ограничения на `telegram_id`, по смыслу это одно и то же)
- `FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL`

### Индексы
- BTree по `telegram_id` — быстрый поиск по Telegram ID
- BTree по `user_id` — поиск по доменному пользователю
- BTree по `city_id` — выборки по городу

---

## 3. Таблица `telegram.chats`

**Назначение:** хранит привязанные чаты/каналы (группы/каналы), куда бот будет публиковать события.

### Структура

| Поле            | Тип                              | Описание                                                   |
|-----------------|----------------------------------|------------------------------------------------------------|
| id              | bigint, PK (default sequence)    | PK                                                         |
| telegram_user_id| bigint, FK → `telegram.users.id` | Владелец/инициатор привязки (кто привязал чат). Nullable. |
| telegram_chat_id| bigint NOT NULL, UNIQUE          | ID чата/канала в Telegram (`chat.id`).                     |
| chat_type       | varchar(32) NOT NULL             | Тип: `private`, `group`, `supergroup`, `channel`.          |
| title           | varchar(255)                     | Название чата/канала.                                      |
| username        | varchar(255)                     | `@username`, если есть.                                    |
| is_active       | boolean DEFAULT true NOT NULL    | Привязка активна.                                          |
| linked_at       | timestamp(0) without time zone   | Когда привязали.                                           |
| unlinked_at     | timestamp(0) without time zone   | Когда отвязали (если есть).                                |
| created_at      | timestamp(0) without time zone   |                                                            |
| updated_at      | timestamp(0) without time zone   |                                                            |
| city_id         | bigint, FK → `public.cities.id`  | Город, по которому подбираем события для рассылки. Nullable.|

### Ограничения
- `PRIMARY KEY (id)`
- `UNIQUE (telegram_chat_id)`
- `FOREIGN KEY (telegram_user_id) REFERENCES telegram.users(id) ON DELETE SET NULL`
- `FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE SET NULL`

### Индексы
- BTree по `(is_active, chat_type)` — быстрые выборки “какие активные каналы/группы”
- BTree по `telegram_user_id` — быстро найти чаты конкретного владельца

---

## 4. Таблица `telegram.chat_broadcasts`

**Назначение:** настройки рассылки для конкретного чата (1 запись на 1 чат).

Важно:
- Здесь хранится “включено/выключено” и `settings` (json) — например периодичность, выбранный шаблон, доп. параметры.

### Структура

| Поле           | Тип                              | Описание                                                   |
|----------------|----------------------------------|------------------------------------------------------------|
| id             | bigint, PK (default sequence)    |                                                            |
| chat_id        | bigint NOT NULL, FK → `telegram.chats.id` | Чат/канал, для которого настроена рассылка.         |
| enabled        | boolean DEFAULT false NOT NULL   | Включена ли рассылка для этого чата.                       |
| settings       | json                             | Настройки рассылки: `period`, `template_code` и т.п.        |
| last_run_at    | timestamp(0) without time zone   | Время последней фактической отправки в канал.               |
| last_preview_at| timestamp(0) without time zone   | Время последнего предпросмотра (например, в личку админа).  |
| created_at     | timestamp(0) without time zone   |                                                            |
| updated_at     | timestamp(0) without time zone   |                                                            |

### Ограничения
- `PRIMARY KEY (id)`
- `UNIQUE (chat_id)` — строго одна настройка рассылки на чат
- `FOREIGN KEY (chat_id) REFERENCES telegram.chats(id) ON DELETE CASCADE`

---

## 5. Таблица `telegram.chat_broadcast_items`

**Назначение:** очередь/история отправок. Каждая запись — “какое событие (`event_id`) отправляем по каким настройкам (`broadcast_id`)”.

Важно:
- Не даём дубли: UNIQUE (broadcast_id, event_id)
- Для планировщика/воркера есть индекс по `(status, planned_at)`
- В этой таблице timestamps **с timezone** (`with time zone`), в отличие от `chat_broadcasts/chats`.

### Структура

| Поле        | Тип                                   | Описание                                                  |
|-------------|----------------------------------------|-----------------------------------------------------------|
| id          | bigint, PK (default sequence)          | Primary key                                               |
| broadcast_id| bigint NOT NULL, FK → `telegram.chat_broadcasts.id` | Настройки рассылки для чата                         |
| event_id    | bigint NOT NULL, FK → `public.events.id` | Событие, которое планируем/опубликовали                 |
| status      | varchar(32) DEFAULT 'pending' NOT NULL | `pending/planned/posted/skipped/error`                    |
| planned_at  | timestamp(0) with time zone            | Когда планируется публикация                              |
| posted_at   | timestamp(0) with time zone            | Фактическое время отправки                                |
| error_message| text                                  | Последняя ошибка, если отправка не удалась                |
| created_at  | timestamp(0) with time zone            |                                                           |
| updated_at  | timestamp(0) with time zone            |                                                           |

### Ограничения
- `PRIMARY KEY (id)`
- `UNIQUE (broadcast_id, event_id)` — одно событие один раз в рамках одной рассылки
- `FOREIGN KEY (broadcast_id) REFERENCES telegram.chat_broadcasts(id) ON DELETE CASCADE`
- `FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE`

### Индексы
- BTree по `(status, planned_at)` — чтобы быстро выбирать “что отправлять сейчас”

---

## 6. Таблица `telegram.message_templates`

**Назначение:** шаблоны сообщений рассылки. Это “текст + параметры”, которые выбираются в настройках рассылки.

Важно:
- Уникальность по `(code, locale)` — один код на один язык.
- `body` — текст шаблона с плейсхолдерами (обычно HTML + `{title}`, `{start_time|human}` и т.п.).
- Можно выключать шаблоны через `is_active`.

### Структура

| Поле        | Тип                                   | Описание                                           |
|-------------|----------------------------------------|----------------------------------------------------|
| id          | bigint, PK (default sequence)          |                                                    |
| code        | varchar(64) NOT NULL                   | Системный код: `basic`, `brief`, `promo`…          |
| locale      | varchar(8) DEFAULT 'ru' NOT NULL       | Язык: `ru`, `en`…                                  |
| name        | varchar(255) NOT NULL                  | Человекочитаемое название (для админки)            |
| description | text                                   | Короткая подсказка/назначение                      |
| body        | text NOT NULL                          | Текст шаблона с плейсхолдерами                     |
| show_images | boolean DEFAULT true NOT NULL          | Показывать ли изображения                          |
| max_images  | smallint DEFAULT 3 NOT NULL            | Максимум изображений                               |
| is_active   | boolean DEFAULT true NOT NULL          | Можно ли выбирать этот шаблон                      |
| created_at  | timestamp(0) without time zone         |                                                    |
| updated_at  | timestamp(0) without time zone         |                                                    |

### Ограничения
- `PRIMARY KEY (id)`
- `UNIQUE (code, locale)`

---

## 7. Как это используется (коротко)

### Привязка канала/чата
1) Бот видит `telegram_chat_id` и создает/обновляет запись в `telegram.chats`.
2) Если пользователь “владелец” — кладём его в `telegram.chats.telegram_user_id`.
3) Устанавливаем `telegram.chats.city_id` (город чата для ленты/рассылки).
4) Создаём (или гарантируем наличие) `telegram.chat_broadcasts` для этого `chat_id`.

### Рассылка
1) В `telegram.chat_broadcasts.enabled=true` + `settings` (period/template_code/…).
2) Планировщик/воркер кладёт задачи в `telegram.chat_broadcast_items` (status `pending`/`planned`).
3) Отправка меняет `status` на `posted` или `error` и пишет `error_message`.

### Про город
- У `telegram.users.city_id` FK **нет** (логическая связь).
- У `telegram.chats.city_id` FK **есть** (`public.cities.id`, ON DELETE SET NULL).
