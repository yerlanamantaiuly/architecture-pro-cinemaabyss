#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORTS_DIR="${ROOT_DIR}/tests/postman/reports"

detect_ingress_ip() {
  if [[ -n "${K8S_INGRESS_IP:-}" ]]; then
    printf '%s' "${K8S_INGRESS_IP}"
    return 0
  fi

  if command -v minikube >/dev/null 2>&1; then
    minikube ip 2>/dev/null && return 0
  fi

  printf '%s' "192.168.49.2"
}

INGRESS_HOST_IP="$(detect_ingress_ip)"

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

if ! curl --resolve "cinemaabyss.example.com:80:${INGRESS_HOST_IP}" -fsS http://cinemaabyss.example.com/api/events/health >/dev/null 2>&1; then
  echo "Events endpoint недоступен по адресу http://cinemaabyss.example.com/api/events/health через ${INGRESS_HOST_IP}"
  exit 1
fi

echo "Собираю Docker-образ для Postman/Newman тестов"
docker build -t cinemaabyss-api-tests .

echo "Запускаю Postman-тесты для Kubernetes"
docker run --rm \
  --network host \
  --add-host "cinemaabyss.example.com:${INGRESS_HOST_IP}" \
  -v "${REPORTS_DIR}:/app/reports" \
  cinemaabyss-api-tests \
  --environment kubernetes

echo "Тесты Kubernetes завершены. Отчеты лежат в ${REPORTS_DIR}"
