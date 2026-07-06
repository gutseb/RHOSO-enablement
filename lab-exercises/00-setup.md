# Lab Setup — Prerequisites

## Overview

Before starting the lab exercises, complete this one-time setup on your **local
machine** (the machine where you run Ansible). These steps configure SSH access,
your GitHub fork, and the Ansible vault for secrets.

---

## Step 1 — Fork the Lab Repository

Fork the lab repository into your personal GitHub space:

```
https://github.com/rh-osp-demo/showroom_osp-on-ocp-day2
```

> Click **Fork** in the top-right corner and select your personal account.

---

## Step 2 — Get Your Lab Credentials

Your lab portal **Overview** tab provides everything you need:

| Item | Where to find it | Example |
|---|---|---|
| Lab GUID | Overview tab — appears in all URLs | `8mdhj` |
| Bastion hostname | Overview tab — SSH command | `ssh.ocpv10.rhdp.net` |
| Bastion port | Overview tab — SSH command `-p` flag | `30578` |
| Bastion SSH password | Overview tab — credentials section | `<provided>` |
| OCP admin password | Overview tab — credentials section | `<provided>` |

The SSH command shown in the portal will look like:
```
ssh lab-user@<BASTION_HOSTNAME> -p <BASTION_PORT>
```

---

## Step 3 — Configure Your Local SSH Client

Some lab bastions reject connections when your SSH agent presents multiple keys.
Add an `IdentitiesOnly yes` entry so SSH uses only the password (or explicit key)
rather than every loaded identity.

**Option A — Automatic (done by the playbook)**

The `playbooks/00-prerequisites.yml` playbook writes this entry for you. If you
run it first, skip the manual step below.

**Option B — Manual**

Add the following block to `~/.ssh/config` (create the file if it doesn't exist),
replacing `<BASTION_HOSTNAME>` with your bastion hostname from Step 2:

```
Host <BASTION_HOSTNAME>
  IdentitiesOnly yes
  PasswordAuthentication yes
```

```bash
# Quick one-liner — replace ssh.ocpv10.rhdp.net with your bastion hostname
BASTION_HOST=ssh.ocpv10.rhdp.net
cat >> ~/.ssh/config <<EOF

# RHOSO lab bastion
Host ${BASTION_HOST}
  IdentitiesOnly yes
  PasswordAuthentication yes
EOF
chmod 600 ~/.ssh/config
```

---

## Step 4 — Test Bastion Connectivity

Use the SSH command from your lab portal Overview tab:

```bash
ssh lab-user@<BASTION_HOSTNAME> -p <BASTION_PORT>
# Example: ssh lab-user@ssh.ocpv10.rhdp.net -p 30578
```

Enter your bastion password when prompted. Once logged in, verify the lab SSH key
exists:

```bash
ls ~/.ssh/
# You should see <GUID>key.pem and <GUID>key.pub
```

Type `exit` to return to your local machine.

---

## Step 5 — Add the Bastion SSH Key to GitHub

The bastion pushes kustomize overlays to your fork via SSH. You need to authorise
its key as a deploy key.

From the bastion, copy the public key:

```bash
cat ~/.ssh/<GUID>key.pub
```

In your GitHub fork:
1. Go to **Settings → Deploy keys → Add deploy key**
2. Title: `bastion RHOSO gitops key`
3. Paste the public key
4. Check **Allow write access**
5. Click **Save**

---

## Step 6 — Clone This Automation Repository Locally

Set your GitHub username as a shell variable, then clone:

```bash
export YOUR_GITHUB_ID=pnavarro   # replace with your GitHub username
git clone https://github.com/${YOUR_GITHUB_ID}/RHOSO-enablement.git
cd RHOSO-enablement
```

---

## Step 7 — Set Lab Variables

Edit `inventory/group_vars/all/vars.yml` and replace all `REPLACE_WITH_*` placeholders:

```yaml
lab_guid: "8mdhj"                        # your lab GUID (from portal Overview tab)
github_id: "pnavarro"                    # your GitHub username
bastion_hostname: "ssh.ocpv10.rhdp.net"  # from portal Overview tab SSH command
bastion_port: "30578"                    # from portal Overview tab SSH command
```

---

## Step 8 — Set Up Your Vault (Secrets)

Run the vault setup helper:

```bash
bash setup-vault.sh
```

This will:
1. Copy `vault_template.yml` → `inventory/group_vars/all/vault.yml`
2. Open the file in your editor — fill in all values:

```yaml
vault_bastion_password: ""       # your bastion SSH password
vault_ocp_password: ""           # OCP admin password from welcome email
vault_registry_username: ""      # Red Hat registry service account
vault_registry_password: ""      # Red Hat registry service account token
vault_rhc_username: ""           # Red Hat Customer Portal username
vault_rhc_password: ""           # Red Hat Customer Portal password
```

3. Encrypt the file with `ansible-vault`

> `vault.yml` is in `.gitignore` — it will never be committed.

---

## Step 8b — Supply Lab Portal Details Variables

Your lab portal's **Details** tab provides a set of environment-specific IP addresses
used in later OpenStack operator phases (floating IPs, public network range, migration
host). These are separate from the network variables used in the NNCP kustomize patches.

**From the Details tab, copy the export block** — it looks like this:

```
export EXTERNAL_IP_WORKER_1=192.168.10.80
export EXTERNAL_IP_WORKER_2=192.168.10.81
export EXTERNAL_IP_WORKER_3=192.168.10.82
export EXTERNAL_IP_BASTION=192.168.10.83
export PUBLIC_NET_START=192.168.10.84
export PUBLIC_NET_END=192.168.10.95
export CONVERSION_HOST_IP=192.168.10.90
```

**Option A — Helper script (recommended)**

```bash
bash setup-lab-vars.sh
# Paste the export block, then press Ctrl+D
```

The script updates the matching variables in `inventory/group_vars/all/vars.yml`.

**Option B — Manual edit**

Edit the `Lab Portal Variables` section in `inventory/group_vars/all/vars.yml`
and replace the `REPLACE_WITH_PORTAL_VALUE` placeholders with your values:

```yaml
# ── Lab Portal Variables (from the Details tab) ──────────────────────────────
external_ip_worker_1: "192.168.10.80"
external_ip_worker_2: "192.168.10.81"
external_ip_worker_3: "192.168.10.82"
external_ip_bastion:  "192.168.10.83"
public_net_start:     "192.168.10.84"
public_net_end:       "192.168.10.95"
conversion_host_ip:   "192.168.10.90"
```

> These variables are not required until later phases of the lab. You can
> supply them now or return to this step when prompted.

---

## Step 9 — Verify Setup

Run the prerequisites playbook. This also writes the SSH config entry automatically:

```bash
ansible-playbook playbooks/00-prerequisites.yml --ask-vault-pass
```

All tasks should pass, including the bastion ping and OCP login.

---

**Next:** [Lab 01 — Install Operator Prerequisites](01-prerequisites.md)
