#!/usr/bin/env bash
# Drives the runtime attack scenarios the Falco rules are built to catch, and
# demonstrates the two-layer control model:
#   1. Admission (Kyverno) blocks the vulnerable pod in a policed namespace.
#   2. Runtime (Falco) detects the attacks once the pod runs in an exempt one.
# Requires: kubectl context on the lab cluster, Falco + Kyverno installed.
set -euo pipefail

POD=vulnerable-app
ATTACK_NS=attack-lab
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/4] Proving admission control: apply the vulnerable pod to 'default'"
# Kyverno returns a non-zero exit when it denies the pod, which is the success
# case here, so branch on the exit code rather than grepping through a pipe.
if out=$(kubectl apply -f "$here/vulnerable-pod.yaml" -n default 2>&1); then
  echo "  -> WARNING: pod was NOT blocked. Is Kyverno installed and enforcing?"
  echo "$out"
  kubectl delete pod "$POD" -n default --ignore-not-found
else
  echo "$out" | sed 's/^/    /'
  echo "  -> Kyverno correctly BLOCKED the privileged/hostPath/hostPID pod."
fi

echo "[2/4] Creating an exempt namespace to host the runtime demo"
kubectl create namespace "$ATTACK_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$ATTACK_NS" purpose=runtime-attack-demo --overwrite
kubectl apply -f "$here/vulnerable-pod.yaml" -n "$ATTACK_NS"
kubectl wait --for=condition=ready "pod/$POD" -n "$ATTACK_NS" --timeout=120s

echo "[3/4] Streaming Falco alerts (background)"
falco_pod="$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o name | head -1)"
kubectl logs -f -n falco "$falco_pod" 2>/dev/null \
  | grep --line-buffered -iE 'shell|sensitive|escape|binary|metadata' &
tail_pid=$!
sleep 3

run() { echo; echo ">>> $1"; kubectl exec "$POD" -n "$ATTACK_NS" -- sh -c "$2" 2>/dev/null || true; sleep 2; }

echo "[4/4] Executing attack techniques"
run "T1059 Terminal shell in container"           "bash -c 'echo shell-spawned'"
run "T1552 Read /etc/shadow (credential access)"  "cat /etc/shadow || true"
run "T1552 Read service account token"            "cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || echo no-token"
run "T1611 Container escape via host mount"       "mount --bind /host/etc /mnt 2>/dev/null; ls /host/etc >/dev/null && echo host-fs-reachable"
run "T1105 Drop and execute new binary"           "cp /bin/echo /tmp/dropped && /tmp/dropped executed"
run "T1552.005 Reach Azure IMDS"                  "bash -c 'timeout 3 bash -c \"exec 3<>/dev/tcp/169.254.169.254/80 && echo reached-imds\"' 2>/dev/null || true"

sleep 3
kill "$tail_pid" 2>/dev/null || true
echo
echo "Done. Review full alert history:"
echo "  kubectl logs -n falco $falco_pod | grep -iE 'Warning|Critical'"
echo "Cleanup:  kubectl delete namespace $ATTACK_NS"
