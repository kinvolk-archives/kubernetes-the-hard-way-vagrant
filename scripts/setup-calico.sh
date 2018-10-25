#!/usr/bin/bash

set -euo pipefail

readonly dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly base="https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation"
readonly dl_manifest_dir="${dir}/manifests/downloaded/calico"
readonly cluster_cidr='10.200.0.0/16'

mkdir -p "${dl_manifest_dir}"
pushd "${dl_manifest_dir}"
trap 'popd' EXIT

curl "${base}/hosted/rbac-kdd.yaml" -o calico-kdd-rbac.yaml
curl "${base}/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml" -o calico-kdd-calico.yaml

# find a line with "name: CALICO_IPV4POOL_CIDR", change the value in
# the next line to use our cluster_cidr
sed -i'' -e '/- name: CALICO_IPV4POOL_CIDR/!b;n;s!^\(.*value:\).*!\1 "'"${cluster_cidr}"'"!' calico-kdd-calico.yaml

kubectl apply -f calico-kdd-rbac.yaml
kubectl apply -f calico-kdd-calico.yaml
