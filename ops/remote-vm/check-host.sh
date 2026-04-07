#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Не найден docker-compose.yml в ${ROOT_DIR}"
  exit 1
fi

cpu_count="$(nproc)"
mem_gb="$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)"
disk_gb="$(df -BG "${ROOT_DIR}" | awk 'NR==2 {gsub(/G/, "", $4); print $4}')"

echo "Сводка по хосту"
echo "  CPU ядер: ${cpu_count}"
echo "  Свободно диска (GB): ${disk_gb}"
echo "  Всего памяти (GB): ${mem_gb}"

if (( cpu_count < 4 )); then
  echo "Предупреждение: меньше 4 ядер CPU. Полный стек спринта может работать медленно."
fi

awk "BEGIN {exit !(${mem_gb} < 8.0)}" && \
  echo "Предупреждение: меньше 8 GB RAM. Minikube и Istio могут работать нестабильно."

if (( disk_gb < 40 )); then
  echo "Предупреждение: меньше 40 GB свободного диска."
fi

echo
echo "Проверка бинарников"
for cmd in git docker kubectl helm minikube curl jq; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    printf "  [ok] %s\n" "${cmd}"
  else
    printf "  [нет] %s\n" "${cmd}"
  fi
done

echo
echo "Проверка Docker"
docker --version
docker compose version
docker info >/dev/null
echo "  Docker daemon: доступен"

echo
echo "Проверка Compose"
docker compose config >/dev/null
echo "  docker compose config: корректный"

echo
echo "Сетевое примечание"
echo "  При необходимости откройте входящие порты: 8000, 8080, 8081, 8082, 8090"
