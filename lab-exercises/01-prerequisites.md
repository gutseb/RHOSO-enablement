# Lab 01 — Install Prerequisites

## Objective

Verify your environment, install kustomize, and confirm that the OpenShift GitOps
(ArgoCD) operator is already installed by the lab provisioner. By the end of this
lab the bastion will have `kustomize` available, your fork will be cloned to
`~/labrepo`, and you will be logged into the OpenShift cluster.

## Prerequisites

- Completed [Lab 00 — Setup](00-setup.md)
- `vars.yml` updated with your `lab_guid` and `github_id`
- Vault file encrypted (`setup-vault.sh` completed)

## Run the Automation

```bash
ansible-playbook playbooks/01-gitops-operators.yml --ask-vault-pass
```

This will:
1. Assert required variables are set
2. Log in to OCP (`oc login`)
3. Install kustomize v5.6.0 to `/usr/local/bin/kustomize`
4. Clone your fork to `~/labrepo`
5. Install NMState and MetalLB operators via OLM
6. Verify cert-manager is running

## What Gets Installed

| Operator | Namespace | Purpose |
|---|---|---|
| NMState | `openshift-nmstate` | Node network config for RHOSO isolated networks |
| MetalLB | `metallb-system` | Bare-metal load balancer for OpenStack endpoints |
| cert-manager | `cert-manager` | TLS certificate management (TLS-everywhere) |

## Manual Verification

### Access the OpenShift GitOps (ArgoCD) console

```bash
# Get the ArgoCD admin password
argoPass=$(oc get secret/openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' | base64 -d)
echo $argoPass

# Get the ArgoCD console URL
argoURL=$(oc get route openshift-gitops-server -n openshift-gitops \
  -o jsonpath='{.spec.host}{"\n"}')
echo $argoURL
```

Open `https://$argoURL` in a browser and log in with username `admin` and the password above.

### Verify NMState operator

```bash
oc get pods -n openshift-nmstate
```

Expected: `nmstate-operator-*`, `nmstate-handler-*` (one per node), and `nmstate-webhook-*` pods all `Running`.

### Verify MetalLB operator

```bash
oc get pods -n metallb-system
```

Expected: `controller-*`, `metallb-operator-*`, and `speaker-*` pods all `Running`.

### Verify cert-manager

```bash
oc get pods -n cert-manager
```

Expected: `cert-manager-*`, `cert-manager-cainjector-*`, and `cert-manager-webhook-*` all `Running`.

## About cert-manager

cert-manager automates TLS certificate issuance and renewal. In RHOSO it enables
**TLS Everywhere (TLS-e)** — all OpenStack service endpoints use SSL/TLS certificates
issued and managed by cert-manager, removing the need for manual certificate lifecycle
management.

## About NMState

The NMState operator provides declarative node network configuration via
`NodeNetworkConfigurationPolicy` (NNCP) objects. In RHOSO it configures the OCP
worker nodes with the isolated network interfaces required by OpenStack services
(internalapi, storage, tenant, external).

## About MetalLB (L2 mode)

MetalLB responds to ARP requests for service IP addresses and forwards traffic to
service pods. RHOSO uses L2 mode to expose OpenStack API endpoints on the networks
defined in `NetConfig`.

---

**Back:** [Lab 00 — Setup](00-setup.md) | **Next:** [Lab 02 — RHOSO Operators](02-gitops-operators.md)
