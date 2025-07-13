#!/bin/bash
docker-compose -f docker-compose.yml -f docker-compose.ci.yml up --abort-on-container-exit --exit-code-from kudab-api
