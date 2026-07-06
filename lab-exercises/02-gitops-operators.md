# Lab 02 — Install RHOSO Operators via GitOps

## Objective

Install the Red Hat OpenStack Platform Service Operators into the OpenShift cluster
using OpenShift GitOps. After this lab the `openstack-operators` namespace will have
a running OpenStack Operator CSV ready to accept control plane configuration.

## Prerequisites

- Completed [Lab 01 — Prerequisites](01-prerequisites.md)
- NMState and MetalLB operators confirmed running

## Run the Automation

```bash
ansible-playbook playbooks/02-rhoso-operators.yml --ask-vault-pass
```

## What Happens

1. Creates the `openstack-operators` and `openstack` namespaces
2. Applies the OpenStack OperatorGroup and Subscription
3. Approves the InstallPlan
4. Waits for the OpenStack Operator CSV to reach `Succeeded`
5. Initialises the operator

## Manual Steps (reference)

The automation above runs the following on the bastion:

```bash
# Create namespaces
oc apply -f ~/labrepo/content/files/osp-ng-openstack-operator.yaml

# Watch operator installation
oc get clusterserviceversion -n openstack-operators -w

# Verify CRD is available
oc get crd openstackcontrolplanes.core.openstack.org
```

## Verification

```bash
# All pods in openstack-operators namespace should be Running
oc get pods -n openstack-operators

# CSV should show Succeeded
oc get csv -n openstack-operators
```

Expected output includes an OpenStack operator pod with status `Running` and a CSV
with phase `Succeeded`.

---

**Back:** [Lab 01 — Prerequisites](01-prerequisites.md) | **Next:** [Lab 03 — Secure Access](03-rhoso-operators.md)
