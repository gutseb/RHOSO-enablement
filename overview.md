**RHOSO**
Red Hat OpenStack Services on OpenShift

**Day 2 Operations Training**

Operator Lifecycle Management  |  Cluster Operations  |  Troubleshooting

Audience: OpenShift / OpenShift Virtualization & RHOSO Architects and Operators

Scope: Post-deployment (Day 2) administration of an existing RHOSO control plane and EDPM data plane

June 2026 — revised for accuracy against RHOSO 18.0 documentation

# **Table of Contents**

1. Architecture Recap: What You're Operating
2. Managing Operators
3. Operating the Cluster (Day 2)
4. Troubleshooting
5. Putting It Together

# **1. Architecture Recap: What You're Operating**

RHOSO separates the OpenStack control plane from the data plane. The control plane runs as ordinary OpenShift workloads, reconciled by a set of service operators that are themselves deployed and managed by the OpenStack Operator (`openstack-operator`). The data plane (Compute, networking agents, storage agents) runs on external RHEL nodes — bare metal or VMs — managed through EDPM (External Data Plane Management) and driven by ansible-runner execution environment pods launched as Kubernetes Jobs.

## **1.1 Control Plane**

* Runs in the `openstack` namespace as Deployments/StatefulSets, one (or more) per OpenStack service.

* A single top-level custom resource, `OpenStackControlPlane`, is the source of truth; service operators reconcile their portion of it.

* Backing infrastructure is reconciled by dedicated operators: `mariadb-operator` (Galera), `rabbitmq-cluster-operator` (RabbitMQ), `infra-operator` (Memcached, Redis, NetConfig/IPAM, DNS), and `ovn-operator` (OVN NB/SB databases and northd).

* TLS-e (TLS everywhere) is enabled by default and handled through cert-manager Issuers; public routes and internal/pod-level endpoints are certificate-backed. Public endpoint TLS cannot be disabled; internal pod-level TLS is configurable (`spec.tls.podLevel.enabled: false` in `OpenStackControlPlane`) but enabled by default.

## **1.2 Data Plane (EDPM)**

* Compute and compute/gateway networking agents live outside OpenShift, on RHEL 9 nodes you already manage day-to-day.

* `OpenStackDataPlaneNodeSet` defines a group of nodes and the Ansible variables/services applied to them.

* `OpenStackDataPlaneDeployment` triggers an actual Ansible run against one or more NodeSets (deploy, update, or scale). Deployments are one-shot: to re-run Ansible you create a **new** `OpenStackDataPlaneDeployment` CR (or delete and recreate one), you do not edit a completed one.

* Each deployment run executes as ansible-runner **Job pods inside OpenShift** (labeled `app=openstackansibleee`), even though the targets are external nodes.

## **1.3 Where State Lives**

| Custom Resource | Purpose |
| :---- | :---- |
| OpenStack (`operator.openstack.org`, in `openstack-operators`) | Operator initialization resource; deploys and manages all service operator controller-managers |
| OpenStackControlPlane | Top-level control-plane spec/status; aggregates per-service readiness |
| OpenStackVersion | Pins the container image set / target release for the deployment (`targetVersion`, `availableVersion`, `deployedVersion`) |
| OpenStackDataPlaneNodeSet | Inventory + Ansible vars for a group of EDPM nodes |
| OpenStackDataPlaneDeployment | Triggers a deploy/update run against one or more NodeSets |
| OpenStackDataPlaneService | Defines a composable data-plane service (playbook, data sources, TLS certs) |
| \<service\>API / per-service CRs (e.g. KeystoneAPI, GlanceAPI, Galera) | Per-service operator CR managing that service's Deployment/StatefulSet and config |

> **Note:** The Ansible execution itself surfaces as Kubernetes `Job`s and pods labeled `app=openstackansibleee`. Track those with `oc get pod -l app=openstackansibleee` and `oc logs job/<service>-<deployment>-<nodeset>` — there is no `oc get openstackansibleee` workflow in RHOSO 18.

**Why this matters for Day 2:** Almost every operational task you'll do — upgrading, scaling, troubleshooting — means editing one of these CRs and watching the relevant operator reconcile it, rather than editing a Deployment or config file directly.

# **2. Managing Operators**

## **2.1 Operator Landscape**

RHOSO 18 installs **one** operator through OLM: `openstack-operator`, subscribed in the `openstack-operators` namespace (channel `stable-v1.0`, one Subscription, one CSV). After OLM installs it, a single **OpenStack initialization CR** (`kind: OpenStack`, apiVersion `operator.openstack.org/v1beta1`, created in `openstack-operators`) starts the OpenStack Operator, which then deploys and manages the individual service operator controller-managers as Deployments in the same namespace.

The service operators are therefore **not** separate OLM operators — you will not see per-service CSVs or Subscriptions. They appear as `*-operator-controller-manager` deployments:

| Controller | Responsibility |
| :---- | :---- |
| openstack-operator | Meta-operator; owns OpenStackControlPlane, OpenStackVersion, and the EDPM data-plane CRDs (the former standalone dataplane-operator was merged into openstack-operator before GA) |
| mariadb-operator | MariaDB/Galera |
| rabbitmq-cluster-operator | RabbitMQ |
| infra-operator | Memcached, Redis, NetConfig/IPAM, DNSMasq |
| keystone-operator | Identity service |
| glance-operator | Image service |
| cinder-operator | Block storage |
| nova-operator | Compute API/conductor/scheduler/cells |
| neutron-operator | Networking API |
| ovn-operator | OVN NB/SB databases and northd |
| placement-operator | Placement service |
| barbican-operator | Key manager |
| octavia-operator | Load balancing |
| telemetry-operator | Ceilometer/Aodh/Prometheus/autoscaling |
| swift / manila / designate / heat / horizon operators | Object storage, shared file systems, DNS, orchestration, dashboard |

## **2.2 Checking Operator Health**

Day 2 health checking starts above the pod layer, at the OLM and CR layers, then drops down only if something looks wrong.

```
# OLM-level: is the single openstack-operator CSV Succeeded?
oc get csv -n openstack-operators

# Subscription channel / install plan approval
oc get subscription -n openstack-operators -o wide

# Pending install plans waiting on manual approval
oc get installplan -n openstack-operators

# Operator initialization resource — deploys the service operators
oc get openstack -n openstack-operators

# Service operator controller-manager deployments and pods
oc get deployment -n openstack-operators
oc get pods -n openstack-operators

# Top-level control plane readiness
oc get openstackcontrolplane -n openstack
oc get openstackcontrolplane -n openstack -o jsonpath='{range .items[0].status.conditions[*]}{.type}{"="}{.status}{" "}{.message}{"\n"}{end}'

# Version state: target vs available vs deployed
oc get openstackversion -n openstack
```

**Read conditions, not just Ready:** OpenStackControlPlane aggregates a Condition per service. A cluster-wide `Ready=False` with everything else green almost always points at one lagging service — read the per-service condition message before chasing pods.

## **2.3 Operator Update Procedure (Minor Updates)**

Minor updates are two-phase: **(1)** update the operators through OLM, **(2)** bump `OpenStackVersion` to roll the service container images. If the Subscription uses `installPlanApproval: Manual` (recommended for production), a new operator version produces an InstallPlan that sits pending until approved.

1. Read the release notes for the target RHOSO minor version and confirm RHOCP version compatibility. Note: RHOSO 18.0.6 and later require RHOCP 4.18 (earlier versions ran on 4.16); crossing that boundary requires the dedicated update procedure in the Red Hat Knowledgebase.

2. Take a config backup (Section 3.5) before touching anything, and confirm your platform backups (etcd, PVs) are current.

3. List pending install plans: `oc get installplan -n openstack-operators`.

4. Approve: `oc patch installplan <name> -n openstack-operators --type merge -p '{"spec":{"approved":true}}'`.

5. Watch the CSV phase move to Succeeded: `oc get csv -n openstack-operators -w`. (If you are updating across the 18.0.6 boundary from an older release, you must also create the `OpenStack` initialization CR after the operator update — see the update guide.)

6. Check the new available version, then patch `OpenStackVersion` to set `spec.targetVersion` to the reported `availableVersion`:

```
oc get openstackversion -n openstack
# NAME                      TARGET VERSION      AVAILABLE VERSION   DEPLOYED VERSION
# openstack-control-plane   18.0.9-20250602.2   18.0.10-20250701.2  18.0.9-20250602.2

oc patch openstackversion openstack-control-plane -n openstack --type merge \
  -p '{"spec":{"targetVersion":"<available_version>"}}'
```

7. Follow the documented sequencing: the OVN services on the control plane update first, then you create an `OpenStackDataPlaneDeployment` with `servicesOverride: [ovn]` to update ovn-controller on the EDPM nodes, then the rest of the control plane rolls, and finally you create a full data-plane update deployment. Watch `oc get openstackcontrolplane -w` and `oc get openstackdataplanedeployment` between phases.

8. Verify `DEPLOYED VERSION` matches the target and run smoke tests before declaring done.

**No native rollback:** There is no supported one-command rollback for an operator update. Treat the pre-update backup as your rollback path, and stage the update in a non-production environment with the same RHOCP version first.

## **2.4 Editing the Control Plane Safely**

Most Day 2 tuning (replica counts, resource requests/limits, `customServiceConfig` overrides) is done by editing `OpenStackControlPlane` or the relevant service CR, not the underlying Deployment — the operator will revert direct Deployment edits on its next reconcile.

```
oc edit openstackcontrolplane -n openstack

# Example: bump Neutron API replicas
oc patch openstackcontrolplane openstack-control-plane -n openstack --type merge -p \
  '{"spec":{"neutron":{"template":{"replicas":3}}}}'
```

* Replica counts, `customServiceConfig`, and resource settings live under `spec.<service>.template`. The `apiOverride` field is for overriding the public route/TLS settings of a service endpoint — it does not carry replicas.

* Webhook validation rejects structurally invalid patches immediately — read the error, it usually names the exact field.

* Changes typically roll pods one at a time; watch `oc get pods -n openstack -w` during the change window.

* For EDPM-side service tuning (e.g. `nova.conf` overrides on compute nodes), edit the relevant `OpenStackDataPlaneNodeSet` (`ansibleVars` or a `ConfigMap`/`Secret` data source) and create a new `OpenStackDataPlaneDeployment` to apply it.

# **3. Operating the Cluster (Day 2)**

## **3.1 Control Plane Infrastructure**

### **MariaDB / Galera**

```
oc get galera -n openstack

# Root password comes from the osp-secret Secret
PASSWORD=$(oc get secret osp-secret -n openstack -o jsonpath='{.data.DbRootPassword}' | base64 -d)

oc rsh -n openstack openstack-galera-0 \
  mysql -uroot -p"$PASSWORD" -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
oc rsh -n openstack openstack-galera-0 \
  mysql -uroot -p"$PASSWORD" -e "SHOW STATUS LIKE 'wsrep_cluster_status';"
```

* Remember there are typically two Galera clusters: `openstack-galera-*` and `openstack-cell1-galera-*` — check both.

* `wsrep_cluster_size` should equal the configured replica count; `wsrep_cluster_status` should read `Primary` on every node.

* Scaling replicas is done via the `OpenStackControlPlane` spec (`spec.galera.templates.<name>.replicas`), not by scaling a StatefulSet manually.

### **RabbitMQ**

```
oc get statefulset -n openstack -l app.kubernetes.io/component=rabbitmq
oc rsh -n openstack rabbitmq-server-0 rabbitmqctl cluster_status
oc rsh -n openstack rabbitmq-server-0 rabbitmqctl list_queues name messages consumers
```

* There are typically two RabbitMQ clusters as well (`rabbitmq-server-*` and `rabbitmq-cell1-server-*`).

* Watch for partitioned clusters (network partitions show up in `cluster_status`) and unconsumed queue buildup, which usually points at a stuck or undersized conductor/agent on the consuming side.

### **Memcached**

Scaling is a replica count change on the Memcached section of the `OpenStackControlPlane` spec. The infra-operator updates the Memcached CR's server list in its status, and the service operators regenerate the consuming services' configuration accordingly — you do not edit any service config by hand.

## **3.2 Data Plane (EDPM) Operations**

### **Cordoning a Compute Node (steps only)**

1. Disable the nova-compute service for that host:

```
openstack compute service set <host> nova-compute --disable --disable-reason "planned maintenance"
```

2. Live-migrate or evacuate remaining instances off the host (per your migration network and shared-storage constraints). The legacy `nova host-evacuate-live` command is **not available** — the `nova` CLI was removed from python-novaclient and is not shipped in the openstackclient pod. Migrate per instance instead:

```
openstack server list --host <host> --all-projects
for ID in $(openstack server list --host <host> --all-projects -f value -c ID); do
  openstack server migrate --live-migration "$ID"
done
```

3. Confirm zero instances remain: `openstack server list --host <host> --all-projects`.

4. When maintenance is complete, re-enable the service: `openstack compute service set <host> nova-compute --enable`.

**EDPM is Ansible, not GitOps-on-the-node:** Nothing is continuously reconciled on the data-plane nodes the way the control plane is. Drift only gets corrected the next time an `OpenStackDataPlaneDeployment` runs — so run one after any manual fix you make directly on a compute node.

## **3.3 Storage Operations**

Glance, Cinder, and Nova (ephemeral/root disks) are typically backed by Ceph/ODF via RBD. Storage Day 2 work is mostly about backend health and capacity, not the OpenStack services themselves.

```
# From a Ceph toolbox / admin context
ceph -s
ceph osd status
ceph df
rados df -p <cinder-volumes-pool>

# Cinder/Nova-side backend checks (from the openstackclient pod)
openstack volume service list
openstack compute service list

or

oc rsh openstackclient openstack volume service list
oc rsh openstackclient openstack compute service list
```

* `ceph -s` HEALTH_WARN/HEALTH_ERR always takes priority over anything reported in Cinder/Glance logs — clear that first.

* New backends or pool changes are applied by editing the Cinder section of the `OpenStackControlPlane` CR (`spec.cinder.template.cinderVolumes.<backend>.customServiceConfig`), not `cinder.conf` directly. Ceph client keys/conf reach pods and EDPM nodes via the `ceph-conf-files` Secret and `extraMounts`.

## **3.4 Networking Operations**

### **Control-Plane Side**

* OVN northbound/southbound databases run as control-plane pods; ovn-operator manages them.

* MetalLB (L2 mode) typically fronts LoadBalancer-type Services for internal API and OVN DB endpoints that need a stable VIP on the isolated networks.

```
oc get pods -n openstack -l service=ovsdbserver-nb
oc get svc -n openstack -l service=ovsdbserver-nb
oc get l2advertisement -n metallb-system
oc get ipaddresspool -n metallb-system
```

### **Data-Plane Side**

* Each EDPM node runs ovn-controller, registering as an OVN chassis. Data-plane node networking (bonds, VLANs) is rendered by the EDPM Ansible roles (`edpm_network_config` using os-net-config) from the NodeSet's network definitions; the `NodeNetworkConfigurationPolicy` (NNCP)/nmstate objects configure the **OCP worker** attachments, and `NetConfig` defines the RHOSO network/subnet layout used for IPAM.

```
# On an EDPM compute node (i.e. ssh -i /home/lab-user/.ssh/<GUID>key.pem cloud-user@compute01)
# ovn-controller runs in a podman container — run ovn-appctl inside it:
sudo podman exec ovn_controller ovn-appctl -t ovn-controller connection-status
# Open vSwitch runs on the host:
sudo ovs-vsctl show

# Against the OVN SB DB (e.g. from the ovsdbserver-sb pod)
ovn-sbctl show   # chassis registration, should list every compute host

# Cluster-side network config objects
oc get netconfig -n openstack
oc get nncp
```

**Production note:** Production MetalLB experience here is L2-mode only — BGP-mode MetalLB and BGP/dynamic-routing designs are valid alternatives but follow a different operational model not covered by the L2 troubleshooting steps above.

## **3.5 Backup & Disaster Recovery**

1. Control-plane CR backup (config, not data): `oc get openstackcontrolplane -n openstack -o yaml > controlplane-backup.yaml`, repeated for `OpenStackVersion`, each `OpenStackDataPlaneNodeSet`, and the Secrets they reference (`osp-secret`, SSH keys, TLS bundles). CR YAML alone does not restore a cluster — it's one input to recovery.

2. MariaDB data backup: Red Hat's documented stance is to back up with your preferred backup and recovery tooling before updates; a scheduled Galera-consistent dump (e.g. `mysqldump --all-databases --single-transaction` against one node) stored off-cluster is a common minimum for labs and classes.

3. OVN DB backup: `ovsdb-client backup` against the NB/SB endpoints before any OVN-impacting change.

4. OpenShift-level: etcd backup and a persistent volume snapshot/backup policy (e.g. OADP) are outside RHOSO's scope but are a hard prerequisite — confirm they're current before any RHOSO update window.

## **3.6 Certificate Management**

```
oc get certificate -n openstack
oc get certificate -n openstack -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter
oc get issuer -n openstack
oc describe certificate <name> -n openstack
```

* cert-manager auto-renews before expiry by default; a `Ready=False` condition or an EXPIRY in the past means renewal is stuck — check the associated CertificateRequest and Issuer status next. RHOSO's issuers are namespaced Issuers (e.g. `rootca-internal`, `rootca-public`), not ClusterIssuers, unless you integrated a custom CA.

* Data-plane node certificates (libvirt, OVN) are distributed by the `install-certs` EDPM service — after cert changes affecting EDPM, run a new `OpenStackDataPlaneDeployment`.

## **3.7 Version Updates — Sequencing (Steps Only)**

1. Confirm RHOCP platform version compatibility for the target RHOSO release (RHOCP 4.18 for RHOSO ≥ 18.0.6).

2. Backup (3.5).

3. Update the operator via OLM (2.3, steps 3–5).

4. Patch `OpenStackVersion.spec.targetVersion`; the control-plane OVN services update first.

5. Update OVN on the data plane: new `OpenStackDataPlaneDeployment` with `servicesOverride: [ovn]`.

6. Let the remaining control-plane services roll; validate control-plane health fully before continuing.

7. Run a full data-plane update `OpenStackDataPlaneDeployment` to bring EDPM node packages/containers in line.

8. Re-validate `openstack compute service list`, `openstack hypervisor list`, and a smoke-test instance boot/network/volume attach before declaring done.

# **4. Troubleshooting**

## **4.1 Triage Order**

Work top-down through the reconciliation chain instead of jumping straight to pod logs — it's almost always faster to find which layer is actually broken first.

1. `OpenStackControlPlane` status conditions — which service is unhealthy, and what message did the operator attach?

2. That service's own CR (e.g. KeystoneAPI, NovaAPI, Galera) — does its status match, or is the operator itself stuck reconciling?

3. Pods backing that CR — `oc get pods`, `oc describe pod` for events (scheduling, image pull, probe failures).

4. Container/application logs — `oc logs`, and `oc logs --previous` if it's currently crash-looping.

5. Underlying dependency (DB, MQ, network, certificates) — is the actual error a downstream connectivity issue surfacing one layer up?

## **4.2 Common Issues and Resolutions**

| Symptom | Likely Cause / First Checks |
| :---- | :---- |
| CSV stuck in Pending | InstallPlan not approved (manual approval mode), or CatalogSource unhealthy — check `oc get catalogsource -n openshift-marketplace` |
| Service pod CrashLoopBackOff | Check `oc logs --previous` first; common causes are a DB/MQ secret mismatch or a bad `customServiceConfig` patch |
| Galera won't form cluster / no Primary | Check `wsrep_cluster_status` on each pod; after an ungraceful shutdown the operator's recovery logic may need help identifying the most-advanced node (highest seqno in the grastate) — see the mariadb-operator recovery procedure before any manual bootstrap |
| RabbitMQ queues backing up | `rabbitmqctl list_queues name messages consumers` — zero consumers usually means the conductor/agent on the consuming side is stuck, not RabbitMQ itself |
| New compute host never appears in hypervisor list | Check the `app=openstackansibleee` Job logs for the deployment first; if Ansible succeeded, check chassis registration in the OVN SB DB and run `nova-manage cell_v2 discover_hosts --verbose` from a conductor pod |
| Neutron port stuck DOWN / binding failed | Confirm ovn-controller is connected on the hosting compute (`ovn-appctl -t ovn-controller connection-status`) and that the chassis is present in the OVN SB DB |
| Glance image upload fails or hangs | Check Ceph health and RBD pool permissions/quota first — Glance errors here are almost always backend, not Glance itself |
| Cinder volume stuck in `creating` | cinder-volume pod logs plus `openstack volume service list` — a down cinder-volume service for that backend is the most common cause |
| Live migration fails partway | Check shared storage/Ceph reachability from the destination host, libvirt TLS certificates on both hosts, and the migration network MTU between source and destination |

## **4.3 Log and Diagnostic Collection**

### **Control plane: RHOSO must-gather**

```
# Default cluster data + RHOSO-specific collection
oc adm must-gather \
  --image-stream=openshift/must-gather \
  --image=registry.redhat.io/rhoso-operators/openstack-must-gather-rhel9:1.0
```

The RHOSO must-gather also collects SOS reports from the RHOCP nodes running RHOSO pods; collectors are tunable via environment variables appended to the gather command (e.g. `-- SOS_SERVICES= gather` to skip SOS collection, `OSP_NS`/`OSP_OPERATORS_NS` for non-default namespaces).

```
# Recent logs for a misbehaving pod
oc logs -n openstack <pod> --since=1h
oc logs -n openstack <pod> --previous

# All events in the namespace, sorted by time
oc get events -n openstack --sort-by=.lastTimestamp
```

### **RHCOS master/worker nodes: sosreport via toolbox**

RHCOS does not ship the `sos` tool natively. The supported method is a debug pod plus the `toolbox` support-tools container (`registry.redhat.io/rhel9/support-tools`; mirror it first in disconnected environments):

```
# 1. Open a debug session on the node (works for masters and workers)
oc debug node/<node_name>

# 2. Use the host binaries
chroot /host

# 3. Launch the support-tools container
toolbox
# If it prints "Container 'toolbox-' exists. Trying to start...", exit,
# remove it with: podman rm toolbox-root
# and rerun toolbox — stale containers break sos plugins.

# 4. Collect the sos report with the parameters Red Hat Support expects
sos report -e openshift -e openshift_ovn -e openvswitch -e podman -e crio \
  -k crio.all=on -k crio.logs=on -k podman.all=on -k podman.logs=on \
  -k networking.ethtool-namespaces=off --all-logs --plugin-timeout=600
```

The archive lands in `/host/var/tmp/` inside the toolbox (i.e. `/var/tmp/` on the node). Retrieve it without SSH by concatenating through a fresh debug session:

```
oc debug node/<node_name> -- bash -c \
  'cat /host/var/tmp/sosreport-<name>.tar.xz' > sosreport-<name>.tar.xz
```

Then remove the archive from the node. Drop `--all-logs` if the archive is too large.

### **EDPM nodes (RHEL hosts): standard sosreport**

`sos` runs natively on the RHEL data-plane nodes:

```
sudo sos report --batch -o openstack_edpm,podman,networking,openvswitch
```

**Capture before you remediate:** Run must-gather / sos report before restarting pods or services where possible — a restart frequently clears the exact evidence (crash logs, core dumps, stuck queue state) you need to root-cause the issue.

## **4.4 Quick Diagnostic Command Reference**

| Layer | Command |
| :---- | :---- |
| OLM | `oc get csv,subscription,installplan -n openstack-operators` |
| Operator init | `oc get openstack -n openstack-operators` ; `oc get deployment -n openstack-operators` |
| Control plane | `oc get openstackcontrolplane -n openstack -o yaml` |
| Version state | `oc get openstackversion -n openstack` |
| Per-service CR | `oc get keystoneapi,novaapi,glance -n openstack` (etc.) |
| Pods | `oc get pods -n openstack -o wide` |
| Events | `oc get events -n openstack --sort-by=.lastTimestamp` |
| Galera | `oc rsh <galera-pod> mysql -uroot -p"$PASSWORD" -e "SHOW STATUS LIKE 'wsrep_%';"` |
| RabbitMQ | `oc rsh <rabbitmq-pod> rabbitmqctl cluster_status` |
| OVN chassis | `ovn-sbctl show` (from/against an OVN SB endpoint) |
| Nova | `openstack compute service list` / `openstack hypervisor list` |
| Cinder | `openstack volume service list` |
| EDPM deployment status | `oc get openstackdataplanedeployment,openstackdataplanenodeset -n openstack` ; `oc get pod -l app=openstackansibleee` |
| Certificates | `oc get certificate -n openstack` |

# **5. Putting It Together**

The common thread across operators, cluster operations, and troubleshooting is the same: RHOSO state lives in Kubernetes custom resources, not in config files on a host. Day 2 work is the discipline of editing the right CR, watching the right operator reconcile it, and reading status conditions before logs. Keep that order — OpenStackControlPlane status, then service CR, then pod, then container — and most incidents narrow down fast.

**Suggested next steps for continued practice:**

* Build a deliberate failure (disable a nova-compute service, force a Galera pod out of the cluster) in a lab and walk the triage order in Section 4.1 end to end.

* Practice a minor update in a non-production environment using the manual-approval + `OpenStackVersion` sequence in 2.3 before doing it live.

* Pair this with the hands-on compute-node cordon drill (3.2) and the sosreport/toolbox collection in 4.3 — those workflows are the ones most teams under-practice before they need them during an incident.
