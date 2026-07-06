# RHOSO Day 2 Operations — Lab Automation

Ansible automation and lab exercises for the **Red Hat OpenStack Services on OpenShift (RHOSO)** Day 2 Operations workshop.

This repo automates the initial RHOSO deployment so students can focus on day-2 operational exercises without spending the full session on installation.

## Lab Topics

| # | Topic | Playbook | Exercise |
|---|-------|----------|----------|
| 00 | Setup & Prerequisites | `playbooks/00-prerequisites.yml` | [lab-exercises/00-setup.md](lab-exercises/00-setup.md) |
| 01 | Install Operator Prerequisites (GitOps) | `playbooks/01-gitops-operators.yml` | [lab-exercises/01-prerequisites.md](lab-exercises/01-prerequisites.md) |
| 02 | Install RHOSO Operators (GitOps) | `playbooks/02-rhoso-operators.yml` | [lab-exercises/02-gitops-operators.md](lab-exercises/02-gitops-operators.md) |
| 03 | Configure Secure Access | `playbooks/03-secure-access.yml` | [lab-exercises/03-rhoso-operators.md](lab-exercises/03-rhoso-operators.md) |
| 04 | Install NFS Server | `playbooks/04-nfs-server.yml` | [lab-exercises/05-nfs-server.md](lab-exercises/05-nfs-server.md) |
| 05 | Deploy Control Plane (GitOps) | `playbooks/05-control-plane.yml` | [lab-exercises/06-control-plane.md](lab-exercises/06-control-plane.md) |
| 06 | **Networking Patch** _(if required)_ | `playbooks/06-networking-patch.yml` | [lab-exercises/07-networking-patch.md](lab-exercises/07-networking-patch.md) |
| 07 | Deploy Data Plane (GitOps) | `playbooks/07-data-plane.yml` | [lab-exercises/08-data-plane.md](lab-exercises/08-data-plane.md) |
| 08 | Access OpenStack | `playbooks/08-access-openstack.yml` | [lab-exercises/09-access-openstack.md](lab-exercises/09-access-openstack.md) |

## Quick Start

### 1. Fork the Lab Repo

Fork `https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2` into your GitHub account.

### 2. Clone This Repo

```bash
export YOUR_GITHUB_ID=pnavarro   # replace with your GitHub username
git clone https://github.com/${YOUR_GITHUB_ID}/RHOSO-enablement.git
cd RHOSO-enablement
```

### 3. Set Your Lab Variables

Edit `inventory/group_vars/all/vars.yml`:

```yaml
lab_uuid: "YOUR_UUID"       # from your lab welcome email
github_id: "YOUR_GITHUB_ID"
```

### 4. Set Up Your Vault (Secrets)

```bash
bash setup-vault.sh
```

Fill in your bastion password, OCP admin password, and Red Hat pull secret when prompted. The vault is encrypted and excluded from git.

### 5. Run All Phases

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Or run a single phase:

```bash
ansible-playbook playbooks/05-control-plane.yml --ask-vault-pass
```

## Security Notes

- **`inventory/group_vars/all/vault.yml`** is in `.gitignore` — never committed
- `vault_template.yml` shows the required variable names without values — safe to commit
- SSH keys (`*.pem`, `*.key`) are excluded from git
- Use `ansible-vault edit inventory/group_vars/all/vault.yml` to update secrets

## Lab Infrastructure

Each student receives:
- **Lab UUID** — unique identifier for your environment (e.g. `zf6s2`)
- **Bastion host** — `lab-user@ssh.ocpv05.rhdp.net -p <PORT>`
- **OCP 4.16 cluster** — 3-node controller/worker
- **RHEL 9.4 compute** — virtualised data plane host
- **OCP Console** — `https://console-openshift-console.apps.cluster-<UUID>.dyn.redhatworkshops.io`

## Upstream References

- Lab content: https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2

> The content in this repository is not officially supported by Red Hat. It is intended for exploratory and educational purposes.
