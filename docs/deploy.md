#### Deploy/Production

- Деплой оркестируется через docker compose, git-подмодули, сервер Ubuntu 22.04+ (VPS, Selectel и др.)
- Основной способ запуска и обновления окружения — docker compose и Makefile
- Дополнительная CI/CD-автоматизация может использоваться отдельно, если настроена для конкретного окружения

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

- **docker-compose.yml** — основные сервисы: kudab-api, kudab-parser, kudab-frontend, kudab-bot, kudab-horizon, kudab-nginx, kudab-db, kudab-redis
- **docker-compose.prod.yml** — только override для продакшена (переменные, порты, volumes, рестарт always, prod-конфиг nginx)
- **docker-compose.dev.yml** — override для разработки (volume-маунты исходников, порты под hot-reload, dev-конфиг nginx)
- **.env.example, .env.production, .env.development** — шаблоны переменных окружения

#### Требования

- Docker 20+, docker compose 2+, git (c поддержкой submodules)
- Сервер с открытыми 80/443 (prod)
- Пользователь в группе docker, SSH-ключи настроены
- Переменные/секреты в GitHub Actions: GH_TOKEN, SSH_PRIVATE_KEY, PROD_SSH_USER, PROD_SSH_HOST, PROD_DIRECTORY

#### Последовательность деплоя

1. Обновить infra и подмодули
2. Пересобрать и поднять нужные сервисы через docker compose
3. Проверить health/status контейнеров
4. При необходимости выполнить миграции
5. Проверить логи и базовые smoke-проверки

Часто используемые команды:

```sh
make prod-pull
make prod-deploy
make prod-deploy-service SVC=kudab-bot
```

