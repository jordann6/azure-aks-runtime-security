# Runtime Security: Controls and Detection Catalog

This lab layers three independent controls on a single AKS cluster and shows how
they overlap. The design principle is defense in depth: an attack that slips past
one layer is caught by the next.

## The three layers

| Layer | Tool | Acts at | Model |
| ----- | ---- | ------- | ----- |
| Admission | Kyverno | Pod create/update | Prevent — reject unsafe pods before they run |
| Runtime | Falco (modern eBPF) | Syscalls on the node | Detect — alert on malicious behavior in running pods |
| Cloud | Microsoft Defender for Containers | Subscription / control plane | Detect + posture — agentless discovery, image CVEs, control-plane threat alerts |

Kyverno and Falco are deliberately complementary. Kyverno stops the privileged,
hostPath, hostPID pod from ever being admitted in a policed namespace. Falco
assumes something still gets through (a namespace exemption, a compromised
workload, a zero-day) and watches what it does at runtime.

## Admission controls (Kyverno)

Every policy runs in `Enforce` mode and excludes only the system namespaces
(`kube-system`, `gatekeeper-system`, `falco`, `kyverno`).

| Policy | Blocks | Pod Security Standard |
| ------ | ------ | --------------------- |
| disallow-privileged-containers | `securityContext.privileged: true` | Baseline |
| require-run-as-nonroot | Containers without `runAsNonRoot: true` | Restricted |
| disallow-host-namespaces | `hostNetwork`, `hostPID`, `hostIPC` | Baseline |
| disallow-host-path | `hostPath` volumes | Baseline |

The policies are unit-tested offline with the Kyverno CLI against known-good and
known-bad pods (`k8s/kyverno/tests/`), and that test gates CI before any policy
is enforced on a cluster.

## Runtime detection (Falco)

Custom rules, each tagged with its MITRE ATT&CK technique so alerts line up with
the Navigator layer.

| Rule | Priority | Technique | Trigger |
| ---- | -------- | --------- | ------- |
| Terminal Shell in Container | WARNING | T1059 | `bash`/`sh`/`zsh` spawned in a container |
| Read Sensitive File in Container | WARNING | T1552 | Read of `/etc/shadow`, `/etc/passwd`, `/run/secrets` |
| Container Escape via Mount | CRITICAL | T1611 | `mount` targeting `/etc`, `/proc`, `/host` |
| Drop and Execute New Binary | WARNING | T1105 | Execution of a binary written into the container layer |
| Contact Cloud Metadata Service | WARNING | T1552.005 | Outbound connection to Azure IMDS `169.254.169.254` |

## Cloud detection (Defender for Containers)

Enabled as a subscription pricing plan and wired to the same Log Analytics
workspace as AKS diagnostics. It adds:

- Agentless image scanning for known CVEs in running images
- Control-plane threat alerts (for example, exec into a pod, a new high-privilege
  binding, or anomalous API server calls)
- Kubernetes posture recommendations mapped to the Microsoft cloud security
  benchmark

Falco covers node-level syscall behavior; Defender covers the Azure control plane
and image supply chain. Together they close the gap that any single agent leaves.

## Attack-to-detection map

The `k8s/attack-scenarios/run-runtime-attacks.sh` driver executes each technique
and you watch the matching control react:

1. Apply the vulnerable pod to `default` → **Kyverno denies it** (admission proof).
2. Re-run it in an exempt namespace → pod starts.
3. Spawn a shell → **Falco: Terminal Shell in Container**.
4. Read `/etc/shadow` and the service account token → **Falco: Read Sensitive File**.
5. Reach the host filesystem through the hostPath mount → **Falco: Container Escape via Mount**.
6. Drop and run a new binary → **Falco: Drop and Execute New Binary**.
7. Curl Azure IMDS → **Falco: Contact Cloud Metadata Service**.
