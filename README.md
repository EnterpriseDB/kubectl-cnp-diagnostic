# 📊 EDB/CNP Diagnostic plugin for `kubectl`

A specialized `kubectl` plugin designed to collect deep diagnostic information from EDB Postgres for Kubernetes (CNP), CloudNativePG (CNPG), and EDB Postgres Distributed for Kubernetes (PGD4K) clusters.

> **Read-only and safe to run:** This tool never modifies your cluster and never collects credentials or secret values. Only secret names/types, never contents. See "What is collected?" below for the full list.

## 🐧 Mac OS and Linux Installation

Install the plugin globally using the following command:

```
curl -sSfL https://github.com/EnterpriseDB/kubectl-cnp-diagnostic/raw/main/install.sh | sh
```

> **Note**: This script downloads the `kubectl-edbdiag` binary, installs it to `~/.local/bin`, and adds that path to your shell's PATH if it isn't already there, so both `kubectl edbdiag` and a bare `kubectl-edbdiag` work afterwards.

**If the command above hangs or times out:** some corporate networks (Netskope, Zscaler, and similar SSL-inspecting proxies) silently block GitHub's raw-content URLs. Use this instead:

```
git clone https://github.com/EnterpriseDB/kubectl-cnp-diagnostic.git
cd kubectl-cnp-diagnostic
bash install.sh
```

## 🪟 Windows Installation

1. Download the `kubectl-edbdiag` file from this repository.
2. Create a folder for your plugins (e.g., `C:\kubectl-plugins`).
3. Move the file into that folder and rename it to `kubectl-edbdiag.exe`.
4. Add the folder path to your system's **PATH** environment variable.

---

## 🛠 Usage

Once installed, trigger the diagnostic collection by running either:

```
kubectl edbdiag
```
or
```
kubectl-edbdiag
```

The tool auto-detects whether you're on plain Kubernetes or OpenShift (`oc`) and uses the right CLI for every command. At any prompt, you can type `q` (or `quit`/`exit`) to stop without collecting anything.

### What is collected?
The tool generates a comprehensive `.tar.gz` package including:
* **Operator Variant**: CNP, CNPG, or PGD4K selected first, before any cluster/namespace input.
* **Collection Scope**:
    * CNP/CNPG: collect every cluster across every namespace, or a single named cluster.
    * PGD4K: since a PGD group is made up of multiple per-node `Cluster` resources (often across namespaces), the tool auto-discovers all of them and lets you collect the whole group, one namespace, or a single node.
* **Cluster Level**: Status, full/cleaned YAML manifests, `describe` output, namespace events, ScheduledBackups, Jobs, PGDGroupCleanups, PVCs, Secrets (names/types only — never contents), and the Namespace definition (captures OpenShift SCC/UID-range annotations).
* **Operator Level**: Version tags, deployment manifests, controller logs, and RBAC (operator ClusterRole, OLM-owned ClusterRoles, ClusterRoleBindings).
* **Pod Level**: `describe` output, OpenShift SCC/security-context annotation, and logs for **every container and init container** on the pod (not just `postgres`).
* **`pods-logs/`**: every pod's logs (data nodes, operator, and on PGD4K proxy pods) are also mirrored flat into one top-level folder as `<namespace>__<pod>__<container>.log`, so you can grep across the whole run without walking the nested tree.
* **Database Stats**: Collected for **every** database in the cluster:
    * **Performance**: Detailed lock analysis (`pg_locks`) and session activity (`pg_stat_activity`).
    * **Blocking Analysis**: Advanced detection of blocked PIDs and blocking statements.
    * **Storage**: Table and Index bloat reports with live/dead tuple counts.
    * **Maintenance**: Extension lists, database versions, and `SHOW ALL` parameters.
    * **Replication**: Slot details with retained-WAL size, `pg_stat_subscription`, and role OIDs (`pg_roles`) useful for spotting a role created independently on each node instead of via replicated DDL.
* **PGD4K-specific**: per-node BDR/PGD catalog views (`bdr.node_summary`, `bdr.node_slots`, `bdr.worker_errors`, `bdr.subscription_summary`, `bdr.subscription`, `bdr.group_versions_details`, `bdr.group_raft_details`, `bdr.group_replslots_details`, `bdr.proxy_config_summary`, `write_leader` history), the native `pgd` CLI (`check-health`, `show-groups`, `show-nodes`, `show-raft`, `replication show --slots`), PGDGroup/PGDGroupCleanup manifests, and dedicated `describe`+logs for PGD Proxy pods.

> **Note on data handling:** `postgres.log` is collected in full. If your cluster has verbose SQL logging enabled (e.g. `log_statement = all`), that log could contain literal query values. Review the generated `.tar.gz` before sharing it if your organization has strict data-handling requirements.
---

## 📋 Usage Example

### Execution Flow:
```
$ kubectl-edbdiag
Detected OpenShift context - using 'oc' for all cluster commands.
Select Operator Variant:
  1) EDB Postgres® AI for CloudNativePG™ Cluster (CNP)
  2) CloudNativePG™ (CNPG)
  3) EDB Postgres® AI for CloudNativePG™ Global Cluster (PGD4K)
  q) Quit
Enter choice [1-3, or q to quit]: 1

=== Discovering CNP clusters in your Kubernetes context ===

Select collection scope:
  1) All CNP clusters, across all namespaces
  2) A specific cluster (you provide namespace + cluster name)
  q) Quit
Enter choice [1, 2, or q]: 2

Detected clusters:
   1) postgresql-advanced-cluster       (namespace: default)
   2) Enter manually
   q) Quit
Select cluster [1-2, or q]: 1

Targets to collect (1):
  - namespace=default  cluster=postgresql-advanced-cluster

Starting comprehensive collection into: edb_diag_postgresql-advanced-cluster_20260810_205527
  (all pod logs are also mirrored flat into: edb_diag_postgresql-advanced-cluster_20260810_205527/pods-logs)

Collecting operator-level info...
  Found operator pod: postgresql-operator-controller-manager-754f87c5b-bqv9n (ns: postgresql-operator-system)
=== Collecting cluster: default/postgresql-advanced-cluster ===
  --- Processing Pod: postgresql-advanced-cluster-1 ---
     -> Collecting from Database: postgres
     -> Collecting from Database: edb
     -> Collecting from Database: app
  --- Processing Pod: postgresql-advanced-cluster-2 ---
  --- Processing Pod: postgresql-advanced-cluster-3 ---
--------------------------------------------------------
Collection complete: edb_diag_postgresql-advanced-cluster_20260810_205527.tar.gz
```

For PGD4K, the flow is the same up through variant selection, then instead of asking for one namespace/cluster, it auto-discovers every node-cluster in the group:

```
$ kubectl-edbdiag
Detected OpenShift context - using 'oc' for all cluster commands.
Select Operator Variant:
  1) EDB Postgres® AI for CloudNativePG™ Cluster (CNP)
  2) CloudNativePG™ (CNPG)
  3) EDB Postgres® AI for CloudNativePG™ Global Cluster (PGD4K)
  q) Quit
Enter choice [1-3, or q to quit]: 3

=== Discovering PGD4K clusters in your Kubernetes context ===

Detected PGD4K node clusters:
   1) region-a-1   (namespace: default)
   2) region-a-2   (namespace: default)
   3) region-a-3   (namespace: default)
   4) region-b-1   (namespace: default)
   5) region-b-2   (namespace: default)
   6) region-b-3   (namespace: default)
   7) region-c-1   (namespace: default)

Select scope:
  a) Collect ALL PGD4K nodes/clusters listed above (recommended - needed for group-level BDR/Raft diagnostics)
  n) Collect only clusters within one specific namespace
  m) Enter a single namespace + cluster manually
  q) Quit
Enter choice [a/n/m/q] (default a): a

Targets to collect (7): ...
=== Collecting PGD/BDR group-wide diagnostics (via region-a-1-1) ===
  Collecting PGD Proxy pod diagnostics...
--------------------------------------------------------
Collection complete: edb_diag_pgd4k_multi_20260810_185026.tar.gz
```
---

## 📋 Generated Result Structure

### CNP / CNPG

The tool organizes results by cluster, pod, and database for easy troubleshooting:

```
.
├── clusters
│   └── default__postgresql-advanced-cluster
│       ├── cluster_info
│       │   ├── backups_summary.txt
│       │   ├── backups.yaml
│       │   ├── cluster_definition_clean.yaml
│       │   ├── cluster_definition_full.yaml
│       │   ├── cluster_describe.txt
│       │   ├── cluster_status.txt
│       │   ├── jobs.txt
│       │   ├── namespace_definition.yaml
│       │   ├── namespace_events.txt
│       │   ├── pgdgroupcleanups.yaml
│       │   ├── pvc_list.txt
│       │   ├── scheduledbackups.yaml
│       │   └── secrets_list.txt
│       └── pods
│           ├── postgresql-advanced-cluster-1
│           │   ├── describe_result.txt
│           │   ├── postgresql
│           │   │   ├── activity_counts.out
│           │   │   ├── archiver.out
│           │   │   ├── bgwriter.out
│           │   │   ├── bootstrap-controller_previous.log
│           │   │   ├── bootstrap-controller.log
│           │   │   ├── db_app
│           │   │   │   ├── blocking_analysis_detailed.out
│           │   │   │   ├── blocking_summary.out
│           │   │   │   ├── database_bloat.out
│           │   │   │   ├── extensions.out
│           │   │   │   ├── index_bloat.out
│           │   │   │   ├── pg_locks.out
│           │   │   │   ├── pg_stat_activity.out
│           │   │   │   ├── pg_stat_user_tables.out
│           │   │   │   └── table_tuples.out
│           │   │   ├── db_edb
│           │   │   │   ├── blocking_analysis_detailed.out
│           │   │   │   ├── blocking_summary.out
│           │   │   │   ├── database_bloat.out
│           │   │   │   ├── extensions.out
│           │   │   │   ├── index_bloat.out
│           │   │   │   ├── pg_locks.out
│           │   │   │   ├── pg_stat_activity.out
│           │   │   │   ├── pg_stat_user_tables.out
│           │   │   │   └── table_tuples.out
│           │   │   ├── db_postgres
│           │   │   │   ├── blocking_analysis_detailed.out
│           │   │   │   ├── blocking_summary.out
│           │   │   │   ├── database_bloat.out
│           │   │   │   ├── extensions.out
│           │   │   │   ├── index_bloat.out
│           │   │   │   ├── pg_locks.out
│           │   │   │   ├── pg_stat_activity.out
│           │   │   │   ├── pg_stat_user_tables.out
│           │   │   │   └── table_tuples.out
│           │   │   ├── db_version.out
│           │   │   ├── pg_roles.out
│           │   │   ├── pg_stat_subscription.out
│           │   │   ├── plugin-barman-cloud_previous.log
│           │   │   ├── plugin-barman-cloud.log
│           │   │   ├── postgres_previous.log
│           │   │   ├── postgres.log
│           │   │   ├── replication_slots.out
│           │   │   ├── replication.out
│           │   │   └── show_all.out
│           │   └── scc_and_security_context.txt
│           ├── postgresql-advanced-cluster-2
│           │
│           └── postgresql-advanced-cluster-4
│
├── operator_info
│   ├── barman_plugin_version.txt
│   ├── clusterrolebindings.yaml
│   ├── logs
│   │   ├── manager_previous.log
│   │   └── manager.log
│   ├── olm_owned_clusterroles.yaml
│   ├── operator_clusterrole.txt
│   ├── operator_manifest.yaml
│   └── operator_version.txt
├── pods-logs
│   ├── default__postgresql-advanced-cluster-1__bootstrap-controller_previous.log
│   ├── default__postgresql-advanced-cluster-1__bootstrap-controller.log
│   ├── default__postgresql-advanced-cluster-1__plugin-barman-cloud_previous.log
│   ├── default__postgresql-advanced-cluster-1__plugin-barman-cloud.log
│   ├── default__postgresql-advanced-cluster-1__postgres_previous.log
│   ├── default__postgresql-advanced-cluster-1__postgres.log
│   ├── default__postgresql-advanced-cluster-2__bootstrap-controller_previous.log
│   ├── default__postgresql-advanced-cluster-2__bootstrap-controller.log
│   ├── default__postgresql-advanced-cluster-2__plugin-barman-cloud_previous.log
│   ├── default__postgresql-advanced-cluster-2__plugin-barman-cloud.log
│   ├── default__postgresql-advanced-cluster-2__postgres_previous.log
│   ├── default__postgresql-advanced-cluster-2__postgres.log
│   ├── default__postgresql-advanced-cluster-3__bootstrap-controller_previous.log
│   ├── default__postgresql-advanced-cluster-3__bootstrap-controller.log
│   ├── default__postgresql-advanced-cluster-3__plugin-barman-cloud_previous.log
│   ├── default__postgresql-advanced-cluster-3__plugin-barman-cloud.log
│   ├── default__postgresql-advanced-cluster-3__postgres_previous.log
│   ├── default__postgresql-advanced-cluster-3__postgres.log
│   ├── postgresql-operator-system__postgresql-operator-controller-manager-754f87c5b-bqv9n__manager_previous.log
│   └── postgresql-operator-system__postgresql-operator-controller-manager-754f87c5b-bqv9n__manager.log
└── storage
    └── all_pv_list.txt

24 directories, 174 files
```

### PGD4K

Same per-pod/per-database layout as above, repeated for **every node-cluster** in the group, plus a `pgd_group_info/` folder for group-wide BDR/Raft diagnostics and PGD Proxy pods:

```
.
├── clusters
│   ├── default__region-a-1
│   │   ├── cluster_info
│   │   │   ├── backups_summary.txt
│   │   │   ├── backups.yaml
│   │   │   ├── cluster_definition_clean.yaml
│   │   │   ├── cluster_definition_full.yaml
│   │   │   ├── cluster_describe.txt
│   │   │   ├── cluster_status.txt
│   │   │   ├── jobs.txt
│   │   │   ├── namespace_definition.yaml
│   │   │   ├── namespace_events.txt
│   │   │   ├── pgdgroupcleanups.yaml
│   │   │   ├── pvc_list.txt
│   │   │   ├── scheduledbackups.yaml
│   │   │   └── secrets_list.txt
│   │   └── pods
│   │       └── region-a-1-1
│   │           ├── describe_result.txt
│   │           ├── postgresql
│   │           │   ├── activity_counts.out
│   │           │   ├── archiver.out
│   │           │   ├── bdr_group_raft_details.out
│   │           │   ├── bdr_group_replslots_details.out
│   │           │   ├── bdr_group_versions_details.out
│   │           │   ├── bdr_node_slots.out
│   │           │   ├── bdr_node_summary.out
│   │           │   ├── bdr_proxy_config_summary.out
│   │           │   ├── bdr_subscription_summary.out
│   │           │   ├── bdr_subscription.out
│   │           │   ├── bdr_worker_errors.out
│   │           │   ├── bdr_write_leader_history.out
│   │           │   ├── bgwriter.out
│   │           │   ├── bootstrap-controller_previous.log
│   │           │   ├── bootstrap-controller.log
│   │           │   ├── db_app
│   │           │   │   ├── blocking_analysis_detailed.out
│   │           │   │   ├── blocking_summary.out
│   │           │   │   ├── database_bloat.out
│   │           │   │   ├── extensions.out
│   │           │   │   ├── index_bloat.out
│   │           │   │   ├── pg_locks.out
│   │           │   │   ├── pg_stat_activity.out
│   │           │   │   ├── pg_stat_user_tables.out
│   │           │   │   └── table_tuples.out
│   │           │   ├── db_postgres
│   │           │   │   ├── blocking_analysis_detailed.out
│   │           │   │   ├── blocking_summary.out
│   │           │   │   ├── database_bloat.out
│   │           │   │   ├── extensions.out
│   │           │   │   ├── index_bloat.out
│   │           │   │   ├── pg_locks.out
│   │           │   │   ├── pg_stat_activity.out
│   │           │   │   ├── pg_stat_user_tables.out
│   │           │   │   └── table_tuples.out
│   │           │   ├── db_version.out
│   │           │   ├── pg_roles.out
│   │           │   ├── pg_stat_subscription.out
│   │           │   ├── pgd_replication_slots.out
│   │           │   ├── postgres_previous.log
│   │           │   ├── postgres.log
│   │           │   ├── replication_slots.out
│   │           │   ├── replication.out
│   │           │   └── show_all.out
│   │           └── scc_and_security_context.txt
:
│   ├── default__region-x-x
:
:
├── operator_info
│   ├── clusterrolebindings.yaml
│   ├── logs
│   │   ├── manager_previous.log
│   │   └── manager.log
│   ├── olm_owned_clusterroles.yaml
│   ├── operator_clusterrole.txt
│   ├── operator_manifest.yaml
│   └── operator_version.txt
├── pgd_group_info
│   ├── pgd_check_health.out
│   ├── pgd_show_groups.out
│   ├── pgd_show_nodes.out
│   ├── pgd_show_raft.out
│   ├── pgdgroupcleanups.yaml
│   ├── pgdgroups.yaml
│   └── proxy_pods
│       └── kube-system__kube-proxy-q8jz2
│           ├── describe_result.txt
│           ├── kube-proxy_previous.log
│           └── kube-proxy.log
├── pods-logs
│   ├── default__region-a-1-1__bootstrap-controller_previous.log
│   ├── default__region-a-1-1__bootstrap-controller.log
│   ├── default__region-a-1-1__postgres_previous.log
│   ├── default__region-a-1-1__postgres.log
│   ├── default__region-a-2-1__bootstrap-controller_previous.log
│   ├── default__region-a-2-1__bootstrap-controller.log
│   ├── default__region-a-2-1__postgres_previous.log
│   ├── default__region-a-2-1__postgres.log
│   ├── default__region-a-3-1__bootstrap-controller_previous.log
│   ├── default__region-a-3-1__bootstrap-controller.log
│   ├── default__region-a-3-1__postgres_previous.log
│   ├── default__region-a-3-1__postgres.log
│   ├── default__region-b-1-1__bootstrap-controller_previous.log
│   ├── default__region-b-1-1__bootstrap-controller.log
│   ├── default__region-b-1-1__postgres_previous.log
│   ├── default__region-b-1-1__postgres.log
│   ├── default__region-b-2-1__bootstrap-controller_previous.log
│   ├── default__region-b-2-1__bootstrap-controller.log
│   ├── default__region-b-2-1__postgres_previous.log
│   ├── default__region-b-2-1__postgres.log
│   ├── default__region-b-3-1__bootstrap-controller_previous.log
│   ├── default__region-b-3-1__bootstrap-controller.log
│   ├── default__region-b-3-1__postgres_previous.log
│   ├── default__region-b-3-1__postgres.log
│   ├── default__region-c-1-1__bootstrap-controller_previous.log
│   ├── default__region-c-1-1__bootstrap-controller.log
│   ├── default__region-c-1-1__postgres_previous.log
│   ├── default__region-c-1-1__postgres.log
│   ├── kube-system__kube-proxy-q8jz2__kube-proxy_previous.log
│   ├── kube-system__kube-proxy-q8jz2__kube-proxy.log
│   ├── pgd-operator-system__pgd-operator-controller-manager-59c64c7c69-928dg__manager_previous.log
│   └── pgd-operator-system__pgd-operator-controller-manager-59c64c7c69-928dg__manager.log
└── storage
    └── all_pv_list.txt

58 directories, 448 files
```
