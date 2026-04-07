#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "Поднимаю только старый контур: postgres + monolith"
docker compose up -d postgres monolith

echo "Жду готовности монолита"
for _ in {1..30}; do
  if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo
echo "Статус сервисов"
docker compose ps postgres monolith

echo
echo "Проверка /health"
curl -fsS http://localhost:8080/health || {
  echo "Монолит не ответил на /health"
  exit 1
}

echo
echo
echo "Проверка /api/movies"
curl -fsS http://localhost:8080/api/movies || {
  echo "Монолит не ответил на /api/movies"
  exit 1
}

echo
echo
echo "Монолитный контур запущен."
echo "Полезные URL:"
echo "  http://<server-ip>:8080/health"
echo "  http://<server-ip>:8080/api/movies"
echo "  http://<server-ip>:8080/api/users"
