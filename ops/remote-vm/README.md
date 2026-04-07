# Удаленная VM

В этой директории лежат вспомогательные скрипты для подготовки удаленной VM на
`Ubuntu 24.04`, где будет запускаться окружение второго спринта CinemaAbyss.

## Рекомендуемый размер VM

- Только для baseline: 2 vCPU, 4 GB RAM, 20 GB диска
- Для полного трека спринта: 4 vCPU, 8 GB RAM, 40 GB диска
- Комфортно для Istio/Fortio: 6 vCPU, 10-12 GB RAM, 50+ GB диска

## Ожидаемый порядок работы

1. Создать VM с `Ubuntu 24.04`.
2. Скопировать этот репозиторий на VM.
3. Запустить `ops/remote-vm/bootstrap-ubuntu-24.04.sh` от `root`.
4. Перелогиниться, чтобы применилось членство в группе Docker.
5. Запустить `ops/remote-vm/check-host.sh`.
6. Если нужно быстро оживить старый контур, запустить `ops/remote-vm/run-monolith-only.sh`.
7. Для полного docker-стека запустить `ops/remote-vm/run-full-stack.sh`.
8. При необходимости снять baseline через `ops/remote-vm/run-compose-baseline.sh`.
9. После появления образов для Kubernetes запустить
   `ops/remote-vm/start-minikube.sh`.

## Что делают скрипты

- `bootstrap-ubuntu-24.04.sh`: ставит Docker, Compose plugin, `kubectl`, Helm,
  Minikube, Git, `curl` и полезные сетевые утилиты.
- `check-host.sh`: проверяет CPU, память, диск и наличие нужных бинарников.
- `run-monolith-only.sh`: поднимает только старый монолитный контур с PostgreSQL.
- `run-full-stack.sh`: поднимает весь docker-стек и проверяет основные endpoint'ы.
- `run-postman-docker.sh`: прогоняет Postman/Newman тесты в Docker без установки Node.js на сервер.
- `run-postman-kubernetes.sh`: прогоняет Postman/Newman тесты против ingress Kubernetes без установки Node.js на сервер. По умолчанию использует `192.168.49.2`, при необходимости IP можно переопределить через `K8S_INGRESS_IP`.
- `run-compose-baseline.sh`: поднимает только те сервисы, которые уже реально
  есть в репозитории, и сохраняет диагностический отчет.
- `run-k8s-plain.sh`: применяет plain Kubernetes manifests в порядке из задания 3.
- `run-helm-install.sh`: удаляет предыдущий Helm release/namespace и ставит chart
  заново через `helm install`.
- `create-ghcr-secret.sh`: создаёт или обновляет `docker-registry` secret для
  доступа Kubernetes к `ghcr.io`.
- `start-minikube.sh`: стартует профиль Minikube с размером под этот проект и
  включает ingress.

## Примечания

- `run-monolith-only.sh` нужен для быстрого подъема старого контура без всего
  остального стека.
- `run-full-stack.sh` нужен для проверки уже реализованного docker-контура.
- Baseline через Docker Compose можно использовать как дополнительный
  диагностический сценарий.
- Если позже понадобится доступ Kubernetes к GHCR, после публикации образов
  нужно будет создать репозиторий/форк и подготовить `dockerconfigjson` secret.
