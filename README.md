# kudab-infra
Meta-репозиторий для оркестрации и деплоя платформы kudab.ru. Содержит docker-compose, подмодули всех сервисов, шаблоны .env и инструкции для быстрой сборки, запуска и CI/CD всего проекта.

Запуск прода:
```shell
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Запуск dev:
```shell
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Запуск ci:
```shell
docker-compose -f docker-compose.yml -f docker-compose.ci.yml.disabled up --abort-on-container-exit --exit-code-from kudab-api
```
