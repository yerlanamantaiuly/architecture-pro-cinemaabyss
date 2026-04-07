#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "Добавляю Helm repo Istio"
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null 2>&1 || true
helm repo update

echo
echo "Устанавливаю istio-base"
helm upgrade --install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace

echo
echo "Устанавливаю istiod"
helm upgrade --install istiod istio/istiod -n istio-system --wait --timeout 300s

echo
echo "Проверяю состояние istio-system"
kubectl -n istio-system get pods
kubectl -n istio-system rollout status deploy/istiod --timeout=300s

echo
echo "Устанавливаю istio-ingressgateway"
helm upgrade --install istio-ingressgateway istio/gateway -n istio-system --wait --timeout 300s

echo
echo "Проверяю состояние ingress gateway"
kubectl -n istio-system get pods

echo
echo "Включаю sidecar injection для namespace cinemaabyss"
kubectl label namespace cinemaabyss istio-injection=enabled --overwrite

echo
echo "Перезапускаю deployment'ы, чтобы sidecar'ы добавились в уже работающие pod'ы"
kubectl -n cinemaabyss rollout restart deploy/monolith deploy/movies-service deploy/events-service deploy/proxy-service

echo
echo "Жду готовности deployment'ов"
kubectl -n cinemaabyss rollout status deploy/monolith --timeout=300s
kubectl -n cinemaabyss rollout status deploy/movies-service --timeout=300s
kubectl -n cinemaabyss rollout status deploy/events-service --timeout=300s
kubectl -n cinemaabyss rollout status deploy/proxy-service --timeout=300s

echo
echo "Применяю circuit breaker конфигурацию"
kubectl apply -f "${ROOT_DIR}/src/kubernetes/circuit-breaker-config.yaml" -n cinemaabyss

echo
echo "Проверяю pod'ы после включения Istio"
kubectl -n cinemaabyss get pods

echo
echo "Проверяю namespace label"
kubectl get namespace cinemaabyss -L istio-injection
