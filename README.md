#### kudab-infra

Meta-репозиторий для оркестрации и деплоя платформы **kudasobrat.ru**. Содержит инфраструктурные настройки, docker-compose конфигурацию, все сервисы как git-подмодули, шаблоны .env и инструкции для быстрой сборки, запуска и обновления production/dev среды.

---

#### Состав

- **docker-compose.yml** — основной compose-файл, включает все сервисы платформы (api, parser, frontend, admin, bot, publisher, recommendations, nginx, redis, swagger, db)
- **docker-compose.prod.yml** — продакшен-override: переменные окружения, volumes, рестарт always, прод-конфиг nginx, SSL
- **docker-compose.dev.yml** — дев-override: маунты исходников, дополнительные порты, dev-конфиг nginx, горячая перезагрузка
- **scripts/** — служебные скрипты: backup_db.sh, migrate.sh, rollback.sh (только используемые!)
- **.env.example, .env.production, .env.development** — шаблоны переменных окружения для сервисов
- **docs/** — документация, бизнес-логика, структура, архитектура
- **.github/workflows/deploy.yml** — автоматизация деплоя через GitHub Actions

---

#### Быстрый старт

##### Клонирование и инициализация

```sh
git clone --recurse-submodules git@github.com:ваш/kudab-infra.git
cd kudab-infra
git submodule update --init --recursive
```

##### Подготовь .env

- Скопируй и настрой .env.example или .env.production для production
- Проверь переменные окружения, пути к SSL, пароли к сервисам

##### Запуск production

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

##### Запуск development

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

---

#### Автоматизация деплоя (Production)

- **CI/CD**: На push в main срабатывает deploy.yml (GitHub Actions)
- На сервере:
    - `git pull` и обновление подмодулей
    - build/pull всех образов
    - запуск docker compose с prod-override
    - healthcheck критических сервисов
    - backup_db.sh, migrate.sh
    - smoke test (API, frontend)
    - rollback (автоматически, если деплой неуспешен)

---

#### Минимальные требования

- Ubuntu 22.04+ (или любая Linux с docker 20+, compose 2+)
- Открытые 80/443 (prod), корректно настроенный docker user
- SSH-доступ по ключу, все переменные/секреты заданы в GitHub Actions

---

#### Rollback

- Все сервисы сохраняют предыдущий образ (:latest → :previous)
- При ошибке деплоя автоматический откат через scripts/rollback.sh

---

#### Документация

- Все инструкции, структура, архитектура, бизнес-логика — в **docs/**

---

#### Контакты и поддержка

- [Telegram](https://t.me/ya_solomka) — быстрые вопросы по инфраструктуре/деплою

---

#### Версия

- Актуальная версия: **1.0.1**
