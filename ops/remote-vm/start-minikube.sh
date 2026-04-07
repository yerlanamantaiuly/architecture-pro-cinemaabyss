#!/usr/bin/env bash
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cinemaabyss}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DISK_SIZE="${MINIKUBE_DISK_SIZE:-40g}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

echo "Запускаю профиль Minikube ${PROFILE}"
minikube start \
  --profile="${PROFILE}" \
  --driver="${DRIVER}" \
  --cpus="${CPUS}" \
  --memory="${MEMORY}" \
  --disk-size="${DISK_SIZE}" \
  --kubernetes-version=v1.30.0

echo "Включаю ingress addon"
minikube -p "${PROFILE}" addons enable ingress

echo "Переключаю kubectl context"
kubectl config use-context "${PROFILE}"

cat <<EOF

Minikube готов.

Рекомендуемые следующие шаги:
1. Проверьте storage class и pod'ы ingress controller.
2. Сначала примените namespace, config, secrets и postgres.
3. Затем примените kafka/zookeeper.
4. После этого примените manifests для monolith и movies.
5. Не применяйте manifests для proxy/events, пока сами сервисы и их образы не появятся.

EOF
