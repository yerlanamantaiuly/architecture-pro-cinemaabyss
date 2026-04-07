#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-cinemaabyss}"
SECRET_NAME="${2:-dockerconfigjson}"

read -rp "GitHub username: " GH_USER
read -rsp "GitHub PAT (read:packages): " GH_PAT
echo

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

kubectl -n "${NAMESPACE}" create secret docker-registry "${SECRET_NAME}" \
  --docker-server=ghcr.io \
  --docker-username="${GH_USER}" \
  --docker-password="${GH_PAT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret ${SECRET_NAME} в namespace ${NAMESPACE} создан или обновлён."
