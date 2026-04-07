#!/usr/bin/env bash
set -euo pipefail

if ! command -v yc >/dev/null 2>&1; then
  echo "Нужен yc CLI. Установите его и сначала выполните 'yc init'."
  exit 1
fi

YC_INSTANCE_NAME="${YC_INSTANCE_NAME:-cinemaabyss-sprint2}"
YC_ZONE="${YC_ZONE:-ru-central1-a}"
YC_SUBNET_NAME="${YC_SUBNET_NAME:-default-ru-central1-a}"
YC_SECURITY_GROUP_ID="${YC_SECURITY_GROUP_ID:-}"
YC_IMAGE_FAMILY="${YC_IMAGE_FAMILY:-ubuntu-2404-lts}"
YC_CORES="${YC_CORES:-4}"
YC_MEMORY_GB="${YC_MEMORY_GB:-8}"
YC_DISK_GB="${YC_DISK_GB:-40}"
YC_SSH_USER="${YC_SSH_USER:-ubuntu}"
YC_SSH_KEY_PATH="${YC_SSH_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}"

if [[ ! -f "${YC_SSH_KEY_PATH}" ]]; then
  echo "Не найден публичный SSH-ключ: ${YC_SSH_KEY_PATH}"
  exit 1
fi

network_interface="subnet-name=${YC_SUBNET_NAME},nat-ip-version=ipv4"
if [[ -n "${YC_SECURITY_GROUP_ID}" ]]; then
  network_interface="${network_interface},security-group-ids=${YC_SECURITY_GROUP_ID}"
fi

echo "Создаю Yandex Cloud VM ${YC_INSTANCE_NAME}"
echo "Зона: ${YC_ZONE}"
echo "Подсеть: ${YC_SUBNET_NAME}"
echo "Семейство образов: ${YC_IMAGE_FAMILY}"
echo "CPU: ${YC_CORES}"
echo "Память (GB): ${YC_MEMORY_GB}"
echo "Диск (GB): ${YC_DISK_GB}"

yc compute instance create \
  --name "${YC_INSTANCE_NAME}" \
  --zone "${YC_ZONE}" \
  --cores "${YC_CORES}" \
  --memory "${YC_MEMORY_GB}" \
  --create-boot-disk "image-folder-id=standard-images,image-family=${YC_IMAGE_FAMILY},size=${YC_DISK_GB}" \
  --network-interface "${network_interface}" \
  --metadata "ssh-keys=${YC_SSH_USER}:$(cat "${YC_SSH_KEY_PATH}")"

cat <<EOF

Команда на создание VM отправлена.

Следующие шаги:
1. Получите публичный IP:
   yc compute instance get "${YC_INSTANCE_NAME}" --zone "${YC_ZONE}"
2. Подключитесь к VM по SSH как ${YC_SSH_USER}.
3. Склонируйте или скопируйте этот репозиторий.
4. Запустите sudo bash ops/remote-vm/bootstrap-ubuntu-24.04.sh

EOF
