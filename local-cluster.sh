#!/bin/bash


echo "!!!ОБЯЗАТЕЛЬНО к прочтению!!!"
echo "Необходимо указать ваши логин/токен от GitHub в настройках ArgoCD, иначе на локальном стенде не будут развернуты приложения."
echo "Для этого нужно:"
echo "  - Перейти в директорию:"
echo "      cd vars/02-clusters/incloud-k8s-local-dev-local-1/argoproj/argo-cd"
echo "  - Скопировать файл argocd.yaml.example в argocd.yaml:"
echo "      cp argocd.yaml.example argocd.yaml"
echo "  - Открыть файл argocd.yaml в редакторе и указать ваши учетные данные GitHub (нужно сгенерировать личный токен с правами на чтение репозиториев)"
echo ""


read -p "Нажмите Enter для продолжения или Ctrl+C для выхода... " input


LOCAL_CLUSTER_NAME="incloud-k8s-local-dev-local-1"

echo "--- start minikube with CNI=cilium"
minikube start \
  --cni=cilium \
  --dns-domain=${LOCAL_CLUSTER_NAME}.in-cloud.internal \
  --driver=docker \
  --cpus=3 \
  --memory=6144 \
  -p=incloud
  # --extra-config=apiserver.oidc-issuer-url="https://dex.incloud-idp.svc.${LOCAL_CLUSTER_NAME}.in-cloud.internal" \
  # --extra-config=apiserver.oidc-username-claim=email \
  # --extra-config=apiserver.oidc-client-id=incloud \

TMP_DIR=$(mktemp -d -p /tmp)
echo "DEBUG: tmp directory: ${TMP_DIR} "

export K8S_VERSION=$(kubectl version | sed -n 's/.*Server Version:[[:space:]]*\(v[0-9.]*\).*/\1/p')
echo ""
echo "Kubernetes version: ${K8S_VERSION}"

INCLOUD_COMPONENTS_VERSION=$(cat vars/02-clusters/${LOCAL_CLUSTER_NAME}/${LOCAL_CLUSTER_NAME}.yaml | sed -n 's/.*incloudComponentsVersion:[[:space:]]*\(v[0-9.]*\).*/\1/p')
INCLOUD_COMPONENTS_VERSION_FILE="releases.d/incloud-releases/${INCLOUD_COMPONENTS_VERSION}.yaml"
echo "DEBUG: In-Cloud components version file: ${INCLOUD_COMPONENTS_VERSION_FILE}"

cat ${INCLOUD_COMPONENTS_VERSION_FILE} | sed -E 's/^([A-Za-z0-9_]+):[[:space:]]*([^[:space:]]+).*/export \1="\2"/' > ${TMP_DIR}/components_versions.env
source ${TMP_DIR}/components_versions.env

export \
  CLUSTER_NAME=incloud-k8s-local \
  CLUSTER_ENV=dev \
  CLUSTER_AREA=local \
  CLUSTER_INDEX=1 \
  ARGOCD_APPLICATION_BRANCH="$(git branch --show-current)" \
  ARGOCD_APPLICATION_REPO="https://github.com/PRO-Robotech/helmfile-manifests.git"


echo ""
echo "--- create admin role & admin user"
kubectl apply -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admin-clusterrole
rules:
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - "*"
  - nonResourceURLs:
      - "*"
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin-clusterrole
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: admin@in-cloud.internal
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: anonymous-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin-clusterrole
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: system:anonymous
EOF


# echo ""
# echo "--- templating cilium"
# helm template cilium ./charts/cilium/cilium-${CILIUM_VERSION}/cilium \
#   --namespace kube-system \
#   --set operator.replicas=1 \
#   --set ipam.operator.clusterPoolIPv4PodCIDRList="10.244.0.0/16" \
#   --set ipam.operator.clusterPoolIPv4MaskSize=24 > ${TMP_DIR}/cilium.yaml
# echo "--- deploy cilium"
# kubectl apply -f ${TMP_DIR}/cilium.yaml
# echo "--- waiting cilium"
# kubectl -n kube-system wait ds/cilium --for=jsonpath='{.status.numberReady}'=1 --timeout=180s


# echo ""
# echo "--- install istio CRDs"
# kubectl apply -f ./charts/istio-release/base-${ISTIO_VERSION}/base/files/crd-all.gen.yaml


echo ""
echo "--- templating argocd"
helmfile \
  -e ${CLUSTER_ENV} \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=argocd \
  template > ${TMP_DIR}/argocd.yaml
echo "--- deploy argocd"
kubectl create ns incloud-argocd
kubectl -n incloud-argocd apply -f ${TMP_DIR}/argocd.yaml
kubectl -n incloud-argocd wait deployment/argocd-repo-server --for=jsonpath='{.status.availableReplicas}'=1 --timeout=300s
kubectl -n incloud-argocd apply -f ${TMP_DIR}/argocd.yaml
kubectl -n incloud-argocd wait job/argocd-redis-secret-init --for=jsonpath='{.status.succeeded}'=1 --timeout=180s


echo ""
echo "--- create argocd app: cert-manager"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-cert-manager
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=cert-manager --namespace="incloud-cert-manager"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: CERT_MANAGER_VERSION
        value: ${CERT_MANAGER_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: istio"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-istio
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=istio --namespace="incloud-istio"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: ISTIO_VERSION
        value: ${ISTIO_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} ISTIO_VERSION=${ISTIO_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: dex"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dex
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-idp
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=dex --namespace="incloud-idp"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: ISTIO_VERSION
        value: ${ISTIO_VERSION}
      - name: POSTGRES_VERSION
        value: ${POSTGRES_VERSION}
      - name: DEX_VERSION
        value: ${DEX_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} ISTIO_VERSION=${ISTIO_VERSION} POSTGRES_VERSION=${POSTGRES_VERSION} DEX_VERSION=${DEX_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: netbox"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: netbox
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-netbox
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=netbox --namespace="incloud-netbox"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: ISTIO_VERSION
        value: ${ISTIO_VERSION}
      - name: POSTGRES_VERSION
        value: ${POSTGRES_VERSION}
      - name: NETBOX_VERSION
        value: ${NETBOX_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} ISTIO_VERSION=${ISTIO_VERSION} POSTGRES_VERSION=${POSTGRES_VERSION} NETBOX_VERSION=${NETBOX_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: sgroups"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sgroups
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-sgroups
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=sgroups --namespace="incloud-sgroups"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: ISTIO_VERSION
        value: ${ISTIO_VERSION}
      - name: POSTGRES_VERSION
        value: ${POSTGRES_VERSION}
      - name: SGROUPS_VERSION
        value: ${SGROUPS_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} ISTIO_VERSION=${ISTIO_VERSION} POSTGRES_VERSION=${POSTGRES_VERSION} SGROUPS_VERSION=${SGROUPS_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: sgroups-provider"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sgroups-provider
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-sgroups
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=sgroups-provider --namespace="incloud-sgroups"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: SGROUPS_PROVIDER_VERSION
        value: ${SGROUPS_PROVIDER_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} SGROUPS_PROVIDER_VERSION=${SGROUPS_PROVIDER_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: sgroups-resources"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sgroups-resources
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-sgroups
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=sgroups-resources --namespace="incloud-sgroups"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: SGROUPS_RESOURCES_VERSION
        value: ${SGROUPS_RESOURCES_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} SGROUPS_RESOURCES_VERSION=${SGROUPS_RESOURCES_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: sgroups-to-nft"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: to-nft
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-sgroups
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=to-nft --namespace="incloud-sgroups"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: TO_NFT_VERSION
        value: ${TO_NFT_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} TO_NFT_VERSION=${TO_NFT_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: sgroups-netguard"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: netguard
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-sgroups
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=netguard --namespace="incloud-sgroups"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: NETGUARD_VERSION
        value: ${NETGUARD_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} NETGUARD_VERSION=${NETGUARD_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: incloud-web"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: incloud-web
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-web
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=incloud-web --namespace="incloud-web"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: ISTIO_VERSION
        value: ${ISTIO_VERSION}
      - name: INCLOUD_WEB_VERSION
        value: ${INCLOUD_WEB_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} ISTIO_VERSION=${ISTIO_VERSION} INCLOUD_WEB_VERSION=${INCLOUD_WEB_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


echo ""
echo "--- create argocd app: crossplane"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-crossplane
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=crossplane --namespace="incloud-crossplane"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: CROSSPLANE_VERSION
        value: ${CROSSPLANE_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} CROSSPLANE_VERSION=${CROSSPLANE_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    - Replace=true
EOF


echo ""
echo "--- create argocd app: crossplane-incloud"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane-incloud
  namespace: incloud-argocd
spec:
  destination:
    namespace: incloud-crossplane
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      env:
      - name: helmfile_args
        value: -e ${CLUSTER_ENV} -l incloud-collections=crossplane-incloud --namespace="incloud-crossplane"
      - name: CLUSTER_AREA
        value: ${CLUSTER_AREA}
      - name: CLUSTER_ENV
        value: ${CLUSTER_ENV}
      - name: CLUSTER_INDEX
        value: "${CLUSTER_INDEX}"
      - name: CLUSTER_NAME
        value: ${CLUSTER_NAME}
      - name: CROSSPLANE_INCLOUD_VERSION
        value: ${CROSSPLANE_INCLOUD_VERSION}
      - name: helmfile_envs
        value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} CROSSPLANE_INCLOUD_VERSION=${CROSSPLANE_INCLOUD_VERSION}
      name: helmfile-with-args
    repoURL: ${ARGOCD_APPLICATION_REPO}
    targetRevision: ${ARGOCD_APPLICATION_BRANCH}
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
EOF


# echo ""
# echo "--- create argocd app: osconsole"
# kubectl apply -f - <<EOF
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: console-incloud
#   namespace: incloud-argocd
# spec:
#   destination:
#     namespace: incloud-console
#     server: https://kubernetes.default.svc
#   project: default
#   source:
#     path: .
#     plugin:
#       env:
#       - name: helmfile_args
#         value: -e ${CLUSTER_ENV} -l incloud-collections=openshift-console --namespace=incloud-console
#       - name: CLUSTER_AREA
#         value: ${CLUSTER_AREA}
#       - name: CLUSTER_ENV
#         value: ${CLUSTER_ENV}
#       - name: CLUSTER_INDEX
#         value: "${CLUSTER_INDEX}"
#       - name: CLUSTER_NAME
#         value: ${CLUSTER_NAME}
#       - name: OPENSHIFT_CONSOLE_CUSTOMIZATION_PLUGIN_VERSION
#         value: ${OPENSHIFT_CONSOLE_CUSTOMIZATION_PLUGIN_VERSION}
#       - name: OPENSHIFT_CONSOLE_VERSION
#         value: ${OPENSHIFT_CONSOLE_VERSION}
#       - name: ISTIO_VERSION
#         value: ${ISTIO_VERSION}
#       - name: helmfile_envs
#         value: CLUSTER_AREA=${CLUSTER_AREA} CLUSTER_ENV=${CLUSTER_ENV} CLUSTER_INDEX=${CLUSTER_INDEX} CLUSTER_NAME=${CLUSTER_NAME} OPENSHIFT_CONSOLE_CUSTOMIZATION_PLUGIN_VERSION=${OPENSHIFT_CONSOLE_CUSTOMIZATION_PLUGIN_VERSION} OPENSHIFT_CONSOLE_VERSION=${OPENSHIFT_CONSOLE_VERSION} ISTIO_VERSION=${ISTIO_VERSION}
#       name: helmfile-with-args
#     repoURL: ${ARGOCD_APPLICATION_REPO}
#     targetRevision: ${ARGOCD_APPLICATION_BRANCH}
#   syncPolicy:
#     syncOptions:
#     - CreateNamespace=true
# EOF


echo ""
echo "---------"
echo "--- Доступ к основным локальным сервисам"
echo "Чтобы получить доступ к локальным веб-интерфесам, нужно:"
echo "1. Добавить запись в /etc/hosts:"
echo "127.0.0.1 argocd.incloud-argocd.svc.incloud-k8s-local-dev-local-1.in-cloud.internal dex.incloud-idp.svc.incloud-k8s-local-dev-local-1.in-cloud.internal netbox.incloud-netbox.svc.incloud-k8s-local-dev-local-1.in-cloud.internal sgroups.incloud-sgroups.svc.incloud-k8s-local-dev-local-1.in-cloud.internal incloud.incloud-web.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo ""
echo "2. Запустить проброс порта, выполнив команду:"
echo "sudo kubectl -n incloud-istio port-forward svc/istio-ingressgateway 443:443"
echo ""
echo "3. После выполнения команды можно будет перейти по адресам:"
# echo "  - https://dex.incloud-idp.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo "Netbox: https://netbox.incloud-netbox.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo "Учетная запись по-умолчанию:"
echo "username: admin"
echo "password: admin"
echo ""
echo "Sgroups: https://sgroups.incloud-sgroups.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo ""
echo "In-Cloud: https://incloud.incloud-web.svc.incloud-k8s-local-dev-local-1.in-cloud.internal/openapi-ui"


echo ""
echo "---------"
echo "--- Доступ к ArgoCD"
echo "ArgoCD будет доступен по адресу: https://localhost:8080"
echo "После выполнения команды: kubectl -n incloud-argocd port-forward svc/argocd-server 8080:443"
echo "Учетная запись по-умолчанию:"
echo "username: admin"
echo "password: admin"
