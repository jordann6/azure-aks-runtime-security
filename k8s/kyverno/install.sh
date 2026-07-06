#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

echo "Adding Kyverno Helm repo..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

echo "Installing Kyverno..."
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

echo "Waiting for Kyverno to be ready..."
kubectl wait --for=condition=available deployment \
  -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=180s

echo "Applying admission policies..."
kubectl apply -f "$here/policies/"

echo "Kyverno installation complete."
kubectl get clusterpolicy
