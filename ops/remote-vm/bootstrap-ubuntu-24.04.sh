#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите скрипт от root: sudo bash $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER:-ubuntu}}"
ARCH="$(dpkg --print-architecture)"
KUBECTL_VERSION="v1.30.2"
MINIKUBE_VERSION="v1.35.0"

echo "[1/8] Обновляю метаданные apt"
apt-get update

echo "[2/8] Устанавливаю базовые пакеты"
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  conntrack \
  curl \
  git \
  gpg \
  jq \
  net-tools \
  socat \
  software-properties-common

echo "[3/8] Устанавливаю Docker Engine и Compose plugin"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "${TARGET_USER}"

echo "[4/8] Устанавливаю kubectl"
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo "[5/8] Устанавливаю Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[6/8] Устанавливаю Minikube"
curl -fsSL "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64" -o /usr/local/bin/minikube
chmod +x /usr/local/bin/minikube

echo "[7/8] Устанавливаю GitHub CLI (необязательно, но полезно)"
mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
cat >/etc/apt/sources.list.d/github-cli.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
EOF
apt-get update
apt-get install -y gh

echo "[8/8] Печатаю версии установленных инструментов"
docker --version
docker compose version
kubectl version --client
helm version
minikube version
gh --version | head -n 1

cat <<EOF

Подготовка завершена.

Следующие шаги:
1. Перелогиньтесь, чтобы применилось членство пользователя ${TARGET_USER} в группе Docker.
2. Запустите ops/remote-vm/check-host.sh
3. Склонируйте или скопируйте репозиторий на VM, если еще этого не сделали.
4. Запустите ops/remote-vm/run-compose-baseline.sh из корня репозитория.

EOF
