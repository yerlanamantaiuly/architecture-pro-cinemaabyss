#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="${ROOT_DIR}/ops/remote-vm/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="${REPORT_DIR}/compose-baseline-${TIMESTAMP}.md"

mkdir -p "${REPORT_DIR}"
cd "${ROOT_DIR}"

services=(
  postgres
  zookeeper
  kafka
  monolith
  movies-service
  kafka-ui
)

cleanup() {
  docker compose stop "${services[@]}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "Собираю только уже реализованные прикладные сервисы"
docker compose build monolith movies-service

echo "Запускаю baseline-сервисы"
docker compose up -d "${services[@]}"

echo "Жду стабилизации сервисов"
sleep 35

{
  echo "# Отчет Compose Baseline"
  echo
  echo "- Сформирован: $(date -Iseconds)"
  echo "- Хост: $(hostname)"
  echo
  echo "## Сервисы"
  docker compose ps "${services[@]}"
  echo
  echo "## Health-check"
  echo
  echo "### Monolith"
  curl -fsS http://localhost:8080/health || echo "Проверка Monolith не прошла"
  echo
  echo
  echo "### Movies"
  curl -fsS http://localhost:8081/api/movies/health || echo "Проверка Movies не прошла"
  echo
  echo
  echo "### Kafka UI"
  curl -fsS http://localhost:8090 >/dev/null && echo "Kafka UI отвечает на :8090" || echo "Kafka UI недоступен"
  echo
  echo
  echo "## Примечания"
  echo "- proxy-service специально исключен из baseline, потому что src/microservices/proxy сейчас пустой."
  echo "- events-service специально исключен из baseline, потому что src/microservices/events сейчас отсутствует."
  echo
  echo "## Хвост логов"
  echo
  docker compose logs --tail=40 "${services[@]}"
} >"${REPORT_FILE}"

echo "Отчет baseline сохранен в ${REPORT_FILE}"
