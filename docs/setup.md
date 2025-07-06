#### SETUP: РАЗВЁРТЫВАНИЕ ПРОЕКТА KUDAB.RU

---

#### ОБЩИЕ ТРЕБОВАНИЯ

- Docker + Docker Compose (v2+)
- Git (желательно с поддержкой submodules)
- Node.js 20+ (локально — для разработки frontend)
- Python 3.11+ (локально — для разработки бота)
- make (опционально для коротких команд)
- Доступ к .env файлам (шаблоны .env.example есть в каждом сервисе)

---

#### 1. КЛОНИРОВАНИЕ И ОБНОВЛЕНИЕ РЕПОЗИТОРИЯ

```sh
git clone --recurse-submodules git@github.com:kudab-ru/kudab-infra.git
cd kudab-infra
# Если submodules не подтянулись:
git submodule update --init --recursive
```
---

#### 2. КОНФИГУРАЦИЯ ОКРУЖЕНИЯ

Скопируйте .env.example → .env в корне и во всех сервисах (api, frontend, bot, publisher):

```sh
cp .env.example .env
cp services/kudab-api/.env.example services/kudab-api/.env
cp services/kudab-frontend/.env.example services/kudab-frontend/.env
cp services/kudab-bot/.env.example services/kudab-bot/.env
cp services/kudab-publisher/.env.example services/kudab-publisher/.env
```

Проверьте и отредактируйте переменные для вашего окружения (DB, API, токены, почта и др.).

#### 3. СБОРКА И ЗАПУСК ВСЕХ СЕРВИСОВ

```sh
docker compose up -d --build
```

Сервисы поднимутся автоматически: API, frontend, bot, publisher, nginx, postgres.

#### 4. ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ

Зайдите в контейнер API (Laravel) и выполните миграции (если не подтянулись автоматически):

```sh
docker compose exec kudab-api bash
php artisan migrate --seed
exit
```

#### 5. ДОПОЛНИТЕЛЬНЫЕ КОМАНДЫ

Для сборки/перезапуска отдельных сервисов:

```sh
docker compose up -d --build kudab-frontend
docker compose restart kudab-api
```

Для просмотра логов:

```sh
docker compose logs -f kudab-api
docker compose logs -f kudab-frontend
```

Для остановки всех сервисов:

```sh
docker compose down
```

#### 6. ДЕВЕЛОПМЕНТ ЛОКАЛЬНО (по необходимости)
Frontend (SSR, Nuxt.js):

```sh
cd services/kudab-frontend
npm install
npm run dev
```

#### SSR будет на http://localhost:3000/

Bot (Python, aiogram):

```sh
cd services/kudab-bot
pip install -r requirements.txt
python -m bot.main
```


#### 7. ССЫЛКИ ДЛЯ ДОСТУПА
[//]: # (TODO: Пересмотреть ссылку)
- API: http://localhost/api/
- Frontend: http://localhost/
- Админка/API Swagger: (если есть) http://localhost/api/docs
- Бот: @kudab_ru_bot

#### 8. ЧАСТЫЕ ПРОБЛЕМЫ

Не работает база: проверьте переменные подключения (DB_HOST, DB_PORT, DB_USER, DB_PASSWORD).

Миграции не проходят: убедитесь, что контейнер с базой запущен (docker compose ps).

Нет прав на файлы (storage/logs): настройте права внутри контейнера, если нужно:

```sh
docker compose exec kudab-api chown -R www-data:www-data storage bootstrap/cache
```

#### 9. ОБНОВЛЕНИЕ

Для обновления кода и зависимостей:

```sh
git pull --recurse-submodules
git submodule update --init --recursive
docker compose pull
docker compose up -d --build
```

#### 10. РАСШИРЕНИЯ

Для отдельного запуска тестов, линтеров, задач CI — см. README.md и styleguide.md.

Для настройки окружения production/staging — дополняется отдельным docker-compose.override.yml.

