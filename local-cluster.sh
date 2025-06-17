#!/bin/bash

LOCAL_CLUSTER_NAME="incloud-k8s-local-dev-local-1"

echo "--- start minikube with CNI=cilium"
minikube start \
  --cni=cilium \
  --dns-domain=${LOCAL_CLUSTER_NAME}.in-cloud.internal
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
echo "DEBUG: B-Cloud components version file: ${INCLOUD_COMPONENTS_VERSION_FILE}"

cat ${INCLOUD_COMPONENTS_VERSION_FILE} | sed -E 's/^([A-Za-z0-9_]+):[[:space:]]*([^[:space:]]+).*/export \1="\2"/' > ${TMP_DIR}/components_versions.env
source ${TMP_DIR}/components_versions.env

export \
  CLUSTER_NAME=incloud-k8s-local \
  CLUSTER_ENV=dev \
  CLUSTER_AREA=local \
  CLUSTER_INDEX=1


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


echo ""
echo "--- templating cilium"
helm template cilium ./charts/cilium/cilium-${CILIUM_VERSION}/cilium \
  --namespace kube-system \
  --set operator.replicas=1 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="10.244.0.0/16" \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 > ${TMP_DIR}/cilium.yaml
echo "--- deploy cilium"
kubectl apply -f ${TMP_DIR}/cilium.yaml
echo "--- waiting cilium"
kubectl -n kube-system wait ds cilium --for=jsonpath='{.status.numberAvailable}'=1 --timeout=180s


echo ""
echo "--- templating cert-manager"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=cert-manager \
  template > ${TMP_DIR}/cert-manager.yaml incloud-collections: "cert-manager"
echo "--- deploy cert-manager"
kubectl create ns incloud-cert-manager
kubectl apply -f ${TMP_DIR}/cert-manager.yaml
echo "----- waiting finish cert-manager startupapicheck"
kubectl -n incloud-cert-manager wait job/cert-manager-startupapicheck --for=jsonpath='{.status.succeeded}'=1 --timeout=180s
kubectl apply -f ${TMP_DIR}/cert-manager.yaml
echo "----- waiting run cert-manager webhook"
kubectl -n incloud-cert-manager wait deployment/cert-manager-webhook --for=jsonpath='{.status.readyReplicas}'=1 --timeout=180s
kubectl apply -f ${TMP_DIR}/cert-manager.yaml # деплоит сертификаты, которые в прошлую итерацию не создались из-за не работающей валидации


echo ""
echo "--- templating istio"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=istio \
  template > ${TMP_DIR}/istio.yaml
echo "--- deploy istio"
kubectl create ns incloud-istio
kubectl -n incloud-istio apply -f ${TMP_DIR}/istio.yaml
echo "--- waiting run istiod"
kubectl -n incloud-istio wait deployment/istiod --for=jsonpath='{.status.readyReplicas}'=1 --timeout=180s
for i in {1..2}
do
  kubectl -n incloud-istio apply -f ${TMP_DIR}/istio.yaml
done


echo ""
echo "--- templating dex"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=dex \
  template > ${TMP_DIR}/dex.yaml
echo "--- deploy dex"
kubectl create ns incloud-idp
for i in {1..3}
do
  kubectl -n incloud-idp apply -f ${TMP_DIR}/dex.yaml
done


echo ""
echo "--- templating netbox"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=netbox \
  template > ${TMP_DIR}/netbox.yaml
echo "--- deploy netbox"
kubectl create ns incloud-netbox
for i in {1..3}
do
  kubectl -n incloud-netbox apply -f ${TMP_DIR}/netbox.yaml
done


echo ""
echo "--- templating sgroups"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=sgroups \
  template > ${TMP_DIR}/sgroups.yaml
echo "--- deploy sgroups"
kubectl create ns incloud-sgroups
for i in {1..3}
do
  kubectl -n incloud-sgroups apply -f ${TMP_DIR}/sgroups.yaml
done


echo ""
echo "--- templating sgroups-provider"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=sgroups-provider \
  template > ${TMP_DIR}/sgroups-provider.yaml
echo "--- deploy sgroups-provider"
kubectl create ns incloud-sgroups
for i in {1..3}
do
  kubectl -n incloud-sgroups apply -f ${TMP_DIR}/sgroups-provider.yaml
done


echo ""
echo "--- templating sgroups-resources"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=sgroups-resources \
  template > ${TMP_DIR}/sgroups-resources.yaml
echo "--- deploy sgroups-resources"
kubectl create ns incloud-sgroups
for i in {1..3}
do
  kubectl -n incloud-sgroups apply -f ${TMP_DIR}/sgroups-resources.yaml
done


echo ""
echo "--- templating sgroups-to-nft"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=to-nft \
  template > ${TMP_DIR}/sgroups-to-nft.yaml
echo "--- deploy sgroups-to-nft"
kubectl create ns incloud-sgroups
for i in {1..3}
do
  kubectl -n incloud-sgroups apply -f ${TMP_DIR}/sgroups-to-nft.yaml
done


echo ""
echo "--- templating netguard"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=netguard \
  template > ${TMP_DIR}/netguard.yaml
echo "--- deploy netguard"
kubectl create ns incloud-sgroups
for i in {1..3}
do
  kubectl -n incloud-sgroups apply -f ${TMP_DIR}/netguard.yaml
done


echo ""
echo "--- templating incloud-web"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=incloud-web \
  template > ${TMP_DIR}/incloud-web.yaml
echo "--- deploy incloud-web"
kubectl create ns incloud-web
for i in {1..3}
do
  kubectl -n incloud-web apply -f ${TMP_DIR}/incloud-web.yaml
done

echo ""
echo "--- templating crossplane"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=crossplane \
  template > ${TMP_DIR}/crossplane.yaml
echo "--- deploy crossplane"
kubectl create ns incloud-crossplane
kubectl -n incloud-crossplane apply -f ${TMP_DIR}/crossplane.yaml
kubectl -n incloud-crossplane wait deployment/crossplane-crossplane --for=jsonpath='{.status.readyReplicas}'=1 --timeout=180s
for i in {1..2}
do
  kubectl -n incloud-crossplane apply -f ${TMP_DIR}/crossplane.yaml --server-side
  sleep 10
done


echo ""
echo "--- templating crossplane-incloud"
helmfile \
  -e dev \
  --kube-version=${K8S_VERSION} \
  -l incloud-collections=crossplane-incloud \
  template > ${TMP_DIR}/crossplane-incloud.yaml
echo "--- deploy crossplane-incloud"
kubectl create ns incloud-crossplane
for i in {1..10}
do
  kubectl -n incloud-crossplane apply -f ${TMP_DIR}/crossplane-incloud.yaml && break
  sleep 30
done

echo ""
echo ""
echo "--- INFO"
echo "Если получить доступ к локальному веб-интерфесу, то нужно:"
echo "1. Добавить запись в /etc/hosts:"
echo "127.0.0.1 dex.incloud-idp.svc.incloud-k8s-local-dev-local-1.in-cloud.internal netbox.incloud-netbox.svc.incloud-k8s-local-dev-local-1.in-cloud.internal sgroups.incloud-sgroups.svc.incloud-k8s-local-dev-local-1.in-cloud.internal incloud.incloud-web.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo ""
echo "2. Запустить проброс порта, выполнив команду:"
echo "sudo kubectl -n incloud-istio port-forward svc/istio-ingressgateway 443:443"
echo ""
echo "3. После выполнения команды можно будет перейти по адресам:"
# echo "  - https://dex.incloud-idp.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
# echo "  - https://netbox.incloud-netbox.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
# echo "  - https://sgroups.incloud-sgroups.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
echo "  - https://incloud.incloud-web.svc.incloud-k8s-local-dev-local-1.in-cloud.internal"
