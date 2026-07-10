# Lab 05 — Deploy the RHOSO Control Plane via GitOps

## Objective

Create a kustomize overlay for your specific lab environment, commit it to your
GitHub fork, and deploy it via an ArgoCD Application. The ArgoCD sync will provision
the OpenStack control plane including Keystone, Glance, Cinder, Nova, Neutron, and
the required network configuration policies.

## Prerequisites

- Completed [Lab 04 — Secure Access](04-secure-access.md)
- GitHub deploy key added to your fork (see [Lab 00 — Setup](00-setup.md))
- All secrets exist in the `openstack` namespace

## Run the Automation

```bash
ansible-playbook playbooks/05-control-plane.yml --ask-vault-pass
```

This playbook:

1. Creates `environments/base/kustomization.yaml` referencing the upstream base
2. Creates `environments/demo-env/controlplane/kustomization.yaml` with NNCP and NetConfig patches for your `lab_guid`
3. Creates the ArgoCD `Application` manifest pointing at your fork on branch `lab-<lab_guid>`
4. Commits and pushes both files to your fork on branch `lab-<lab_guid>`
5. Deploys the ArgoCD Application
6. Waits up to 30 minutes for the control plane to reach `Ready=True`

## Understanding the Kustomize Overlay

The overlay patches three types of resources:

### NodeNetworkConfigurationPolicy (NNCP)

One NNCP per OCP worker node. The patches update:
- `/metadata/name` → `control-plane-cluster-<lab_guid>-N`
- `/spec/nodeSelector/kubernetes.io~1hostname` → the worker's actual hostname
- The external network IP for that worker

### NetConfig DNS Domains

The `openstacknetconfig` resource is patched with the correct DNS domain suffix for
your cluster: `<network>.sandbox-<lab_guid>-ocp4-cluster.svc.cluster.local`

## Manual Steps (reference)

Set these shell variables once before running any of the commands below:

```bash
export LAB_GUID=8mdhj            # your lab GUID
export YOUR_GITHUB_ID=pnavarro   # your GitHub username
```

### Create the kustomize base

```bash
cd ~/labrepo/content/files/manifests
mkdir -p environments/base

cat > environments/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

components:
  - https://github.com/openstack-k8s-operators/gitops/components/argocd/annotations?ref=v0.1.1

resources:
  - https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2/content/files/manifests/base/controlplane/?ref=main
EOF

kustomize build environments/base
```

### Create the environment overlay

```bash
mkdir -p environments/demo-env/controlplane/
```

Edit `environments/demo-env/controlplane/kustomization.yaml` — replace `zf6s2` with
your `lab_guid` and the worker IPs with your actual values (check `vars.yml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../base/controlplane

patches:
  - target:
      group: nmstate.io
      version: v1
      kind: NodeNetworkConfigurationPolicy
      name: osp-multi-nic-worker-ocp4-worker1
    patch: |-
      - op: replace
        path: /metadata/name
        value: "control-plane-cluster-<lab_guid>-1"
      - op: replace
        path: /spec/nodeSelector/kubernetes.io~1hostname
        value: "control-plane-cluster-<lab_guid>-1"
      - op: replace
        path: /spec/desiredState/interfaces/3/ipv4/address/0/ip
        value: "<external_ip_worker_1 from the lab portal Details tab>"
  # ... (repeat for worker2 and worker3)
```

Validate:

```bash
kustomize build environments/demo-env/controlplane/
```

### Deploy via ArgoCD

```bash
mkdir -p applications/rhoso

cat > applications/rhoso/application-environment-demo-env-controlplane.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  name: environment-rhoso-demo-env-controlplane
  namespace: openshift-gitops
spec:
  destination:
    server: https://kubernetes.default.svc
  project: default
  source:
    path: content/files/manifests/environments/demo-env/controlplane/
    repoURL: https://github.com/${YOUR_GITHUB_ID}/showroom_osp-on-ocp-day2.git
    targetRevision: lab-${LAB_GUID}
  syncPolicy:
    automated: {}
EOF

git add .
git commit -m "Add control plane overlay for lab-${LAB_GUID}"
git push origin lab-${LAB_GUID}

oc create --save-config -f applications/rhoso/application-environment-demo-env-controlplane.yaml
```

## Verification

### Watch ArgoCD Application status

```bash
oc wait --timeout=600s -n openshift-gitops \
  applications.argoproj.io/environment-rhoso-demo-env-controlplane \
  --for jsonpath='{.status.health.status}'=Healthy
```

### Watch control plane deployment (takes 15-30 minutes)

```bash
oc get openstackcontrolplane -n openstack -w
```

When complete you will see:

```
NAME                      STATUS   MESSAGE
openstack-control-plane   True     Setup complete
```

Press `Ctrl+C` to exit the watch.

### Check ArgoCD Application in detail

```bash
oc get -n openshift-gitops application.argoproj.io \
  environment-rhoso-demo-env-controlplane -o wide
```

---

**Back:** [Lab 04 — Secure Access](04-secure-access.md) | **Next:** [Lab 06 — Networking Patch](07-networking-patch.md)
