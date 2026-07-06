# Lab 03 — Install and Configure the NFS Server

## Objective

Configure the lab NFS server with export directories for Cinder, Glance, and AAP.
Add a static IP on the storage network (172.18.0.13/24) so OpenStack services can
reach the NFS server on the correct network segment.

## Prerequisites

- Completed [Lab 02 — RHOSO Operators](02-gitops-operators.md)
- SSH key `~/labrepo/.ssh/{{ lab_guid }}key.pem` is accessible from the bastion

## Run the Automation

```bash
ansible-playbook playbooks/04-nfs-server.yml --ask-vault-pass
```

This connects from the bastion to `nfsserver` (via the lab SSH key) and:

1. Creates `/nfs/cinder`, `/nfs/glance`, `/nfs/aap` with mode `0777`
2. Writes `/etc/exports`
3. Removes the default DHCP connection and adds a static `172.18.0.13/24` on `eth1`
4. Starts and enables `nfs-server.service`
5. Runs `exportfs -ra`

## Manual Steps (reference)

SSH to the NFS server from your bastion:

```bash
ssh -i ~/.ssh/{{ lab_guid }}key.pem cloud-user@nfsserver
sudo -i
```

Create the directories and set permissions:

```bash
mkdir -p /nfs/cinder /nfs/glance /nfs/aap
chmod 777 /nfs/cinder /nfs/glance /nfs/aap
```

Create the exports file:

```bash
cat << 'EOF' > /etc/exports
/nfs/cinder *(rw,sync,no_root_squash)
/nfs/glance *(rw,sync,no_root_squash)
/nfs/aap *(rw,sync,no_root_squash)
EOF
```

Configure the storage network interface:

```bash
nmcli con delete 'Wired connection 1'
nmcli con add con-name "static-eth1" ifname eth1 type ethernet ip4 172.18.0.13/24
nmcli con up "static-eth1"
```

Start NFS:

```bash
systemctl start nfs-server
systemctl enable nfs-server
exportfs -ra
```

Verify:

```bash
exportfs -v
```

Exit back to bastion:

```bash
exit
logout
```

## Verification

From the bastion, check the exports are visible:

```bash
showmount -e 172.18.0.13
```

Expected output:

```
Export list for 172.18.0.13:
/nfs/aap    *
/nfs/glance *
/nfs/cinder *
```

---

**Back:** [Lab 02 — RHOSO Operators](02-gitops-operators.md) | **Next:** [Lab 04 — Secure Access](04-secure-access.md)
