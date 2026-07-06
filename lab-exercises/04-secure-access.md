# Lab 04 — Configure Secure Access for OpenStack Services

## Objective

Create the Kubernetes Secrets required by the RHOSO control and data planes:
service passwords, libvirt credentials, Cinder NFS config, Red Hat subscription
credentials, Red Hat registry pull credentials, and the SSH keys used by the
Ansible dataplane operator.

## Prerequisites

- Completed [Lab 03 — NFS Server](05-nfs-server.md)
- Vault file encrypted with your Red Hat credentials
- `~/labrepo` cloned with the pre-configured secret YAML files

## Run the Automation

```bash
ansible-playbook playbooks/03-secure-access.yml --ask-vault-pass
```

This creates the following secrets in the `openstack` namespace:

| Secret | Purpose |
|---|---|
| `osp-secret` | OpenStack service passwords (base64-encoded) |
| `libvirt-secret` | Libvirt TLS credentials |
| `cinder-nfs-config` | NFS backend config for Cinder |
| `subscription-manager` | Red Hat Customer Portal login for EDPM nodes |
| `redhat-registry` | Registry pull credentials for `registry.redhat.io` |
| `dataplane-ansible-ssh-private-key-secret` | SSH key for Ansible → compute nodes |
| `nova-migration-ssh-key` | ECDSA key pair for Nova live migration |

## Manual Steps (reference)

### Switch to openstack namespace

```bash
oc project openstack
```

### Create OpenStack service password secrets

```bash
cd ~/labrepo/content/files
oc create -f osp-ng-ctlplane-secret.yaml
oc create -f osp-ng-libvirt-secret.yaml
```

### Create Cinder NFS secret

```bash
oc create secret generic cinder-nfs-config --from-file=nfs-cinder-conf
```

### Create Red Hat subscription-manager secret

```bash
oc create secret generic subscription-manager \
  --from-literal rhc_auth='{"login": {"username": "YOUR_RH_USERNAME", "password": "YOUR_RH_PASSWORD"}}'
```

### Create Red Hat registry secret

```bash
oc create secret generic redhat-registry \
  --from-literal edpm_container_registry_logins='{"registry.redhat.io": {"USERNAME": "PASSWORD"}}' \
  -n openstack
```

### Create dataplane Ansible SSH key secret

```bash
oc create secret generic dataplane-ansible-ssh-private-key-secret \
  --save-config --dry-run=client \
  --from-file=authorized_keys=~/.ssh/{{ lab_guid }}key.pub \
  --from-file=ssh-privatekey=~/.ssh/{{ lab_guid }}key.pem \
  --from-file=ssh-publickey=~/.ssh/{{ lab_guid }}key.pub \
  -n openstack -o yaml | oc apply -f-
```

### Generate Nova migration key pair

```bash
ssh-keygen -f ./id -t ecdsa-sha2-nistp521 -N ''
oc create secret generic nova-migration-ssh-key \
  --from-file=ssh-privatekey=id \
  --from-file=ssh-publickey=id.pub \
  -n openstack -o yaml | oc apply -f-
```

## Verification

```bash
# List all secrets in the openstack namespace
oc get secrets -n openstack

# Confirm specific secrets exist
oc get secret osp-secret nova-migration-ssh-key \
  dataplane-ansible-ssh-private-key-secret -n openstack
```

---

**Back:** [Lab 03 — NFS Server](05-nfs-server.md) | **Next:** [Lab 05 — Control Plane](06-control-plane.md)
