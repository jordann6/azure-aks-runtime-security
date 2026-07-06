#!/usr/bin/env bash
set -euo pipefail

echo "Adding Falco Helm repo..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

echo "Installing Falco with modern eBPF driver on AKS..."
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  -f "$(dirname "$0")/values.yaml"

echo "Waiting for Falco pods..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=falco -n falco --timeout=180s

echo "Falco installation complete."
kubectl get pods -n falco
