export \
  CLUSTER_NAME=incloud-k8s-local \
  CLUSTER_ENV=dev \
  CLUSTER_AREA=local \
  CLUSTER_INDEX=1 \
  K8S_VERSION=v1.31.0 \
  INCLOUD_COMPONENTS_VERSION=v1.0.0 \
  HELMFILE_RELEASE="netbox"

export \
  K8S_VERSION="${K8S_VERSION:-$(kubectl version | sed -n 's/.*Server Version:[[:space:]]*\(v[0-9.]*\).*/\1/p')}" \
  TMP_DIR=$(mktemp -d -p /tmp)

INCLOUD_COMPONENTS_VERSION_FILE="releases.d/incloud-releases/${INCLOUD_COMPONENTS_VERSION}.yaml"

cat ${INCLOUD_COMPONENTS_VERSION_FILE} | sed -E 's/^([A-Za-z0-9_]+):[[:space:]]*([^[:space:]]+).*/export \1="\2"/' > ${TMP_DIR}/components_versions.env
source ${TMP_DIR}/components_versions.env

helmfile \
  -e ${CLUSTER_ENV} \
  -l release=${HELMFILE_RELEASE} \
  --kube-version=${K8S_VERSION} \
  template
