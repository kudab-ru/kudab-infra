#### Deploy/Production

- Деплой оркестируется через docker compose, git-подмодули, сервер Ubuntu 22.04+ (VPS, Selectel и др.)
- Автоматизация: GitHub Actions (deploy.yml)
- Никаких pm2/rsync/скриптов вне ./scripts — только docker compose и git

#### Сценарии запуска

##### Production

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

##### Development

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

#### Структура деплоя

- **docker-compose.yml** — все основные сервисы (kudab-api, kudab-parser, kudab-frontend, kudab-admin, kudab-bot, kudab-publisher, kudab-recommendations, kudab-nginx, redis, swagger, kudab-db)
- **docker-compose.prod.yml** — только override для продакшена (переменные, порты, volumes, рестарт always, prod-конфиг nginx)
- **docker-compose.dev.yml** — override для разработки (volume-маунты исходников, порты под hot-reload, dev-конфиг nginx)
- **deploy.yml** — CI/CD процесс: git pull, build, запуск, healthcheck, backup, миграции, smoke test, автоматический rollback
- **scripts/backup_db.sh, migrate.sh, rollback.sh** — backup, миграции, откат состояния
- **.env.example, .env.production, .env.development** — шаблоны переменных окружения

#### Требования

- Docker 20+, docker compose 2+, git (c поддержкой submodules)
- Сервер с открытыми 80/443 (prod)
- Пользователь в группе docker, SSH-ключи настроены
- Переменные/секреты в GitHub Actions: GH_TOKEN, SSH_PRIVATE_KEY, PROD_SSH_USER, PROD_SSH_HOST, PROD_DIRECTORY

#### Последовательность деплоя (workflow)

1. **Push** в main → GitHub Actions запускает deploy.yml
2. На сервере: git pull + обновление подмодулей
3. build/pull docker images, backup предыдущих образов
4. Запуск всех сервисов через docker compose (prod override)
5. Ожидание healthcheck критичных сервисов (nginx, db)
6. backup_db.sh → migrate.sh
7. smoke test (API, frontend)
8. В случае фейла — автоматический rollback через rollback.sh

#### Rollback

- Для всех микросервисов (:latest → :previous), откат автоматизирован rollback.sh