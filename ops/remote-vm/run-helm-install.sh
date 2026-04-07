#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

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
echo "Жду готовности pod'ов"
kubectl wait --for=condition=Ready pod --all -n cinemaabyss --timeout=300s

echo
echo "Текущее состояние pod'ов"
kubectl -n cinemaabyss get pods

echo
echo "Сервисы"
kubectl -n cinemaabyss get svc
