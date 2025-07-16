#### Обновление и деплой подмодуля — только код

```sh
# Обновление подмодуля (локально или в CI)
git submodule update --remote path/to/submodule
git add path/to/submodule
git commit -m "update submodule: <имя>"
git push

# Проверка, какие подмодули изменились
git diff --name-only HEAD~1 HEAD | grep ^path/to/submodule

# Сборка только измененного сервиса
docker-compose build <service_name>

# Прогон тестов для одного сервиса
docker-compose run --rm <service_name> <test_command>

# Перезапуск только обновленного сервиса
docker-compose up -d <service_name>

# Очистка старых неиспользуемых docker-образов
docker image prune -f
docker builder prune -af
```

---

#### Пример pre-commit hook (опционально, bash)

```sh
#!/bin/bash
# .git/hooks/pre-commit
git submodule update --remote
git add path/to/updated-submodule
```

---

#### Пример workflow GitHub Actions (минимальный, только код)

```yaml
name: Submodule Service CI/CD

on:
  push:
    paths:
      - 'api/**'
      - '.gitmodules'
      - 'docker-compose.yml'

jobs:
  build-test-deploy-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: 'recursive'
      - name: Build API
        run: docker-compose build api
      - name: Test API
        run: docker-compose run --rm api <test_command>
      - name: Deploy API
        run: docker-compose up -d api
      - name: Docker cleanup
        run: docker image prune -f && docker builder prune -af
```
