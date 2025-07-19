#!/bin/bash
cp .env.example .env
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build