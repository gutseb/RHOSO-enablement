# Lab 02 — Install RHOSO Service Operators

## Objective

Install the Red Hat OpenStack Platform (RHOSO) service operators into the OpenShift
cluster using OLM (Operator Lifecycle Manager). After this lab the `openstack-operators`
namespace will contain a running OpenStack Operator pod and the
`openstackcontrolplanes.core.openstack.org` CRD will be available.

## Prerequisites

- Completed [Lab 01 — Prerequisites](01-prerequisites.md)
- NMState and MetalLB operators confirmed Running
- Logged in to OCP cluster (`oc whoami` returns `admin`)

## Run the Automation

```bash
ansible-playbook playbooks/02-rhoso-operators.yml --ask-vault-pass
```

This playbook:

1. Creates the `openstack-operators` and `openstack` namespaces
2. Applies the `OperatorGroup` for the OpenStack operator
3. Creates the `Subscription` in `stable-v1.0` channel with Manual approval
4. Waits for the `InstallPlan` to appear, then approves it
5. Waits up to 15 minutes for the CSV to reach `Succeeded`
6. Verifies the `openstackcontrolplanes.core.openstack.org` CRD is registered
7. Creates the `OpenStack` initialiser object
8. Confirms the controller-manager pod is Running

## Manual Steps (reference)

### Create namespaces

```bash
oc create namespace openstack-operators
oc create namespace openstack
```

### Apply the OperatorGroup and Subscription

```bash
cd ~/labrepo/content/files
oc apply -f osp-ng-openstack-operator.yaml
```

### Approve the InstallPlan

The subscription is set to `installPlanApproval: Manual`. You must approve the
generated plan before installation proceeds:

```bash
# Get the InstallPlan name
PLAN=$(oc get installplan -n openstack-operators -o jsonpath='{.items[0].metadata.name}')
echo "Approving: $PLAN"

# Approve it
oc patch installplan "$PLAN" -n openstack-operators \
  --type merge -p '{"spec":{"approved":true}}'
```

### Watch the CSV install

```bash
oc get csv -n openstack-operators -w
```

Wait until the phase column shows `Succeeded`. This can take 5–10 minutes.

### Initialise the operator

```bash
oc apply -f osp-ng-openstack-operator-init.yaml
```

## Verification

```bash
# CSV should show Succeeded
oc get csv -n openstack-operators

# CRD must be registered
oc get crd openstackcontrolplanes.core.openstack.org

# Controller-manager pod should be Running
oc get pods -n openstack-operators -l control-plane=controller-manager
```

Expected output includes one or more pods in `Running` state and the CSV phase
`Succeeded`.

---

**Back:** [Lab 01 — Prerequisites](01-prerequisites.md) | **Next:** [Lab 03 — NFS Server](05-nfs-server.md)
