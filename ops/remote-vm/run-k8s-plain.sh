#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "Проверяю доступность kubectl"
kubectl version --client

echo
echo "Применяю namespace и базовые настройки"
kubectl apply -f src/kubernetes/namespace.yaml
kubectl apply -f src/kubernetes/configmap.yaml
kubectl apply -f src/kubernetes/secret.yaml
kubectl apply -f src/kubernetes/dockerconfigsecret.yaml
kubectl apply -f src/kubernetes/postgres-init-configmap.yaml

echo
echo "Разворачиваю PostgreSQL"
kubectl apply -f src/kubernetes/postgres.yaml

echo
echo "Разворачиваю Kafka и ZooKeeper"
kubectl apply -f src/kubernetes/kafka/kafka.yaml

echo
echo "Разворачиваю приложения"
kubectl apply -f src/kubernetes/monolith.yaml
kubectl apply -f src/kubernetes/movies-service.yaml
kubectl apply -f src/kubernetes/events-service.yaml
kubectl apply -f src/kubernetes/proxy-service.yaml

echo
echo "Разворачиваю ingress"
kubectl apply -f src/kubernetes/ingress.yaml

echo
echo "Текущее состояние pod'ов"
kubectl -n cinemaabyss get pods

echo
echo "Сервисы"
kubectl -n cinemaabyss get svc
