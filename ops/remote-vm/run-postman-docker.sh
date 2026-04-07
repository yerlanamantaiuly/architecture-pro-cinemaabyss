#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORTS_DIR="${ROOT_DIR}/tests/postman/reports"

mkdir -p "${REPORTS_DIR}"
cd "${ROOT_DIR}/tests/postman"

echo "Собираю Docker-образ для Postman/Newman тестов"
docker build -t cinemaabyss-api-tests .

echo "Запускаю Postman-тесты в Docker"
docker run --rm \
  --network=cinemaabyss-network \
  -v "${REPORTS_DIR}:/app/reports" \
  cinemaabyss-api-tests

echo "Тесты завершены. Отчеты лежат в ${REPORTS_DIR}"
