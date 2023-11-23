#!/bin/sh

set -o errexit
set -o nounset
set -o pipefail

echo "Starting Post Create Command"

az extension add --name connectedk8s
az extension add --name k8s-extension
az extension add --name azure-iot-ops

# This env var is important to allow k3s to support shared mounts, required for CSI driver
# Temporary fix until made default https://github.com/k3d-io/k3d/pull/1268#issuecomment-1745466499
export K3D_FIX_MOUNTS=1

# Create local registry for K3D and local development
# TODO make this script idempotent (check for pre-existing registry and cluster)
k3d registry create devregistry.localhost --port 5500

# Create k3d cluster with NFS support and forwarded ports
# See https://github.com/jlian/k3d-nfs
k3d cluster create devcluster --registry-use k3d-devregistry.localhost:5500 -i ghcr.io/jlian/k3d-nfs:v1.25.3-k3s1 \
-p '1883:1883@loadbalancer' \
-p '8883:8883@loadbalancer' \
-p '6001:6001@loadbalancer' \
-p '4000:80@loadbalancer'

helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr --version=1.11 --namespace dapr-system --create-namespace --wait

echo "Ending Post Create Command"
