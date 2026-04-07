#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "Поднимаю полный стек: postgres, zookeeper, kafka, monolith, movies-service, events-service, proxy-service, kafka-ui"
docker compose up -d

echo "Жду готовности сервисов"
for _ in {1..45}; do
  if docker compose ps --format json | grep '"State":"exited"' >/dev/null 2>&1; then
    echo "Один или несколько контейнеров завершились с ошибкой"
    docker compose ps
    exit 1
  fi

  monolith_ok=0
  movies_ok=0
  events_ok=0
  proxy_ok=0

  curl -fsS http://localhost:8080/health >/dev/null 2>&1 && monolith_ok=1 || true
  curl -fsS http://localhost:8081/api/movies/health >/dev/null 2>&1 && movies_ok=1 || true
  curl -fsS http://localhost:8082/api/events/health >/dev/null 2>&1 && events_ok=1 || true
  curl -fsS http://localhost:8000/health >/dev/null 2>&1 && proxy_ok=1 || true

  if [[ "${monolith_ok}" == "1" && "${movies_ok}" == "1" && "${events_ok}" == "1" && "${proxy_ok}" == "1" ]]; then
    break
  fi

  sleep 4
done

if ! curl -fsS http://localhost:8080/health >/dev/null 2>&1 || \
   ! curl -fsS http://localhost:8081/api/movies/health >/dev/null 2>&1 || \
   ! curl -fsS http://localhost:8082/api/events/health >/dev/null 2>&1 || \
   ! curl -fsS http://localhost:8000/health >/dev/null 2>&1; then
  echo "Не все сервисы стали доступны вовремя"
  docker compose ps
  exit 1
fi

echo
echo "Статус сервисов"
docker compose ps

echo
echo "Проверка endpoint'ов"
echo "Монолит:"
curl -fsS http://localhost:8080/health
echo
echo
echo "Movies:"
curl -fsS http://localhost:8081/api/movies/health
echo
echo
echo "Events:"
curl -fsS http://localhost:8082/api/events/health
echo
echo
echo "Proxy:"
curl -fsS http://localhost:8000/health
echo
echo
echo "Фильмы через proxy:"
curl -fsS http://localhost:8000/api/movies
echo
echo
echo "Полный стек поднят."
