# Подготовка VM В Yandex Cloud

Эта инструкция нужна, чтобы подготовить удаленную VM для второго спринта без
запуска проекта на локальной Windows-машине.

## Рекомендуемые параметры

- ОС: `Ubuntu 24.04 LTS`
- Зона: `ru-central1-a`, если ваша подсеть не находится в другой зоне
- CPU: минимум 4 vCPU
- Память: минимум 8 GB
- Диск: минимум 40 GB SSD
- Публичный IP: обязателен

Если вы точно планируете дойти до Istio и нагрузочных проверок на той же VM,
лучше сразу взять 6 vCPU и 10-12 GB RAM.

## Что нужно до создания VM

1. Настроить `yc` CLI и выбрать нужный cloud/folder.
2. Подготовить публичный SSH-ключ.
3. Определить подсеть и security group для VM.

## Полезная проверка

Посмотреть стандартные образы:

```bash
yc compute image list --folder-id standard-images
```

Если `ubuntu-2404-lts` пока недоступен в вашем аккаунте или регионе, переопределите
семейство образов при запуске `ops/remote-vm/create-yc-vm.sh`.

## Создание VM

Можно использовать helper-скрипт:

```bash
YC_SUBNET_NAME=<ваша-подсеть> \
YC_SECURITY_GROUP_ID=<optional-sg-id> \
bash ops/remote-vm/create-yc-vm.sh
```

Либо выполнить эквивалентную команду вручную:

```bash
yc compute instance create \
  --name cinemaabyss-sprint2 \
  --zone ru-central1-a \
  --cores 4 \
  --memory 8 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,size=40 \
  --network-interface subnet-name=<ваша-подсеть>,nat-ip-version=ipv4 \
  --metadata "ssh-keys=ubuntu:$(cat ~/.ssh/id_ed25519.pub)"
```

## После создания

1. Подключитесь к VM по SSH.
2. Скопируйте или склонируйте репозиторий.
3. Запустите:

```bash
sudo bash ops/remote-vm/bootstrap-ubuntu-24.04.sh
```

4. Перелогиньтесь, чтобы применилось членство в группе Docker.
5. Проверьте хост:

```bash
bash ops/remote-vm/check-host.sh
```

6. Если хотите сначала поднять только старый контур:

```bash
bash ops/remote-vm/run-monolith-only.sh
```

7. Если хотите поднять уже весь docker-стек:

```bash
bash ops/remote-vm/run-full-stack.sh
```

8. При необходимости снимите baseline:

```bash
bash ops/remote-vm/run-compose-baseline.sh
```

9. Для Postman-проверки без установки Node.js на сервер:

```bash
bash ops/remote-vm/run-postman-docker.sh
```

10. Для plain Kubernetes-манифестов:

```bash
bash ops/remote-vm/run-k8s-plain.sh
```

11. Для Postman-проверки Kubernetes без установки Node.js:

```bash
bash ops/remote-vm/run-postman-kubernetes.sh
```

12. Только после подготовки Kubernetes-контура готовьте Minikube:

```bash
bash ops/remote-vm/start-minikube.sh
```
