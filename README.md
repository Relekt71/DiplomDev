# Дипломный практикум в Yandex Cloud

## Цели проекта

- Подготовить облачную инфраструктуру на базе Yandex Cloud при помощи Terraform.
- Запустить и сконфигурировать Kubernetes-кластер.
- Установить и настроить систему мониторинга (Prometheus, Grafana, Alertmanager).
- Создать тестовое приложение в Docker-контейнере.
- Настроить CI/CD для автоматической сборки и деплоя.

---

## Этап 1. Создание облачной инфраструктуры

### Инструмент: Terraform

Инфраструктура описывается декларативно через Terraform. Backend для хранения state-файла — S3-бакет в Yandex Cloud.

### Структура конфигурации

terraform/ ├── sa-bucket/ # Создание сервисного аккаунта и S3-бакета │ ├── main.tf │ ├── variables.tf │ └── outputs.tf └── infra/ # Основная инфраструктура (VPC, подсети, k8s-кластер) ├── main.tf ├── variables.tf ├── outputs.tf └── provider.tf

text


Конфигурации для сервисного аккаунта/бакета и основной инфраструктуры разнесены в разные папки — это позволяет создать backend до запуска основной конфигурации.

### Что создаётся

1. **Сервисный аккаунт** с минимально необходимыми правами (не суперпользователь):
   - `k8s.clusters.agent` — управление Managed Kubernetes;
   - `vpc.user` — работа с сетями;
   - `compute.admin` — управление виртуальными машинами;
   - `iam.serviceAccounts.user` — назначение ролей;
   - `container-registry.images.puller` — доступ к Container Registry.

2. **S3-бакет** для хранения Terraform state.

3. **VPC с подсетями** в трёх зонах доступности:
   - `ru-central1-a`
   - `ru-central1-b`
   - `ru-central1-d`

4. **Managed Kubernetes кластер** (региональный мастер, неотказоустойчивый) с node group в трёх подсетях. Worker nodes — прерываемые ВМ (preemptible), что снижает стоимость.

### Команды

```bash
    # Создание сервисного аккаунта и бакета
    cd terraform/sa-bucket
    terraform init
    terraform plan
    terraform apply

    # Создание основной инфраструктуры
    cd terraform/infra
    terraform init -backend-config="access_key=..." -backend-config="secret_key=..."
    terraform plan
    terraform apply

Проверка

bash

    # Проверка, что кластер создан
    yc managed-kubernetes cluster list

    # Получение kubeconfig
    yc managed-kubernetes cluster get-credentials --id <cluster-id> --external

    # Проверка доступа
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces

Результат

    Terraform сконфигурирован, инфраструктура создаётся без ручных действий;
    State-файл хранится в S3-бакете;
    terraform destroy и terraform apply отрабатывают без дополнительных шагов.

## Этап 2. Создание Kubernetes кластера

Способ: Yandex Managed Service for Kubernetes

Использован альтернативный вариант — Managed Kubernetes от Yandex Cloud (рекомендуемый для быстрого старта).
Параметры кластера

    Тип мастера: региональный (неотказоустойчивый)
    Зоны: ru-central1-a, ru-central1-b, ru-central1-d
    Версия Kubernetes: v1.34.1
    Тип worker nodes: прерываемые (preemptible)
    Количество узлов: 2

Проверка работоспособности

bash

    # Ноды кластера
    kubectl --kubeconfig=~/diploma/yc-kubeconfig get nodes -o wide

Ожидаемый результат:

text

    NAME                        STATUS   ROLES    AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
    cl1m1o6uf7u8ubnpmtfd-emul   Ready    <none>   106m   v1.34.1   192.168.10.18   <none>        Ubuntu 22.04.5 LTS   5.15.0-181-generic   containerd://2.2.1
    cl1m1o6uf7u8ubnpmtfd-uryn   Ready    <none>   106m   v1.34.1   192.168.20.35   <none>        Ubuntu 22.04.5 LTS   5.15.0-181-generic   containerd://2.2.1

bash

    # Все поды в кластере
    kubectl --kubeconfig=~/diploma/yc-kubeconfig get pods --all-namespaces

Ожидаемый результат: системные поды в статусе Running, без ошибок.
Доступ к кластеру

Kubeconfig сохранён в ~/diploma/yc-kubeconfig. Все команды kubectl выполняются с флагом:

bash

    --kubeconfig=/home/relekt/diploma/yc-kubeconfig

## Этап 3. Создание тестового приложения

Описание

Тестовое приложение — веб-сервер на базе nginx, отдающий статическую страницу. Приложение упаковано в Docker-образ и хранится в Yandex Container Registry.
Структура репозитория

text

    diploma-app/
    ├── Dockerfile
    ├── nginx.conf
    └── html/
        └── index.html

Dockerfile

dockerfile

    FROM nginx:alpine
    COPY html/ /usr/share/nginx/html/
    COPY nginx.conf /etc/nginx/conf.d/default.conf
    EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]

Сборка и отправка в регистр

bash

    # Сборка образа
    docker build -t cr.yandex/crpjnakmdh5612ocuccu/diploma-app:v1.0.0 .

    # Отправка в Yandex Container Registry
    docker push cr.yandex/crpjnakmdh5612ocuccu/diploma-app:v1.0.0

Результат

    Git-репозиторий с тестовым приложением и Dockerfile;
    Docker-образ в Yandex Container Registry: cr.cloud.yandex.net/crpjnakmdh5612ocuccu/diploma-app:v1.0.0.

## Этап 4. Подготовка системы мониторинга и деплой приложения

4.1. Мониторинг (kube-prometheus)

Для мониторинга используется пакет kube-prometheus, включающий:

    Prometheus — сбор метрик;
    Grafana — визуализация;
    Alertmanager — алерты;
    Node Exporter — метрики узлов.

Установка

bash

# Добавление репозитория
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Установка kube-prometheus-stack
helm --kubeconfig=~/diploma/yc-kubeconfig install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=LoadBalancer

Проверка

bash

# Поды мониторинга
kubectl --kubeconfig=~/diploma/yc-kubeconfig get pods -n monitoring

# Сервис Grafana
kubectl --kubeconfig=~/diploma/yc-kubeconfig get svc -n monitoring | grep grafana

Доступ к Grafana:

    URL: http://<EXTERNAL-IP-Grafana>:80
    Логин: admin
    Пароль: prom-operator

4.2. Деплой приложения через Helm

Приложение развёртывается через Helm-чарт diploma-app-chart в неймспейсе diploma-project.
Конфигурация (values.yaml)

yaml

replicaCount: 2

image:
  repository: cr.cloud.yandex.net/crpjnakmdh5612ocuccu/diploma-app
  tag: v1.0.0
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "200m"
    memory: "256Mi"

Команды деплоя

bash

# Установка релиза
helm --kubeconfig=~/diploma/yc-kubeconfig install diploma-app ./ \
  --namespace diploma-project --create-namespace

# Обновление релиза
helm --kubeconfig=~/diploma/yc-kubeconfig upgrade diploma-app ./ \
  --namespace diploma-project

Проверка

bash

# Поды приложения
kubectl --kubeconfig=~/diploma/yc-kubeconfig get pods -n diploma-project

Ожидаемый результат:

text

NAME                                             READY   STATUS    RESTARTS   AGE
diploma-app-diploma-app-chart-7f574685bf-qt2sd   1/1     Running   0          19m
diploma-app-diploma-app-chart-7f574685bf-r6q5c   1/1     Running   0          19m

bash

# Сервис
kubectl --kubeconfig=~/diploma/yc-kubeconfig get svc -n diploma-project

Ожидаемый результат:

text

NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
diploma-app-diploma-app-chart   ClusterIP   172.17.200.188   <none>        80/TCP    14s

bash

# Endpoints
kubectl --kubeconfig=~/diploma/yc-kubeconfig describe svc diploma-app-diploma-app-chart -n diploma-project

Ожидаемый результат: секция Endpoints содержит IP подов:

text

Endpoints:  172.16.128.12:80,172.16.129.10:80

Внутренняя связность

bash

kubectl --kubeconfig=~/diploma/yc-kubeconfig exec -n diploma-project \
  diploma-app-diploma-app-chart-7f574685bf-qt2sd -- curl -v http://localhost

Ключевой маркер: HTTP/1.1 200 OK.
Статус Helm-релиза

bash

helm --kubeconfig=~/diploma/yc-kubeconfig status diploma-app -n diploma-project

Ожидаемый результат: STATUS: deployed.
Обоснование выбора ClusterIP

В тестовом окружении Yandex Cloud достигнут лимит на сетевые балансировщики нагрузки:

text

Quota limit ylb.networkLoadBalancers.count exceeded

Сервис переведён на тип ClusterIP:

    не расходует квоту на балансировщики;
    обеспечивает корректную внутреннюю маршрутизацию;
    является стандартным паттерном для микросервисов внутри кластера.

В продуктовой среде тип сервиса может быть изменён на LoadBalancer или настроен через Ingress-контроллер.
Локальная демонстрация

bash

kubectl --kubeconfig=~/diploma/yc-kubeconfig port-forward -n diploma-project <имя-пода> 8080:80

Затем открыть http://127.0.0.1:8080 в браузере.
4.3. Автоматизация Terraform через CI/CD

Вместо Terraform Cloud или Atlantis настроен автоматический запуск Terraform из CI/CD-пайплайна при коммите в main ветку. Пайплайн выполняет terraform plan и terraform apply без ручных действий.
Этап 5. Установка и настройка CI/CD
Инструмент: GitHub Actions (или GitLab CI)

CI/CD настраивается в репозитории с тестовым приложением.
Что автоматизировано

    CI (Continuous Integration):
        При любом коммите в репозиторий происходит сборка Docker-образа;
        Образ отправляется в Yandex Container Registry;
        Запускается линтер и тесты (если есть).

    CD (Continuous Deployment):
        При создании тега (например, v1.0.0) происходит сборка образа с соответствующим label;
        Образ отправляется в регистр;
        Приложение автоматически деплоится в Kubernetes-кластер через helm upgrade.

Схема работы

text

Коммит в main → Сборка Docker-образа → Push в Container Registry
Создание тега v*.*.* → Сборка образа с тегом → Push в Registry → Helm upgrade в кластере

Пример пайплайна (GitHub Actions)

yaml

name: CI/CD

on:
  push:
    branches: [ main ]
    tags: [ 'v*.*.*' ]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to Yandex Container Registry
        run: |
          echo "
