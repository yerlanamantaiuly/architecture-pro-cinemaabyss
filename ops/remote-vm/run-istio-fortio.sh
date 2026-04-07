#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cinemaabyss}"
FORTIO_MANIFEST="https://raw.githubusercontent.com/istio/istio/release-1.25/samples/httpbin/sample-client/fortio-deploy.yaml"
MOVIES_URL="${MOVIES_URL:-http://movies-service:8081/api/movies}"
MONOLITH_URL="${MONOLITH_URL:-http://monolith:8080/api/users}"

echo "Разворачиваю fortio"
kubectl apply -f "${FORTIO_MANIFEST}" -n "${NAMESPACE}"

echo
echo "Жду готовности fortio pod"
kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod -l app=fortio --timeout=300s

FORTIO_POD="$(kubectl get pod -n "${NAMESPACE}" -l app=fortio -o jsonpath='{.items[0].metadata.name}')"

echo
echo "Нагрузка на movies-service"
kubectl exec -n "${NAMESPACE}" "${FORTIO_POD}" -c fortio -- \
  fortio load -c 50 -qps 0 -n 500 -loglevel Warning "${MOVIES_URL}"

echo
echo "Метрики circuit breaker для movies-service"
kubectl exec -n "${NAMESPACE}" "${FORTIO_POD}" -c istio-proxy -- \
  pilot-agent request GET stats | grep movies-service | grep pending || true

echo
echo "Нагрузка на monolith"
kubectl exec -n "${NAMESPACE}" "${FORTIO_POD}" -c fortio -- \
  fortio load -c 50 -qps 0 -n 500 -loglevel Warning "${MONOLITH_URL}"

echo
echo "Метрики circuit breaker для monolith"
kubectl exec -n "${NAMESPACE}" "${FORTIO_POD}" -c istio-proxy -- \
  pilot-agent request GET stats | grep monolith | grep pending || true
