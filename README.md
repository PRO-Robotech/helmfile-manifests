# Platform manifests repository

[[_TOC_]]

# 1. manifests

Репозиторий для общих компонентов платформенных кластеров

# 2. Зачем

Катаем все общие вещи отсюда (etcd-backup/linstor/prometheus и прочее)


# 3. когда приложение считается доступным для раскатки?

Когда существует описанный флоу по раскатке в любом кластере, включая сборку образов


# 4. Helmfile и добавление нового кластера

### 4.1 ENVIRONMENTS

```bash
CLUSTER_NAME        - Имя группы кластеров
  Пример:
    - dzen-prod-msk1  | CLUSTER_NAME=dzen
    - pfm-prod-msk1   | CLUSTER_NAME=pfm

CLUSTER_ENV         - Паттерн среды окружения, подразумевается как DEV|STAGE|PROD
  Пример:
    - pfm-dev-msk1    | CLUSTER_ENV=dev
    - pfm-stage-spb1  | CLUSTER_ENV=stage
    - pfm-prod-spb1   | CLUSTER_ENV=prod

CLUSTER_AREA        - Паттерн территории, в частности Москва (msk) и Питер (spb)
  Пример:
    - pfm-prod-msk1   | CLUSTER_AREA=msk
    - pfm-prod-spb1   | CLUSTER_AREA=spb

CLUSTER_INDEX       - Порядковый номер кластера в группе маски 
  Пример:
    - pfm-stage-msk1  | CLUSTER_INDEX=1
    - pfm-stage-msk2  | CLUSTER_INDEX=2
    
```

Helm чарты можно раскатывать через helmfile, для этого необходимо:

1. Разложить values согласно иерархии (отсутсвие файла игнорируется):
    ```bash
    vars
    ├── 00-globals                    # Директория с глобальными настройками
    │  ├── 00-common.yaml             # Общие values, для всех чартов всех кластеров
    │  └── 10-networkAddresses.yaml   # Разные полезные сетевые префиксы
    ├── 01-charts                     # Директорися в которой находятся директории с values для конкретных чартов
    │  └── csi-s3                     # Директория с values для чарта csi-s3, внутри доступны варианты файлов common.yaml, common.yaml.gotmpl, common-<env>.yaml, common-<env>.yaml.gotmpl
    └── 02-clusters                   # Директория с values для конкретного кластера
       └── my                         # Директория с values для кластера my + конкретного чарта в кластере
          └── csi-s3                  # Директория с values для чарта csi-s3 в кластере my, доступны варианты файлов common.yaml, common.yaml.gotmpl, common-<env>.yaml, common-<env>.yaml.gotmpl
    ```

    Чем ближе значение к релизу тем выше приоритет у значения (переопределяет значения с меньшим приоритетом)

2. Создать файл (если отсутсвует) `vars/02-clusters/<cluster_name>/releases.helmfile`

3. Добавить туда необходимый релиз (ниже приведены базово необходимые значения)
    ```yaml
    releases:
    - name: etcd-backup
      namespace: incloud-infra
      chart: etcd-backup/chart
      <<: *default
    ```


    Если переменные окружения не выставлены, helmfile упадет с ошибкой. Для джобы использовать образ с установленным `helmfile`, `helm`, `kustomize`, `helmdiff`

# 4. Генерация *.yaml.gotmpl

Helmfile имеет возможность генерировать переменные для helm-чартов на основе шаблонов. В данный момент для генерации таких шаблонов доступны следующие values:
- vars/00-globals/10-networkAddresses.yaml
- vars/02-clusters<CLUSTER_NAME>common.yaml
- vars/02-clusters<CLUSTER_NAME>-<environment>.yaml

Подробнее подключаемые values можно посмотреть в [helmfile.yaml](helmfile.yaml).


# 5. FAQ
## Известные ошибки
### Error: the lock file (Chart.lock) is out of sync with the dependencies file (Chart.yaml). Please update the dependencies
- Зайти в Charts.yaml
- поменять `apiVersion: v2` на `apiVersion: v1` (депсы на лету добавляются (helm-inserter), это бага)
### Нерабочие releases.helmfile dependencies
Из-за использования dependencies в templates.yaml и подставлением их через "<<: \*default" в releases.helmfile они перетирают основную секцию dependencies. В данный момент эта проблема не решена, поскольку решили использовать subcharts у основного чарта вместо подключения зависимостей через helmfile. Поэтому вместо определения зависимостей посредством helmfile рекомендуется использовать зависимости самого чарта и отключать их через заданные в Chart.yaml conditions.
