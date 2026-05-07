#### kudab-infra

Meta-репозиторий для оркестрации и деплоя платформы **kudab.ru**. Содержит инфраструктурные настройки, docker-compose конфигурацию, все сервисы как git-подмодули, шаблоны .env и инструкции для быстрой сборки, запуска и обновления production/dev среды.

---

#### Состав

- **docker-compose.yml** — основной compose-файл платформы: kudab-api, kudab-frontend, kudab-bot, kudab-parser, kudab-horizon, kudab-nginx, kudab-db, kudab-redis
- **docker-compose.prod.yml** — продакшен-override: переменные окружения, volumes, рестарт always, прод-конфиг nginx, SSL
- **docker-compose.dev.yml** — дев-override: маунты исходников, дополнительные порты, dev-конфиг nginx, горячая перезагрузка
- **scripts/** — служебные скрипты для reindex, диагностики и обслуживания окружения
- **.env.example, .env.production, .env.development** — шаблоны переменных окружения для сервисов
- **docs/** — документация, бизнес-логика, структура, архитектура
- **.github/workflows/** — CI/CD-автоматизация, если используется в конкретном окружении
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

#### Деплой

Основной рабочий способ деплоя и обновления окружения — через Makefile и docker compose.

Полезные команды:

```sh
make dev
make prod
make prod-deploy
make prod-deploy-service SVC=kudab-bot
```

---

#### Минимальные требования

- Ubuntu 22.04+ (или любая Linux с docker 20+, compose 2+)
- Открытые 80/443 (prod), корректно настроенный docker user
- SSH-доступ по ключу, все переменные/секреты заданы в GitHub Actions

---

#### Документация

- Все инструкции, структура, архитектура, бизнес-логика — в **docs/**

---

#### Контакты и поддержка

- [Telegram](https://t.me/mkrasyuk) — быстрые вопросы по инфраструктуре/деплою
