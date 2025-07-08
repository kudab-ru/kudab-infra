#### SPRINT PLAN: kudab.ru (июль–октябрь 2025, расширенная версия)

---

### DevOps / Инфраструктура (ВЫСОКИЙ ПРИОРИТЕТ)

| Статус       | Задача                                                     | Исполнитель        | ETA / Дедлайн      | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Dockerfile для каждого сервиса (api, parser, bot, publisher)| DevOps/Backend     | ASAP               | Production & dev, alpine          |
| Planned      | docker-compose.dev.yml: hotreload, volume-mount, logs      | DevOps             | ASAP               | Для быстрой локальной работы      |
| Planned      | docker-compose.prod.yml: production ready                  | DevOps             | ASAP               | Только нужные сервисы, no-dev     |
| Planned      | GitHub Actions: CI для каждого сервиса                     | DevOps             | ASAP               | Линтинг, тесты, build             |
| Planned      | GitHub Actions: CD/deploy на VNS                           | DevOps             | ASAP               | Deploy scripts, auto-restart      |
| Planned      | Перенос .env.example и secrets в CI                        | DevOps             | ASAP               | GitHub Secrets, безопасно         |
| Planned      | Healthcheck для каждого контейнера                         | DevOps             | ASAP               | Проверка аптайма                  |
| Planned      | Monitoring: uptime-kuma, basic Grafana/Sentry              | DevOps             | Q3 2025            | Минимальный мониторинг            |
| Planned      | Инструкция: setup.md, setup-prod.md                        | DevOps + Docs      | ASAP               | Пошаговая, для новичков           |

---

### Backend / База данных

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Проектирование ER-схемы в dbml/dbdiagram.io                | Backend + Docs     | ASAP               | Основа для миграций и docs        |
| Planned      | Миграции для users, telegram_users, interests, events, etc | Backend            | ASAP               | Все FK, индексы, soft-deletes     |
| Planned      | Сидирование мок-данных                                     | Backend + Student  | ASAP               | Для dev/test окружения            |
| Planned      | Создание стартовой структуры API (Laravel, /api/events)    | Backend            | ASAP               | Версионирование, openapi          |
| Planned      | JWT Auth + Telegram Auth                                   | Backend            | ASAP               | Авторизация с двух сторон         |
| Planned      | CRUD для основных сущностей (events, interests, communities)| Backend           | ASAP               |                                   |
| Planned      | Поддержка фильтрации, пагинации, сортировки                | Backend            | Q3 2025            | Для фронта/бота                   |
| Planned      | Экспорт событий в календари (iCal, Google, Yandex)         | Backend            | Q3 2025            | API endpoint                      |
| Planned      | Webhooks для publisher и бота                              | Backend            | Q3 2025            | Для автоматизации                 |
| Planned      | Rate limiting и логирование ошибок                         | Backend            | Q3 2025            | Безопасность и анализ             |
| Planned      | Миграции: автоматизация, откат, ревью                      | Backend + Student  | Q3 2025            | Документировать в migrations.md   |
| Planned      | Документация по API, ER-диаграмме, миграциям               | Backend + Student  | Q3 2025            | Поддержка в актуальном состоянии  |

---

### Parser / Интеграции

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Прототип парсера VK (события, посты, ссылки)               | Dev 1              | ASAP               | MVP: только события, только тестовый аккаунт |
| Planned      | Прототип парсера Telegram (каналы, афиши, события)         | Dev 1              | Q3 2025            | MVP: несколько каналов, простая логика       |
| Planned      | Парсер сайтов (RSS, iCal, афиши городов)                   | Dev 1              | Q3-Q4 2025         | Долгосрочно, добавить позже                  |
| Planned      | Настройка hotreload (watchdog, entr)                       | Dev 1              | ASAP               | Для dev                                       |
| Planned      | Интеграция парсера с api (POST /api/events/propose)        | Dev 1 + Dev 2      | ASAP               | Через REST                                    |
| Planned      | Логирование ошибок парсера                                 | Dev 1              | Q3 2025            | Лог-файлы, отправка алертов                   |
| Planned      | Документация по парсеру, API-контракт                      | Dev 1 + Student    | Q3 2025            | docs/parser.md, примеры                       |
| Planned      | Демонстрация работы через test script или endpoint         | Dev 1 + QA         | Q3 2025            | Для командных демонстраций                    |

---

### Bot & Publisher

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Telegram-бот: сценарии /start, /events, /favorite, /add_event | Dev 2           | ASAP               | aiogram 3.x, интеграция с api     |
| Planned      | Обработка ошибок, стандартизация ответов                   | Dev 2              | ASAP               | Показ ошибок, логгирование        |
| Planned      | Publisher: MVP рассылки в Telegram-каналы                  | Dev 2              | Q3 2025            | Отправка новых событий            |
| Planned      | Логика фильтрации и расписания в publisher                 | Dev 2              | Q3 2025            | apscheduler, cron                 |
| Planned      | Горячая перезагрузка (hotreload) для бота/publisher        | Dev 2              | ASAP               | Uvicorn --reload, watchdog        |
| Planned      | Документация: команды, настройки, deployment               | Dev 2 + Student    | Q3 2025            | bot.md, publisher.md              |
| Planned      | Юзер-стори: “Пойду” и “Избранное” через бота               | Dev 2              | Q3 2025            | В связке с API и Telegram         |
| Planned      | Поддержка тестирования сценариев                           | QA + Student       | Q3 2025            | Тест-кейсы                        |

---

### Frontend / UI / PWA

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Минимальная PWA-шелл (Nuxt.js, SSR, авторизация, афиша)    | Frontend           | Q3 2025            | Только то, что требует теста      |
| Planned      | “Пойду”/“Избранное” в интерфейсе (UI для бота + web)       | Frontend           | Q3-Q4 2025         | Через API и фронт                 |
| Planned      | Кнопки “Добавить в календарь” (экспорт)                    | Frontend           | Q4 2025            | Google/Яндекс/ICS                 |
| Planned      | Прототип формы ручного добавления события                  | Frontend           | Q4 2025            | В связке с API                    |
| Planned      | Документация: базовый UI-кит, структура страниц            | Frontend + Docs    | Q4 2025            | Для расширения                    |
| Planned      | Push/web-push: базовая интеграция                          | Frontend           | Q4 2025            | PWA                               |

---

### Docs / Тестирование / Support

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Полное обновление setup.md, architecture.md, bot.md        | Student + All      | ASAP               | Для новых разработчиков           |
| Planned      | Подготовка тест-кейсов для api, parser, bot                | Student + QA       | Q3 2025            | Для ручного и автотестирования    |
| Planned      | Создание примеров запросов и ответов по API                | Student + Backend  | Q3 2025            | Для Swagger/OpenAPI               |
| Planned      | Миграции и история изменений (migrations.md, changelog)    | Backend + Docs     | Q3 2025            | Ведется постоянно                 |
| Planned      | Ответы на фидбек, обновление user stories                  | Student            | Q3-Q4 2025         | Support, research                 |
| Planned      | Поддержка Notion или Confluence, если команда растёт       | Student + PM       | Q4 2025            | Сквозная документация             |

---

### Business / Analytics

| Статус       | Задача                                                     | Исполнитель        | ETA                | Примечания                        |
|--------------|------------------------------------------------------------|--------------------|--------------------|-----------------------------------|
| Planned      | Сбор требований от партнеров (афиши, города, туризм)       | PM + BA            | Q3-Q4 2025         | Интеграции, UX-интервью           |
| Planned      | Оценка спроса на B2B API                                   | BA                 | Q4 2025            | Варианты платных тарифов          |
| Planned      | Сценарии запуска: MVP, beta, сбор обратной связи           | PM                 | Q3-Q4 2025         | Подготовка и корректировки        |
| Planned      | Подготовка первого demo для бета-пользователей             | Все                | Q4 2025            | Invite only                       |
| Planned      | Финальная аналитика и дашборд (Grafana, ClickHouse)        | DevOps + Analyst   | Q4 2025            | По мере масштабирования           |

---

### VNS / ПРОДАКШН ИНФРАСТРУКТУРА

| Задача                                               | Исполнитель  | Категория       | ETA   |
|------------------------------------------------------|--------------|-----------------|-------|
| Подбор и заказ VNS                                   | DevOps/PM    | Infra/Business  | ASAP  |
| Настройка ssh-доступа, firewall, fail2ban            | DevOps       | Infra/Security  | ASAP  |
| Развёртывание docker-compose.prod на VNS             | DevOps       | Infra           | ASAP  |
| Перенос и настройка production .env                  | DevOps       | Infra/Security  | ASAP  |
| CI/CD: автоматизация деплоя на VNS (GitHub Actions)  | DevOps       | CI/CD/Infra     | ASAP  |
| Настройка логов, лог-ротации, мониторинга            | DevOps       | Infra/Monitoring| ASAP  |
| Бэкапы БД и restore-скрипт (cron, тест восстановления)| DevOps      | Infra/Backup    | ASAP  |
| Автоматизация SSL (Let's Encrypt/ZeroSSL)            | DevOps       | Infra/Security  | Q3    |
| Healthcheck endpoints для всех сервисов              | DevOps       | Infra           | Q3    |
| Документация по продакшн-деплою                      | DevOps+Docs  | Docs            | ASAP  |

---

### ДИЗАЙН / КОНТЕНТ / UI / ГРАФИКА

| Задача                                               | Исполнитель   | Категория       | ETA   |
|------------------------------------------------------|---------------|-----------------|-------|
| Аватарки, эмодзи для типов событий, меток            | Дизайнер      | UI/Emoji        | ASAP  |
| Набор кастомных эмодзи для рассылок/бота/ТГК         | Дизайнер      | UI/Emoji        | ASAP  |
| Базовые стикеры (развивать пак)                      | Дизайнер      | Content/Sticker | Q3    |
| Анимация логотипа, favicon, PWA-иконки               | Дизайнер      | UI/Animation    | Q3    |
| Прототипирование меню и сообщений для Telegram-бота  | Дизайнер      | UX/Bot          | ASAP  |
| Иллюстрации/обложки для рассылок в каналы            | Дизайнер      | UI/Content      | Q3    |
| Микро-анимации для интерфейса (web/PWA)              | Дизайнер      | UI/Animation    | Q3    |
| Визуализация статистики и достижений (баджи, трофеи) | Дизайнер      | UI/Gamification | Q4    |
| Figma: макеты главных экранов (афиша, профиль, event)| Дизайнер      | UI/UX           | Q3    |
| Визуальное оформление профилей сообществ              | Дизайнер      | UI              | Q3    |
| Адаптация графики под PWA и Telegram                  | Дизайнер      | UI              | Q3    |
| Справочник эмодзи, описание где какие использовать   | Дизайнер+Docs | Docs/UI         | Q3    |

---

### БИЗНЕС-АНАЛИТИК / МЕНЕДЖЕР

| Задача                                               | Исполнитель      | Категория      | ETA   |
|------------------------------------------------------|------------------|----------------|-------|
| Анализ потребностей партнеров и каналов              | BA/PM            | Business       | Q3    |
| Сценарии для бота, рассылок, onboarding              | BA/PM+Дизайнер   | UX/BA          | Q3    |
| Подготовка метрик, KPI, аналитики для продукта       | BA/PM            | Analytics      | Q3    |
| Конкурентный анализ (Telegram, PWA-решения, афиши)   | BA/PM+Student    | Research       | Q3    |
| Подготовка партнерских оферт, шаблонов документов    | BA/PM            | Legal/Docs     | Q3    |
| Анализ запросов пользователей, сбор фидбека          | BA/PM+Student    | Support        | Q3    |
| Организация пилотных интеграций с городскими афишами | BA/PM            | Integrations   | Q4    |
| Документация бизнес-процессов (business.md, roadmap) | BA/PM+Docs       | Docs           | Q3    |
| Настройка и ревизия бэклога задач                    | BA/PM            | Planning       | Q3-Q4 |
| Разработка/утверждение SMM-стратегии (TGK, партнеры) | BA/PM+Дизайнер   | Marketing      | Q4    |

---

### РАЗРАБОТЧИКИ / API / PARSER / BOT / QA

| Задача                                               | Исполнитель      | Категория      | ETA   |
|------------------------------------------------------|------------------|----------------|-------|
| ... (см. предыдущие спринты!)                        |                  |                |       |

*(Все задачи из предыдущей таблицы по DevOps, API, parser, bot, publisher, QA, frontend полностью остаются!  
Это только дополнения для VNS, дизайна и бизнеса.)*

---

### ДОПОЛНИТЕЛЬНО

- Каждая задача дизайнера/BA легко превращается в epic/feature в таск-трекере или на wiki.
- Если появятся уникальные задачи (например, генерация эмодзи ИИ, геймификация профилей, адаптация под новые Telegram-форматы), заводи новые карточки!
- Все готовые эмодзи и стикеры собирай в отдельную папку/ресурс, обновляй справочник.

---

**Могу разбить все задачи ещё подробнее или расписать по конкретным датам, прикрепить шаблоны для эмодзи, задач на ревью и т.п.  
Если нужен markdown-реестр для эмодзи/стикеров, чек-лист для BA/дизайнера, шаблон бизнес-метрик, дай команду — всё подготовлю!**

---

### Спринт 1: Инфра, старт парсера, дизайн-основа, бизнес-аналитика (2 недели)

| Задача                                                        | Исполнитель       | Категория          |
|---------------------------------------------------------------|-------------------|--------------------|
| Заказ и настройка VNS, ssh, firewall, fail2ban                | DevOps            | Infra/Security     |
| Развёртывание docker-compose.prod на VNS, .env, деплой         | DevOps            | Infra/Deploy       |
| Dockerfile, docker-compose.dev с hotreload для всех сервисов   | DevOps            | Infra/Dev          |
| CI/CD (GitHub Actions): build/test/deploy для каждого сервиса  | DevOps            | CI/CD              |
| Миграции БД (users, telegram_users, events, interests)         | Backend           | DB                 |
| Сидирование мок-данных и тестовые данные                       | Backend+Student   | DB/QA              |
| Первые Figma-макеты: афиша, карточка события, профиль          | Дизайнер          | UI/UX              |
| Эмодзи для типов событий, тестовый набор стикеров              | Дизайнер          | UI/Emoji           |
| Подготовка ER-схемы БД (dbml/dbdiagram)                        | Backend+Student   | DB/Docs            |
| Сценарии для бота и каналов, базовый roadmap                   | BA/PM             | BA/Planning        |
| Анализ конкурентов и каналов, сбор референсов                  | BA/PM+Student     | BA/Research        |
| Документация по запуску и прод-деплою                          | DevOps+Student    | Docs/Infra         |

---

### Спринт 2: API, MVP-парсер, Telegram-бот, дизайн Telegram, бизнес-процессы (2 недели)

| Задача                                                        | Исполнитель       | Категория          |
|---------------------------------------------------------------|-------------------|--------------------|
| MVP-парсер VK/Telegram: парсинг событий, публикация в API      | Dev 1             | Parser             |
| Интеграция парсера с /api/events/propose                       | Dev 1+Dev 2       | Parser/API         |
| Запуск MVP API (Laravel): CRUD для events, interests, users    | Dev 2             | Backend/API        |
| JWT и Telegram Auth в API                                      | Dev 2             | Auth               |
| Telegram-бот: /start, /events, /favorite, /add_event           | Dev 2             | Bot                |
| Прототип фильтрации событий в API и боте                       | Dev 2             | Backend/Bot        |
| Кастомизация меню бота (иллюстрации, эмодзи, стикеры)          | Дизайнер          | UI/Bot             |
| Иллюстрации/обложки для рассылок, визуал Telegram-каналов      | Дизайнер          | UI/Content         |
| Финализация ER-схемы, ревью миграций                           | Backend+Student   | DB/Docs            |
| Сценарии рассылок и логики publisher, draft рассылки           | BA/PM             | BA/Publisher       |
| Анализ метрик и требований по аналитике                        | BA/PM             | Analytics          |
| Документация: api.md, parser.md, bot.md, инфра                 | Student           | Docs               |

---

### Спринт 3: Publisher, расширение парсера, UI-графика, бизнес-документы (2 недели)

| Задача                                                        | Исполнитель       | Категория          |
|---------------------------------------------------------------|-------------------|--------------------|
| Publisher MVP: авторассылка событий в Telegram-каналы          | Dev 2             | Publisher          |
| Расширение парсера: новые источники (сайты, open data)         | Dev 1             | Parser             |
| Интеграция publisher с API и логирование                       | Dev 2             | Publisher/API      |
| Продвинутые фильтры/шаблоны для рассылок                       | Dev 2             | Publisher          |
| Логика модерации событий в API                                 | Backend           | Backend/API        |
| Миграции: индексы, soft delete, история изменений              | Backend           | DB                 |
| Новые эмодзи для событий, визуальные баджи и достижения        | Дизайнер          | UI/Emoji/Gamification |
| Анимации лого, оформление профиля, графика для Telegram        | Дизайнер          | UI/Animation       |
| Анализ фидбека, корректировка roadmap, приоритезация           | BA/PM             | BA/Planning        |
| Подготовка бизнес-оферт, шаблонов документов                   | BA/PM             | Business/Legal     |
| Документация: business.md, roadmap.md, setup.md                | Student           | Docs               |
| Тест-кейсы по рассылкам и парсеру, базовый QA                  | Student           | QA                 |

---

#### Примечания:
- **Dev 1**: парсер, интеграции, бэкенд
- **Dev 2**: API, Telegram-бот, publisher
- **Дизайнер**: UI, эмодзи, стикеры, графика для TG, анимация
- **BA/PM**: сценарии, метрики, аналитика, roadmap, оферты
- **Student**: тесты, документация, саппорт, подготовка данных, помощь где нужно
- Все задачи про VNS и прод-инфру отдельно и приоритетно в Спринте 1!
- Новые задачи добавляй по итогам фидбека, ретроспектив и запросов пользователей

---

# Еще вариант

---

### Спринт 1: Инфраструктура и фундамент (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| Dockerfile для всех сервисов (api, parser, bot, publisher) | DevOps/Backend   | Infra/DevOps  |
| docker-compose.dev с hotreload, volume, логами             | DevOps           | Infra/DevOps  |
| docker-compose.prod для VNS                                | DevOps           | Infra/DevOps  |
| CI (GitHub Actions): build, тесты, publish для всех сервисов| DevOps           | Infra/CI      |
| Инструкция по запуску окружения (setup.md)                 | DevOps + Docs    | Docs/Infra    |
| Миграции БД: users, telegram_users, interests, events      | Backend          | DB            |
| Сидирование мок-данных                                     | Backend/Student  | DB/QA         |
| ER-схема БД: dbml/dbdiagram, ревью                         | Backend + Student| DB/Docs       |
| Настройка базового мониторинга (uptime-kuma)               | DevOps           | Infra         |

---

### Спринт 2: Парсер и API (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| MVP-парсер VK (события)                                    | Dev 1            | Parser        |
| MVP-парсер Telegram (каналы)                               | Dev 1            | Parser        |
| Интеграция парсера с API (POST /api/events/propose)        | Dev 1 + Dev 2    | Parser/API    |
| Запуск Laravel API: CRUD для events, interests, users      | Dev 2            | Backend/API   |
| JWT и Telegram Auth                                        | Dev 2            | Backend/Auth  |
| Тесты парсера и API (ручные и unit-тесты)                  | Student          | QA/Docs       |
| Документация: api.md, parser.md                            | Student          | Docs          |
| Настройка hotreload для parser/api                         | DevOps           | Infra         |
| Логирование ошибок, basic alerting                         | DevOps           | Infra/Monitoring|

---

### Спринт 3: Бот и publisher (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| Telegram-бот: /start, /events, /favorite, /add_event       | Dev 2            | Bot           |
| Publisher MVP: рассылка событий в каналы                   | Dev 2            | Publisher     |
| Логирование и обработка ошибок в боте и publisher          | Dev 2            | Bot/Publisher |
| Документация по боту и publisher                           | Student          | Docs          |
| Инструкция по деплою и переменным окружения                | DevOps           | Infra/Docs    |
| Тест-кейсы для команд бота и publisher                     | Student          | QA            |
| Прототип фильтрации событий (бот + publisher)              | Dev 2            | Bot/Publisher |
| Настройка hotreload для бота/publisher                     | DevOps           | Infra/DevOps  |

---

### Спринт 4: Безопасность, поддержка, UI/UX, автоматизация (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| Rate limiting, RBAC, базовая модерация                     | Backend          | API/Security  |
| Логирование подозрительных активностей                     | Backend/DevOps   | Security      |
| Чек-лист релиза и автотесты на деплой                      | DevOps + Student | QA/CI         |
| Юзер-стори для поддержки и onboarding                      | Student          | Docs/Support  |
| Прототип минимального web-интерфейса (PWA-оболочка)        | Frontend         | Frontend/PWA  |
| Push/web-push через фронт и бот                            | Frontend + Bot   | PWA/Bot       |
| Инструкция по бэкапу БД, nightly cron                      | DevOps           | Infra/Backup  |
| Документация по hotreload и CI/CD                          | DevOps + Student | Docs/Infra    |

---

### Спринт 5: Расширение функциональности, интеграции (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| Экспорт событий в календари (Google, Yandex, iCal)         | Backend/Frontend | API/Frontend  |
| Поддержка ролей и прав (admin, moderator)                  | Backend          | API/Security  |
| Интеграция с внешними афишами (open data, RSS, парсер сайтов) | Dev 1         | Parser        |
| Миграции: расширенные индексы, soft delete, история изменений | Backend       | DB            |
| Документация для партнеров (public API, usage guide)       | Student          | Docs/Business |
| Автотесты сценариев “Пойду”, “Избранное”, публикация       | Student          | QA            |
| Поддержка backup/restore, тест восстановления              | DevOps           | Infra/Backup  |
| Улучшение мониторинга и логов (Grafana, Sentry)            | DevOps           | Infra         |

---

### Спринт 6: Аналитика, масштабирование, growth (2 недели)

| Задача                                                     | Исполнитель      | Категория     |
|------------------------------------------------------------|------------------|---------------|
| Метрики и аналитика: dashboard для usage, retention        | DevOps + Student | Analytics     |
| А/Б тесты и сбор пользовательского фидбека                 | Frontend + Student| Product      |
| Финализация документации, релиз-ноты, changelog            | Student          | Docs          |
| Юридические аспекты (privacy, публичная оферта, GDPR/152-ФЗ)| PM/BA            | Legal         |
| Подготовка публичного демо, SMM-старт, партнерские связи   | Все              | Growth/Business|
| Оценка производительности, stress-test API                 | DevOps           | QA/Infra      |
| Подготовка к следующей фазе: roadmap 2.0                   | Все              | Planning      |

---