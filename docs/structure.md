```
kudab-infra/
│
├── certs/                         # SSL-сертификаты (prod/test)
│   ├── dev/                       # Локальные self-signed для dev
│   └── prod/                      # Реальные сертификаты (Let's Encrypt и др.)
│
├── docs/                          # Документация
│   └── source/
│       ├── architecture.md
│       ├── db-schema.md
│       ├── database.dbml
│       ├── api.md
│       ├── bot.md
│       ├── setup.md
│       ├── migrations.md
│       ├── business.md
│       ├── roadmap.md
│       ├── styleguide.md
│       └── ... (и др.)
│
├── .env.example                   # Пример общих переменных окружения (root)
├── .gitmodules                    # Настройки git-подмодулей
├── .gitignore
├── docker-compose.yml             # Основной docker-compose (prod)
├── docker-compose.dev.yml         # dev override (hotreload, volume-mount)
├── docker-compose.ci.yml          # Спец. конфиг для CI/CD тестов (опционально)
├── README.md
│
├── services/                      # Все сервисы (каждый — подмодуль!)
│   │
│   ├── kudab-api/                 # Backend API (Laravel, PHP)
│   │   ├── ... (структура laravel)
│   │   ├── Dockerfile
│   │   ├── .env.example
│   │   └── ...
│   │
│   ├── kudab-frontend/            # Frontend (Nuxt.js)
│   │   ├── ... (структура nuxt)
│   │   ├── Dockerfile
│   │   ├── .env.example
│   │   └── ...
│   │
│   ├── kudab-nginx/               # Nginx конфиг (reverse-proxy)
│   │   ├── default.dev.conf
│   │   ├── default.prod.conf
│   │   ├── Dockerfile
│   │   └── README.md
│   │
│   ├── kudab-bot/                 # Telegram-бот (aiogram)
│   │   ├── ... (src, requirements.txt, Dockerfile)
│   │   └── .env.example
│   │
│   │   ├── ... (src, requirements.txt, Dockerfile)
│   │   └── .env.example
│   │
│   ├── kudab-parser/              # Парсер событий (Laravel)
│   │   ├── ... (laravel)
│   │   ├── Dockerfile
│   │   └── .env.example
│   │
│   │   ├── ... (src, Dockerfile)
│   │   └── .env.example
│   │
│       ├── ... (src, Dockerfile)
│       └── .env.example
│
├── data/                          # Внешние volume для dev-режима, мок-данные
│   ├── uploads/
│   └── ...
│
├── scripts/                       # Скрипты для деплоя, CI, тестов, запуска
│   ├── init-dev.sh
│   ├── deploy-prod.sh
│   └── ...
│
└── .github/                       # Github Actions workflows для CI/CD
    └── workflows/
        ├── build.yml
        ├── test.yml

```