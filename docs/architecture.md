#### ARCHITECTURE OVERVIEW

Проект **kudab.ru** — агрегатор событий и платформенный сервис с интеграцией Telegram, VK, внешних сайтов.  
Вся архитектура построена по принципу сервис-ориентированности с использованием Docker, CI/CD, единого API и универсальных связей.  
**Нет отдельного мобильного приложения:** только PWA (web) и Telegram-интерфейсы.

---

#### СХЕМА ВЗАИМОДЕЙСТВИЯ СЕРВИСОВ

![mermaid-diagram-2025-07-06-235529.png](source/mermaid-diagram-2025-07-06-235529.png)

```shell

```

---

#### СЕРВИСЫ И МИКРОСЕРВИСЫ

| Сервис         | Назначение                                      | Стек / Особенности              |
| -------------- | ----------------------------------------------- | ------------------------------- |
| kudab-infra    | meta-репозиторий, docker compose, Makefile      | Docker Compose, git submodules  |
| kudab-api      | Backend API, бизнес-логика, права, статусы      | Laravel, PHP, PostgreSQL        |
| kudab-frontend | Web-интерфейс и страницы проекта                | Nuxt 3, Vue 3, Tailwind         |
| kudab-bot      | Telegram-бот, панели и пользовательские сценарии| Python, aiogram, httpx          |
| kudab-parser   | Команды парсинга, enqueue, verify, extract      | Laravel/PHP CLI                 |
| kudab-horizon  | Очереди, LLM jobs, consume                      | Laravel Horizon                 |
| kudab-nginx    | Reverse proxy и точка входа                     | Nginx                           |
| kudab-db       | Основная база данных                            | PostgreSQL                      |
| kudab-redis    | Очереди, кэш, служебное состояние               | Redis                           |

---

#### СТЕК ТЕХНОЛОГИЙ

- Backend: Laravel 12 (PHP 8.2), PostgreSQL 15+
- Frontend: Nuxt.js 3 (Vue 3, SSR, PWA), Tailwind CSS
- Bot: Python 3.11, aiogram 3.x, httpx
- Infrastructure: Docker Compose, NGINX, Redis, PostgreSQL, Makefile, при необходимости CI/CD

---

#### ВЗАИМОДЕЙСТВИЕ И ПОТОК ДАННЫХ

1. Пользователь открывает сайт или Telegram-бот.
2. Веб-запросы проходят через Nginx во frontend и API.
3. Frontend и бот работают поверх API; бизнес-логика и проверки находятся в API.
4. Parser enqueue'ит источники и собирает `context_posts`.
5. Команды verify уточняют сообщество, город и привязки.
6. `parser:events:extract` создаёт `llm_jobs` на извлечение событий.
7. Очереди и Horizon обрабатывают `llm_jobs`.
8. Consume переносит результат в `events`.
9. Дополнительно выполняется обслуживание групп событий: relink, index, prune, check.

---

#### ПРИНЦИПЫ АРХИТЕКТУРЫ

- Сервисная структура: каждый компонент можно обновлять/заменять отдельно.
- Единая точка входа (Nginx).
- Вся логика доступа и данных — через API.
- Универсальные morphTo-связи в БД: parent_type/parent_id для расширяемых таблиц (attachments, interest_links и др.).
- Использование Docker для каждого сервиса — быстрый деплой и масштабирование.
- Конфигурирование через .env для каждого сервиса.
- Ориентация на автоматизацию и работу с минимальным количеством ручных действий.

---

#### ДОПОЛНИТЕЛЬНО

- docs/db-schema.md — подробная структура БД (markdown, пояснения)
- docs/database.dbml — визуальная ER-схема для dbdiagram.io
- docs/api.md — описание API (методы, сценарии, спецификация)
- docs/bot.md — сценарии Telegram-бота, команды, flow
- docs/setup.md — инструкция по развёртыванию окружения

---

#### СХЕМА ВНУТРЕННЕЙ СВЯЗИ В БАЗЕ (упрощённо)

```
Table users { ... }
Table telegram_users { ... }
Table interests { ... }
Table events { ... }
Table context_posts { ... }
Table attachments { ... }
Table event_attendees { ... }
Table interest_links { ... }
```

---

#### СПЕЦИФИКА ПЛАТФОРМЫ

- Всё, что касается мобильных устройств — реализовано через адаптивный PWA и Telegram-бот (нет отдельного приложения).
- Экспорт событий в календари поддерживается во frontend и через бота.
- Система “Пойду”/“Избранное” — главный способ отклика на событие, “лайки” не используются.
- Добавление событий: автоматический парсинг и ручное добавление организаторами (после модерации).

---
