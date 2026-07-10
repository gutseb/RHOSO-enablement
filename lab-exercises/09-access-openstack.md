# Lab 09 — Access OpenStack

## Objective

Verify the deployed RHOSO cloud end to end: check compute services and network
agents, then create a public/private network topology, a test flavor, image,
keypair, security group, router, and a cirros VM with a floating IP you can
ping and SSH to. Finally, get the Horizon dashboard URL.

## Prerequisites

- Completed [Lab 08 — Data Plane](08-data-plane.md)
- Lab portal **Details tab** values filled in `inventory/group_vars/all/vars.yml`
  (`external_ip_bastion`, `public_net_start/end`, `conversion_host_ip`)

## Run the Automation

```bash
ansible-playbook playbooks/08-access-openstack.yml --ask-vault-pass
```

This playbook is fully re-runnable — every OpenStack resource is pre-checked
and reported as **"already configured"** if it exists. It:

1. Lists compute services and network agents (read-only verification)
2. Runs `nova-manage cell_v2 discover_hosts` (safe to repeat)
3. Adds the bastion `static-eth1` connection on the external network
4. Creates (or skips): flavor `tiny`, image `cirros`, keypair `default`,
   security group `basic` + SSH/ICMP/DNS rules, networks `public`/`private`,
   subnets `public-net`/`private-net`, router `vrouter`
5. Boots `test-server` and attaches the `conversion_host_ip` floating IP
6. Waits for the VM to reach `ACTIVE` and answer ping on the floating IP
7. Prints a per-resource summary and the Horizon URL (login `admin` / `openstack`)

> If the floating IP is reported in use, set `conversion_host_ip` in vars.yml
> to the next free address and re-run — existing resources are skipped.

## Manual Steps (reference)

See the showroom page (gitops/access-gitops.html) — the automation follows it
verbatim, running the `openstack` commands inside the `openstackclient` pod
via `oc rsh`.

## Verification

```bash
oc rsh -n openstack openstackclient openstack server list
# test-server ACTIVE, private + floating IP

ping -c 3 <conversion_host_ip>
ssh cirros@<conversion_host_ip>   # key: ~/.ssh/id_rsa_pem inside openstackclient pod

oc get routes horizon -n openstack
```

---

**Back:** [Lab 08 — Data Plane](08-data-plane.md)
