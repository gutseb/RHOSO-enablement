# Lab 08 — Deploy the RHOSO Data Plane via GitOps

## Objective

Configure the preprovisioned compute node's hostname and networking, create the
dataplane kustomize overlay in your GitHub fork (with the patches as separate,
auditable files), and deploy it via an ArgoCD Application.

## Prerequisites

- Completed [Lab 07 — Networking Patch](07-networking-patch.md)
- All secrets exist in the `openstack` namespace (Lab 04), including
  `dataplane-ansible-ssh-private-key-secret` and `nova-migration-ssh-key`
- Control plane is `Ready` (Lab 06)

## Run the Automation

```bash
ansible-playbook playbooks/07-data-plane.yml --ask-vault-pass
```

This playbook:

1. Sets the compute node hostname to `edpm-compute-1.sandbox-<lab_guid>-ocp4-cluster.svc.cluster.local`
   and configures its `static-eth1` (ctlplane) and `eth0-dhcp` connections
2. Renders the dataplane overlay from templates into your labrepo fork:
   `content/files/manifests/environments/demo-env/dataplane/`
   - `kustomization.yaml` — references `../../../base/dataplane` plus three patch files
   - `patch-nodeset-nodes.yaml` — adds each node from `compute_nodes` in vars.yml
   - `patch-nodeset-ansible.yaml` — sets `dns_search_domains` for your GUID
   - `patch-pvc-storageclass.yaml` — sets the ansible-logs PVC StorageClass
3. Validates the overlay with `kustomize build`
4. Commits and pushes the overlay to your fork on branch `lab-<lab_guid>`
5. Creates the ArgoCD Application `environment-rhoso-demo-env-dataplane`
6. Waits for the Application to become `Healthy`, then waits (up to 60 min)
   for the `OpenStackDataPlaneDeployment` to reach `Ready=True`

Audit the rendered files in your fork before/after the push — they are plain
YAML committed to your branch.

## Manual Steps (reference)

```bash
# Compute node networking (from the bastion)
ssh -i ~/.ssh/<guid>key.pem cloud-user@compute01
sudo hostnamectl set-hostname edpm-compute-1.sandbox-<guid>-ocp4-cluster.svc.cluster.local
sudo nmcli con add con-name "static-eth1" ifname eth1 type ethernet ip4 172.22.0.100/24 ipv4.dns "172.22.0.89"
sudo nmcli con up "static-eth1"
sudo nmcli con add type ethernet ifname eth0 con-name eth0-dhcp ipv4.method auto ipv6.method ignore
sudo nmcli con up eth0-dhcp
sudo nmcli con mod eth0-dhcp connection.stable-id "user-set"
logout

# Overlay (on the bastion)
cd /home/lab-user/labrepo/content/files/manifests
mkdir -p environments/demo-env/dataplane/
# create kustomization.yaml + the three patch files (see the lab page)
kustomize build environments/demo-env/dataplane/
git add . && git commit -m "Base and demo-env environment dataplane" && git push origin

# ArgoCD Application
oc create --save-config -f applications/rhoso/application-environment-demo-env-dataplane.yaml
oc wait --timeout=600s -n openshift-gitops applications.argoproj.io/environment-rhoso-demo-env-dataplane --for jsonpath='{.status.health.status}'=Healthy
```

## Verification

```bash
oc get application.argoproj.io -n openshift-gitops environment-rhoso-demo-env-dataplane
# Healthy / Synced

oc get openstackdataplanenodeset -n openstack
# preprovisioned-nodeset ... SetupReady

oc get openstackdataplanedeployment -n openstack
# data-plane-deploy ... Setup complete

oc get pods -n openstack | grep dataplane
# ansible-runner pods Completed
```

---

**Back:** [Lab 07 — Networking Patch](07-networking-patch.md) | **Next:** [Lab 09 — Access OpenStack](09-access-openstack.md)
