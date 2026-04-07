#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORTS_DIR="${ROOT_DIR}/tests/postman/reports"
INGRESS_HOST_IP="${K8S_INGRESS_IP:-192.168.49.2}"

mkdir -p "${REPORTS_DIR}"
cd "${ROOT_DIR}/tests/postman"

echo "Проверяю доступность ingress перед запуском тестов"
if ! curl --resolve "cinemaabyss.example.com:80:${INGRESS_HOST_IP}" -fsS http://cinemaabyss.example.com/health >/dev/null 2>&1; then
  echo "Ingress недоступен по адресу http://cinemaabyss.example.com/health через ${INGRESS_HOST_IP}"
  echo "Убедитесь, что:"
  echo "1. ingress controller поднят"
  echo "2. cinemaabyss.example.com доступен через IP ${INGRESS_HOST_IP}"
  echo "3. при необходимости задайте K8S_INGRESS_IP=<нужный-ip>"
  exit 1
fi

echo "Собираю Docker-образ для Postman/Newman тестов"
docker build -t cinemaabyss-api-tests .

echo "Запускаю Postman-тесты для Kubernetes"
docker run --rm \
  --add-host "cinemaabyss.example.com:${INGRESS_HOST_IP}" \
  -v "${REPORTS_DIR}:/app/reports" \
  cinemaabyss-api-tests \
  --environment kubernetes

echo "Тесты Kubernetes завершены. Отчеты лежат в ${REPORTS_DIR}"
