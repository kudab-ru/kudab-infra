#!/bin/bash
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
docker-compose exec -T kudab-db pg_dump -U kudab kudab > backups/db_backup_$TIMESTAMP.sql