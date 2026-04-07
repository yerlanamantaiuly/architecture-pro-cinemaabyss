# Настройка GitHub И GHCR

Используйте этот чек-лист после того, как VM будет создана и вы будете готовы
публиковать образы.

## 1. Создать репозиторий

Выберите один из вариантов:

- Создать новый GitHub-репозиторий и запушить туда этот проект.
- Создать форк исходного репозитория курса, если у вас уже есть его URL.

## 2. Проверить нужные возможности GitHub

- GitHub Actions включены для репозитория
- GitHub Container Registry доступен по пути `ghcr.io/<owner>/<repo>`
- Есть право создавать classic или fine-grained token, если потребуется pull из приватного реестра

## 3. Рекомендуемые учетные данные

- Для push в GHCR из GitHub Actions в пределах того же репозитория обычно
  достаточно `GITHUB_TOKEN`.
- Для pull приватных образов в Kubernetes подготовьте PAT минимум с правом
  `read:packages`.

## 4. Пример логина

С машины, где установлены Docker и `gh`:

```bash
gh auth login
echo "$CR_PAT" | docker login ghcr.io -u YOUR_GITHUB_LOGIN --password-stdin
```

## 5. Порядок подготовки Kubernetes pull secret

1. Залогиньтесь в `ghcr.io` через Docker.
2. Откройте `~/.docker/config.json`.
3. Закодируйте этот файл в Base64.
4. Вставьте значение в `src/kubernetes/dockerconfigsecret.yaml`.
5. То же значение продублируйте в Helm `values.yaml`, если секретом управляет chart.

## 6. Важное текущее ограничение проекта

Текущий workflow собирает только `monolith` и `movies-service`. Для полного
стека в GHCR проекту еще нужны код `proxy-service` и `events-service`, а также
шаги CI для их сборки и публикации.
