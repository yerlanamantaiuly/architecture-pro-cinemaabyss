#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

if ! kubectl -n cinemaabyss get secret dockerconfigjson >/dev/null 2>&1; then
  echo "Ошибка: в namespace cinemaabyss отсутствует secret dockerconfigjson"
  echo "Сначала создайте его командой kubectl create secret docker-registry ..., затем повторите запуск."
  exit 1
fi

echo "Проверяю доступность Helm"
helm version

echo
echo "Удаляю старую установку, если она есть"
helm uninstall cinemaabyss -n cinemaabyss >/dev/null 2>&1 || true
kubectl delete namespace cinemaabyss >/dev/null 2>&1 || true

echo
echo "Устанавливаю chart через Helm"
helm install cinemaabyss ./src/kubernetes/helm --namespace cinemaabyss --create-namespace

echo
echo "Текущее состояние pod'ов"
kubectl -n cinemaabyss get pods

echo
echo "Сервисы"
kubectl -n cinemaabyss get svc
