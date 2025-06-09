#!/bin/bash

# echo "--- start minikube with CNI=cilium"
# minikube start \
#    --cni=cilium

TMP_DIR=$(mktemp -d -p /tmp)
echo "DEBUG: tmp directory: ${TMP_DIR} "

export K8S_VERSION=$(kubectl version | sed -n 's/.*Server Version:[[:space:]]*\(v[0-9.]*\).*/\1/p')
echo ""
echo "Kubernetes version: ${K8S_VERSION}"

INCLOUD_COMPONENTS_VERSION=$(cat vars/02-clusters/incloud-k8s-local-dev-local-1/incloud-k8s-local-dev-local-1.yaml | sed -n 's/.*incloudComponentsVersion:[[:space:]]*\(v[0-9.]*\).*/\1/p')
INCLOUD_COMPONENTS_VERSION_FILE="releases.d/incloud-releases/${INCLOUD_COMPONENTS_VERSION}.yaml"
echo "DEBUG: B-Cloud components version file: ${INCLOUD_COMPONENTS_VERSION_FILE}"

cat ${INCLOUD_COMPONENTS_VERSION_FILE} | sed -E 's/^([A-Za-z0-9_]+):[[:space:]]*([^[:space:]]+).*/export \1="\2"/' > ${TMP_DIR}/components_versions.env
source ${TMP_DIR}/components_versions.env

export \
  CLUSTER_NAME=incloud-k8s-local \
  CLUSTER_ENV=dev \
  CLUSTER_AREA=local \
  CLUSTER_INDEX=1

# echo ""
# echo "--- set anonimous admin role"
# kubectl apply -f - <<EOF
# ---
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: admin-clusterrole
# rules:
#   - apiGroups:
#       - "*"
#     resources:
#       - "*"
#     verbs:
#       - "*"
# ---
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: anonymous-clusterrolebinding
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: admin-clusterrole
# subjects:
# - apiGroup: rbac.authorization.k8s.io
#   kind: User
#   name: system:anonymous
# EOF

# echo ""
# echo "--- templating cilium"
# helm template cilium ./charts/cilium/cilium-${CILIUM_VERSION}/cilium \
#   --namespace kube-system \
#   --set operator.replicas=1 \
#   --set ipam.operator.clusterPoolIPv4PodCIDRList="10.244.0.0/16" \
#   --set ipam.operator.clusterPoolIPv4MaskSize=24 > ${TMP_DIR}/cilium.yaml
# echo "--- deploy cilium"
# kubectl apply -f ${TMP_DIR}/cilium.yaml


# echo ""
# echo "--- templating cert-manager"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=cert-manager \
#   template > ${TMP_DIR}/cert-manager.yaml incloud-collections: "cert-manager"
# echo "--- deploy cert-manager"
# kubectl create ns incloud-cert-manager
# kubectl apply -f ${TMP_DIR}/cert-manager.yaml
# echo "----- waiting finish cert-manager startupapicheck"
# kubectl -n incloud-cert-manager wait job/cert-manager-startupapicheck --for=jsonpath='{.status.succeeded}'=1 --timeout=180s
# kubectl apply -f ${TMP_DIR}/cert-manager.yaml
# echo "----- waiting run cert-manager webhook"
# kubectl -n incloud-cert-manager wait deployment/cert-manager-webhook --for=jsonpath='{.status.readyReplicas}'=1 --timeout=180s
# kubectl apply -f ${TMP_DIR}/cert-manager.yaml # деплоит сертификаты, которые в прошлую итерацию не создались из-за не работающей валидации


# echo ""
# echo "--- templating istio"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=istio \
#   template > ${TMP_DIR}/istio.yaml
# echo "--- deploy istio"
# kubectl create ns incloud-istio
# kubectl apply -f ${TMP_DIR}/istio.yaml
# echo "--- waiting run istiod"
# kubectl -n incloud-istio wait deployment/istiod --for=jsonpath='{.status.readyReplicas}'=1 --timeout=180s
# for i in {1..2}
# do
#   kubectl apply -f ${TMP_DIR}/istio.yaml
# done


# echo ""
# echo "--- templating netbox"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=netbox \
#   template > ${TMP_DIR}/netbox.yaml
# echo "--- deploy netbox"
# kubectl create ns incloud-netbox
# for i in {1..3}
# do
#   kubectl apply -f ${TMP_DIR}/netbox.yaml
# done


# echo ""
# echo "--- templating sgroups"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=sgroups \
#   template > ${TMP_DIR}/sgroups.yaml
# echo "--- deploy sgroups"
# kubectl create ns incloud-sgroups
# for i in {1..3}
# do
#   kubectl apply -f ${TMP_DIR}/sgroups.yaml
# done


# echo ""
# echo "--- templating sgroups-provider"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=sgroups-provider \
#   template > ${TMP_DIR}/sgroups-provider.yaml
# echo "--- deploy sgroups-provider"
# kubectl create ns incloud-sgroups
# for i in {1..3}
# do
#   kubectl apply -f ${TMP_DIR}/sgroups-provider.yaml
# done


# echo ""
# echo "--- templating sgroups-resources"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=sgroups-resources \
#   template > ${TMP_DIR}/sgroups-resources.yaml
# echo "--- deploy sgroups-resources"
# kubectl create ns incloud-sgroups
# for i in {1..3}
# do
#   kubectl apply -f ${TMP_DIR}/sgroups-resources.yaml
# done


# echo ""
# echo "--- templating sgroups-to-nft"
# helmfile \
#   -e dev \
#   --kube-version=${K8S_VERSION} \
#   -l incloud-collections=to-nft \
#   template > ${TMP_DIR}/sgroups-to-nft.yaml
# echo "--- deploy sgroups-to-nft"
# kubectl create ns incloud-sgroups
# for i in {1..3}
# do
#   kubectl apply -f ${TMP_DIR}/sgroups-to-nft.yaml
# done


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
  kubectl apply -f ${TMP_DIR}/netguard.yaml
done

