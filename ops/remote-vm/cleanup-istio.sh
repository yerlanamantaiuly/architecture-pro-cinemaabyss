#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cinemaabyss}"
FORTIO_MANIFEST="https://raw.githubusercontent.com/istio/istio/release-1.25/samples/httpbin/sample-client/fortio-deploy.yaml"

echo "Удаляю fortio"
kubectl delete -f "${FORTIO_MANIFEST}" -n "${NAMESPACE}" >/dev/null 2>&1 || true

echo "Удаляю circuit breaker конфигурацию"
kubectl delete -f "./src/kubernetes/circuit-breaker-config.yaml" -n "${NAMESPACE}" >/dev/null 2>&1 || true

echo "Убираю istio-injection label с namespace ${NAMESPACE}"
kubectl label namespace "${NAMESPACE}" istio-injection- >/dev/null 2>&1 || true

echo "Удаляю Istio releases"
helm uninstall istio-ingressgateway -n istio-system >/dev/null 2>&1 || true
helm uninstall istiod -n istio-system >/dev/null 2>&1 || true
helm uninstall istio-base -n istio-system >/dev/null 2>&1 || true

echo "Удаляю namespace istio-system"
kubectl delete namespace istio-system >/dev/null 2>&1 || true

echo "Перезапускаю deployment'ы приложения без sidecar'ов"
kubectl -n "${NAMESPACE}" rollout restart deploy/monolith deploy/movies-service deploy/events-service deploy/proxy-service >/dev/null 2>&1 || true

echo "Готово"
