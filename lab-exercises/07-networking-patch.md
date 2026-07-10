# Lab 07 — Networking Patch (RHOCP Network Isolation)

## Objective

Prepare OpenShift networking for the RHOSO data plane: apply the worker
NodeNetworkConfigurationPolicies (NNCPs) with the external IPs from your lab
portal, create the NetworkAttachmentDefinitions and MetalLB address pools for
the isolated networks, and enable global IP forwarding.

## Prerequisites

- Completed [Lab 06 — Control Plane](06-control-plane.md)
- Lab portal **Details tab** values filled in `inventory/group_vars/all/vars.yml`
  (`external_ip_worker_1/2/3`, `external_ip_bastion`, `public_net_start/end`,
  `conversion_host_ip`)

## Run the Automation

```bash
ansible-playbook playbooks/06-networking-patch.yml --ask-vault-pass
```

This playbook:

1. Asserts the portal `external_ip_worker_*` values are set
2. Renders one NNCP manifest per OCP worker from a template — audit them in
   `artifacts/06-networking-patch/osp-ng-nncp-w{1,2,3}.yaml` in the repo
3. Applies the NNCPs and waits until all three reach `SuccessfullyConfigured`
4. Applies `osp-ng-netattach.yaml`, `osp-ng-metal-lb-ip-address-pools.yaml`,
   and `osp-ng-metal-lb-l2-advertisements.yaml` from the labrepo
5. Patches the cluster network operator with `ipForwarding: Global`
   (skipped if already set)

## Manual Steps (reference)

```bash
cd ~/labrepo/content/files
find . -type f -exec sed -i 's/UUID/<your_guid>/g' {} +
sed -i 's/EXTERNAL_IP_WORKER_1/<portal value>/' osp-ng-nncp-w1.yaml
sed -i 's/EXTERNAL_IP_WORKER_2/<portal value>/' osp-ng-nncp-w2.yaml
sed -i 's/EXTERNAL_IP_WORKER_3/<portal value>/' osp-ng-nncp-w3.yaml
oc apply -f osp-ng-nncp-w1.yaml
oc apply -f osp-ng-nncp-w2.yaml
oc apply -f osp-ng-nncp-w3.yaml
oc get nncp -w    # wait for SuccessfullyConfigured, then Ctrl+C
oc apply -f osp-ng-netattach.yaml
oc apply -f osp-ng-metal-lb-ip-address-pools.yaml
oc apply -f osp-ng-metal-lb-l2-advertisements.yaml
oc patch network.operator cluster -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"ipForwarding": "Global"}}}}}' --type=merge
```

> The automation renders the NNCPs to `artifacts/06-networking-patch/`
> instead of editing the labrepo files in place, so your fork stays clean of
> environment-specific values.

## Verification

```bash
oc get nncp
# all policies: Available / SuccessfullyConfigured

oc get network-attachment-definitions -n openstack
# ctlplane, internalapi, storage, tenant

oc get ipaddresspools -n metallb-system
oc get l2advertisements -n metallb-system

oc get network.operator cluster -o jsonpath='{.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding}'
# Global
```

---

**Back:** [Lab 06 — Control Plane](06-control-plane.md) | **Next:** [Lab 08 — Data Plane](08-data-plane.md)
