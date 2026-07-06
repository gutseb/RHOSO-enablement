# CLAUDE.md — RHOSO Enablement Lab

## Project Purpose

Automation and lab exercise content for the **Red Hat OpenStack Services on OpenShift (RHOSO) Day 2 Operations** workshop. This repo helps students rapidly deploy a functional RHOSO system and then walks them through day-2 operational exercises.

## Target Audience

Red Hat field/partner SEs and customers attending a 1-day RHOSO Day 2 Operations workshop. Students are assumed to have basic OpenShift familiarity but may be new to RHOSO.

## Lab Infrastructure (per student)

- 3-node OCP 4.16 controller/worker cluster (pre-provisioned)
- Bastion host (RHEL): `lab-user@ssh.ocpv05.rhdp.net -p 30883`
- RHEL 9.4 virtualised compute host (data plane)
- Each student has a unique **UUID** (e.g. `zf6s2`) that parameterises all URLs and keys

## Security Practices

- **Never commit** plaintext passwords, SSH keys, or OCP credentials to git
- Student secrets go in `inventory/group_vars/all/vault.yml` (Ansible Vault encrypted)
- A `vault_template.yml` shows the required variables without values — commit this
- `.gitignore` excludes `vault.yml`, `.vault_password`, and any `*.pem` / `*.key` files
- Students run `ansible-vault encrypt inventory/group_vars/all/vault.yml` after filling it out

## Lab Topics (in order)

1. Install the Operators prerequisites using OpenShift gitops
2. Install the Red Hat OpenStack Platform Service Operators using OpenShift gitops
3. Configure Secure Access for OpenStack Services
4. Install NFS server
5. Deploy RHOSO control plane using OpenShift gitops
6. **[PLACEHOLDER]** Networking patch (may be required before data plane deployment)
7. Deploy RHOSO data plane using OpenShift gitops
8. Access OpenStack

## Upstream Fork

- Upstream: https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2
- Each student forks the upstream repo into their own GitHub account

## Repo Structure

```
RHOSO-enablement/
├── CLAUDE.md                    # This file
├── README.md                    # Student-facing setup guide
├── .gitignore                   # Excludes secrets and vault files
├── ansible.cfg
├── inventory/
│   ├── hosts.yml                # Bastion as Ansible target (parameterised by UUID)
│   └── group_vars/
│       └── all/
│           ├── vars.yml         # Non-secret lab variables (committed)
│           └── vault.yml        # Encrypted secrets — DO NOT commit unencrypted
├── vault_template.yml           # Variable names with empty values — safe to commit
├── setup-vault.sh               # Helper: copies template → vault.yml, prompts student
├── playbooks/
│   ├── site.yml                 # Master playbook (runs all phases in order)
│   ├── 00-prerequisites.yml
│   ├── 01-gitops-operators.yml
│   ├── 02-rhoso-operators.yml
│   ├── 03-secure-access.yml
│   ├── 04-nfs-server.yml
│   ├── 05-control-plane.yml
│   ├── 06-networking-patch.yml  # PLACEHOLDER
│   ├── 07-data-plane.yml
│   └── 08-access-openstack.yml
├── roles/
│   ├── prerequisites/
│   ├── gitops-operators/
│   ├── rhoso-operators/
│   ├── secure-access/
│   ├── nfs-server/
│   ├── control-plane/
│   ├── networking-patch/
│   ├── data-plane/
│   └── openstack-access/
└── lab-exercises/
    ├── 00-setup.md
    ├── 01-prerequisites.md
    ├── 02-gitops-operators.md
    ├── 03-rhoso-operators.md
    ├── 04-secure-access.md
    ├── 05-nfs-server.md
    ├── 06-control-plane.md
    ├── 07-networking-patch.md   # PLACEHOLDER
    ├── 08-data-plane.md
    └── 09-access-openstack.md
```

## Development Notes

- The `archive/` directory holds prior planning documents — do not include in student deliverables
- Each playbook should be runnable standalone (idempotent) as well as via `site.yml`
- Playbooks target the `bastion` host group and use `become: true` where needed
- The upstream repo (`rh-osp-demo/showroom_osp-on-ocp-day2`) is the reference for gitops manifests; students fork it into their own accounts

## Key Variables (see vars.yml and vault_template.yml)

| Variable | Source | Description |
|---|---|---|
| `lab_guid` | vars.yml | Student's unique lab GUID (e.g. zf6s2) |
| `bastion_hostname` | vars.yml | Bastion SSH hostname |
| `bastion_port` | vars.yml | Bastion SSH port (30883) |
| `github_id` | vars.yml | Student's GitHub username |
| `ocp_console_url` | vars.yml | Derived from lab_guid |
| `vault_bastion_password` | vault.yml | Bastion SSH password |
| `vault_ocp_password` | vault.yml | OCP admin password |
| `vault_registry_username` | vault.yml | RH registry service account |
| `vault_registry_password` | vault.yml | RH registry token |
| `vault_rhc_username` | vault.yml | RH Customer Portal username |
| `vault_rhc_password` | vault.yml | RH Customer Portal password |

## Reference Clone (local, not committed)

The upstream repo is cloned into `reference/` for local reading during development:
- `reference/upstream/` — https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2

The `reference/` directory is in `.gitignore`. Clone fresh with:
```bash
git clone --depth=1 https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2.git reference/upstream
```
