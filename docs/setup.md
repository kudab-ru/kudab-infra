#### SETUP: Быстрый старт для kudab.ru

---

#### Требования

- Docker + Compose (v2+)
- Git (лучше с поддержкой submodules)
- Node.js 20+ (для frontend)
- Python 3.11+ (для бота)
- Шаблоны `.env.example` (лежат в каждом сервисе)

---

#### 1. Клонируй репозиторий

```sh
git clone --recurse-submodules git@github.com:kudab-ru/kudab-infra.git
cd kudab-infra
git submodule update --init --recursive
```

---

#### 2. Подготовь переменные окружения

```sh
cp .env.example .env
cp services/kudab-api/.env.example services/kudab-api/.env
cp services/kudab-frontend/.env.example services/kudab-frontend/.env
cp services/kudab-bot/.env.example services/kudab-bot/.env
cp services/kudab-publisher/.env.example services/kudab-publisher/.env
cp services/kudab-parser/.env.example services/kudab-parser/.env
cp services/kudab-admin/.env.example services/kudab-admin/.env
cp services/kudab-recommendations/.env.example services/kudab-recommendations/.env
```
Проверь и поправь значения под себя (DB, токены, почта, Redis, Swagger).

---

#### 3. Запусти проект

```sh
docker compose up -d --build
```
Все сервисы поднимутся автоматически.

---

#### 4. Миграция базы

```sh
docker compose exec kudab-api php artisan migrate --seed
```

---

#### 5. Полезные команды

- Перезапуск сервиса:
  ```sh
  docker compose restart kudab-api
  ```
- Просмотр логов:
  ```sh
  docker compose logs -f kudab-api
  ```
- Остановка:
  ```sh
  docker compose down
  ```

---

#### 6. Локальная разработка

- Frontend:
  ```sh
  cd services/kudab-frontend && npm install && npm run dev
  ```
- Bot:
  ```sh
  cd services/kudab-bot && pip install -r requirements.txt && python -m bot.main
  ```

---

#### 7. Доступ

- API: http://localhost/api/
- Front: http://localhost/
- Admin: http://localhost/admin/
- Swagger: http://localhost:8181

---

#### 8. Обновление

```sh
git pull --recurse-submodules
git submodule update --init --recursive
docker compose pull
docker compose up -d --build
```

---

#### 9. Проблемы

- Проверь переменные подключения к базе и Redis
- Проверь права на storage/logs:
  ```sh
  docker compose exec kudab-api chown -R www-data:www-data storage bootstrap/cache
  ```

---

#### 10. Скрипты

##### Основные скрипты из scripts/

- `init-dev.sh` — инициализация dev-окружения, билд и запуск всех сервисов.
- `deploy-prod.sh` — деплой на production.
- `migrate.sh` — прогон миграций баз данных.
- `test.sh` — полный запуск CI-процесса (прогон тестов всех сервисов).
- `down.sh` — остановка всех контейнеров и очистка volume.
- `logs.sh` — просмотр последних 100 строк логов всех сервисов.
- `build.sh` — ручная сборка всех Docker-образов.

> Перед запуском скриптов: не забудь выдать права на выполнение:
> ```
> chmod +x scripts/*.sh
> ```

---