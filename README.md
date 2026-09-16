# 📊 EDB/CNP Diagnostic plugin for `kubectl`

A specialized `kubectl` plugin designed to collect deep diagnostic information from EDB Postgres for Kubernetes (CNP), CloudNativePG (CNPG), and EDB Postgres Distributed for Kubernetes (PGD4K) clusters.

## 🐧 Mac OS and Linux Installation

Install the plugin using the following command (no `sudo` required):

```
curl -sSfL https://github.com/EnterpriseDB/kubectl-cnp-diagnostic/raw/main/install.sh | sh
```

> **Note**: This script downloads the `kubectl-edbdiag` binary, installs it to `~/.local/bin` (your own user directory — no root/admin privileges needed), and adds that path to your shell's PATH if it isn't already there — so both `kubectl edbdiag` and a bare `kubectl-edbdiag` work afterwards. `sudo` is intentionally not used: on many corporate-managed Macs, `sudo` triggers an MDM/endpoint-security elevation prompt that can hang a piped install with no visible output.

## 🪟 Windows Installation

1. Download the `kubectl-edbdiag` file from this repository.
2. Create a folder for your plugins (e.g., `C:\kubectl-plugins`).
3. Move the file into that folder and rename it to `kubectl-edbdiag.exe`.
4. Add the folder path to your system's **PATH** environment variable.

## 📴 Offline / Air-Gapped Installation

If the machine that actually has `kubectl`/`oc` access to the cluster (a
bastion host, a locked-down production jump box, etc.) has no internet
access at all, `install.sh` won't work there — it does a `git clone`
internally, which needs a live connection. Instead, fetch the plugin on a
machine that does have internet access, then transfer just that one file
over.

**Step 1 — on a machine WITH internet access**, download just the plugin
(no need to clone the whole repo):
```
curl -sSfLo kubectl-edbdiag https://raw.githubusercontent.com/EnterpriseDB/kubectl-cnp-diagnostic/main/kubectl-edbdiag
chmod +x kubectl-edbdiag
```

Optionally confirm what you're about to transfer is genuinely current
before shipping it over:
```
sha256sum kubectl-edbdiag
curl -s https://raw.githubusercontent.com/EnterpriseDB/kubectl-cnp-diagnostic/main/kubectl-edbdiag | sha256sum
```
(both hashes should match)

**Step 2 — transfer the single file** to the offline bastion/production
host:
```
scp kubectl-edbdiag user@bastion-host:/home/user/
```
If `scp` itself is blocked by the user's egress rules, `rsync`, `sftp`, or
even attaching it to an internal ticket/file-share works just as well — it's
one small plain-text script, not a binary.

**Step 3 — on the bastion/production host itself** (no internet needed from
here on):
```
mkdir -p ~/.local/bin
mv kubectl-edbdiag ~/.local/bin/
chmod +x ~/.local/bin/kubectl-edbdiag
export PATH="$HOME/.local/bin:$PATH"     # add this line to ~/.bashrc or ~/.zshrc to persist it
```

**Step 4 — verify and run:**
```
kubectl edbdiag version     # confirms the SHA-256 matches what you fetched in Step 1
kubectl edbdiag --help
kubectl edbdiag --variant pgd4k --scope all -y
```

## 🔄 Checking for Updates & Upgrading

`kubectl-edbdiag` follows [Semantic Versioning](https://semver.org/)
(`MAJOR.MINOR.PATCH`) — every commit that changes the script's actual
behavior bumps the version and adds an entry to
[`CHANGELOG.md`](./CHANGELOG.md), so you always know what changed and
whether you should upgrade.

**1. Check what you're running today:**
```
kubectl edbdiag version
```

**2. See what's changed / what's latest:** check
[`CHANGELOG.md`](./CHANGELOG.md) and compare its top entry's version against
the one you just printed.

**3. Find out EXACTLY which file is actually running.** Don't skip this —
if you've ever manually copied the script somewhere (or installed it more
than once), blindly re-running the installer can create a second, unused
copy instead of upgrading the one your shell actually calls:
```
which kubectl-edbdiag
# or: type -a kubectl-edbdiag
```

**4. Fetch the latest copy:**
- **Recommended** — `git clone` stays on `github.com` itself rather than
  `raw.githubusercontent.com`. Some corporate SSL-inspecting proxies
  (Netskope, etc.) silently hang or block direct requests to
  `raw.githubusercontent.com` — confirmed on a real corporate network
  while testing this exact upgrade path — while git's smart-HTTP protocol
  against `github.com` goes through fine. This is the same reason
  `install.sh` uses `git clone` internally instead of curl-ing the raw
  file directly:
  ```
  TMPDIR_UPGRADE=$(mktemp -d)
  git clone --depth 1 --quiet https://github.com/EnterpriseDB/kubectl-cnp-diagnostic.git "$TMPDIR_UPGRADE/repo"
  cp "$TMPDIR_UPGRADE/repo/kubectl-edbdiag" /tmp/kubectl-edbdiag
  chmod +x /tmp/kubectl-edbdiag
  rm -rf "$TMPDIR_UPGRADE"
  ```
- **Fallback**, if `git` isn't available: fetch directly via `curl`. This
  works fine on many networks, but if the command below just hangs with no
  output, `Ctrl+C` it and use the `git clone` method above instead:
  ```
  curl -sSfLo /tmp/kubectl-edbdiag https://raw.githubusercontent.com/EnterpriseDB/kubectl-cnp-diagnostic/main/kubectl-edbdiag
  chmod +x /tmp/kubectl-edbdiag
  ```
- On an air-gapped bastion: fetch it with either command above on a
  machine that *does* have internet, then transfer `/tmp/kubectl-edbdiag`
  over via `scp`/`rsync`/`sftp` — same as the Offline Installation steps
  above.

**5. Overwrite the EXACT path found in step 3** (not just `~/.local/bin` by
default — overwrite wherever `which` actually pointed):
```
cp /tmp/kubectl-edbdiag "$(which kubectl-edbdiag)"
chmod +x "$(which kubectl-edbdiag)"
```

**6. Confirm the upgrade took effect:**
```
kubectl edbdiag version    # should now show the new version number
```

**Windows:** re-download `kubectl-edbdiag` from the repo and overwrite the
existing `kubectl-edbdiag.exe` in your plugins folder.

**Shortcut for the common case:** if you installed via the one-liner and
have never manually copied the binary anywhere else, re-running the same
install command also works, since it always does a fresh `git clone`:
```
curl -sSfL https://github.com/EnterpriseDB/kubectl-cnp-diagnostic/raw/main/install.sh | sh
```

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

The tool auto-detects whether you're on plain Kubernetes or OpenShift (`oc`) and uses the right CLI for every command. At any prompt you can type `q` (or `quit`/`exit`) to stop without collecting anything.

### What is collected?
The tool generates a comprehensive `.tar.gz` package including:
* **Operator Variant**: CNP, CNPG, or PGD4K — selected first, before any cluster/namespace input.
* **Collection Scope**:
    * CNP/CNPG — collect every cluster across every namespace, or a single named cluster.
    * PGD4K — since a PGD group is made up of multiple per-node `Cluster` resources (often across namespaces), the tool auto-discovers all of them and lets you collect the whole group, one namespace, or a single node.
* **Cluster Level**: Status, full/cleaned YAML manifests, `describe` output, namespace events, ScheduledBackups, Jobs, PGDGroupCleanups, PVCs, Secrets (names/types only — never contents), and the Namespace definition (captures OpenShift SCC/UID-range annotations).
* **Operator Level**: Version tags, deployment manifests, controller logs, and RBAC (operator ClusterRole, OLM-owned ClusterRoles, ClusterRoleBindings).
* **Pod Level**: `describe` output, OpenShift SCC/security-context annotation, and logs for **every container and init container** on the pod (not just `postgres`).
* **`pods-logs/`**: every pod's logs (data nodes, operator, and — on PGD4K — proxy pods) are also mirrored flat into one top-level folder as `<namespace>__<pod>__<container>.log`, so you can grep across the whole run without walking the nested tree.
* **Database Stats**: Collected for **every** database in the cluster:
    * **Performance**: Detailed lock analysis (`pg_locks`) and session activity (`pg_stat_activity`).
    * **Blocking Analysis**: Advanced detection of blocked PIDs and blocking statements.
    * **Storage**: Table and Index bloat reports with live/dead tuple counts.
    * **Maintenance**: Extension lists, database versions, and `SHOW ALL` parameters.
    * **Replication**: Slot detail with retained-WAL size, `pg_stat_subscription`, and role OIDs (`pg_roles`) — useful for spotting a role created independently on each node instead of via replicated DDL.
* **PGD4K-specific**: per-node BDR/PGD catalog views (`bdr.node_summary`, `bdr.node_slots`, `bdr.worker_errors`, `bdr.subscription_summary`, `bdr.subscription`, `bdr.group_versions_details`, `bdr.group_raft_details`, `bdr.group_replslots_details`, `bdr.proxy_config_summary`, `write_leader` history), **plus the entire `bdr` schema catalog** dumped into `postgresql/bdr_catalog/` (every table/view auto-discovered at runtime — ~127 files on PGD 5.9.4, ~128 on 6.x, so it stays current with whatever PGD version is installed), the native `pgd` CLI (`cluster show`/`verify`, `nodes list`, `groups list`, `raft show`, `events show`, `replication show`), the pgd CLI's own version detection (so version-specific commands like the removed `check-health` are skipped cleanly on 6.x+), PGDGroup/PGDGroupCleanup manifests, and dedicated `describe`+logs for genuine PGD Proxy pods only (matched by their operator-set label, never Kubernetes' own `kube-proxy`).
---

## 🤖 Non-Interactive / Scripted Usage

Every prompt can be pre-answered with a flag, which makes it possible to loop
this tool unattended across many clusters — handy when you only reach those
clusters through a jump host / bastion, one `oc login` at a time.

```
  --variant=cnp|cnpg|pgd4k       Operator variant (skips the variant menu)
  --scope=all|namespace|single   Collection scope (skips the scope menu)
                                    all       - every cluster/node found
                                    namespace - every cluster in --namespace
                                    single    - exactly --namespace + --cluster
  --namespace=NAME                Required for scope=namespace or scope=single
  --cluster=NAME                  Required for scope=single
  -y, --yes, --non-interactive    Fail fast instead of prompting if
                                   --variant or --scope wasn't also given
  version, -v, --version          Print the script version + its own
                                   SHA-256 and exit
  -h, --help                      Show full help and exit
```

Any flag you leave out just falls back to its normal interactive prompt — you
can mix and match, or supply everything for a fully unattended run.

**Checking which version you're running:**

Unlike the compiled `kubectl cnpg`/`kubectl cnp` plugins, `kubectl-edbdiag` is a
plain shell script pulled straight from GitHub, so there's no build-injected
`Commit`/`Date` to check. `kubectl edbdiag version` instead prints its own
SHA-256, so you can confirm your installed copy is byte-for-byte the latest
fix on `main`:
```
$ kubectl edbdiag version
kubectl-edbdiag version 1.1.0 (released 2026-09-16)
SHA256:  <64-character hash of your local copy>
Compare against: https://raw.githubusercontent.com/EnterpriseDB/kubectl-cnp-diagnostic/main/kubectl-edbdiag
```
If your hash doesn't match the hash of the file at that URL, re-download and
reinstall — you're on an older copy.

**One specific cluster, no prompts:**
```
kubectl edbdiag --variant cnp --scope single --namespace prod --cluster pg-main -y
```

**Every PGD4K node/cluster in the current context:**
```
kubectl edbdiag --variant pgd4k --scope all -y
```

**Looping across several remote OpenShift clusters from one bastion host** —
if you already have live `oc login` sessions cached as kubeconfig contexts:
```
for ctx in $(oc config get-contexts -o name); do
    echo "=== $ctx ==="
    oc config use-context "$ctx"
    kubectl edbdiag --variant pgd4k --scope all -y
done
```

Or, if each cluster needs a fresh token-based login (tokens usually expire),
keep a `server,token` pair per line in a file only you can read
(`chmod 600 clusters.csv`), and delete it once you're done:
```
while IFS=, read -r server token; do
    echo "=== Logging into $server ==="
    oc login --token="$token" --server="$server" >/dev/null
    kubectl edbdiag --variant pgd4k --scope all -y
done < clusters.csv
```

Each iteration produces its own self-contained `.tar.gz`, so you end up with
one clean bundle per cluster rather than one mixed archive.

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
  --- Processing Pod: postgresql-advanced-cluster-4 ---
--------------------------------------------------------
Collection complete: edb_diag_postgresql-advanced-cluster_20260810_205527.tar.gz
```

For PGD4K, the flow is the same up through variant selection, then instead of asking for one namespace/cluster it auto-discovers every node-cluster in the group:

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
  1) Collect ALL PGD4K nodes/clusters listed above (recommended - needed for group-level BDR/Raft diagnostics)
  2) Collect only clusters within one specific namespace
  3) Enter a single namespace + cluster manually
  q) Quit
Enter choice [1-3, or q] (default 1): 1

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
│   ├── default__postgresql-advanced-cluster-4__bootstrap-controller_previous.log
│   ├── default__postgresql-advanced-cluster-4__bootstrap-controller.log
│   ├── default__postgresql-advanced-cluster-4__plugin-barman-cloud_previous.log
│   ├── default__postgresql-advanced-cluster-4__plugin-barman-cloud.log
│   ├── default__postgresql-advanced-cluster-4__postgres_previous.log
│   ├── default__postgresql-advanced-cluster-4__postgres.log
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
│   │           │   ├── bdr_catalog
│   │           │   │   ├── commit_scopes.out
│   │           │   │   ├── conflict_history_summary.out
│   │           │   │   ├── node_group_summary.out
│   │           │   │   ├── node_summary.out
│   │           │   │   ├── sequences.out
│   │           │   │   ├── stat_activity.out
│   │           │   │   ├── stat_worker.out
│   │           │   │   ├── tables.out
│   │           │   │   ├── triggers.out
│   │           │   │   └── ... (~127 files on PGD 5.9.4 / ~128 on 6.x —
│   │           │   │        every table + view in the `bdr` schema,
│   │           │   │        auto-discovered at runtime, one `.out` per
│   │           │   │        object; the exact set/count varies slightly
│   │           │   │        by PGD version)
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
│   │           │   ├── pgd_cli_version.out
│   │           │   ├── pgd_replication_slots.out
│   │           │   ├── postgres_previous.log
│   │           │   ├── postgres.log
│   │           │   ├── replication_slots.out
│   │           │   ├── replication.out
│   │           │   └── show_all.out
│   │           └── scc_and_security_context.txt
:
│   ├── default__region-x-x        (same layout as region-a-1 above, repeated
:                                    for every node-cluster in the group)
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
│   ├── pgd_check_health.out          (or a "removed in 6.x" note - see below)
│   ├── pgd_cli_version.out
│   ├── pgd_cluster_show.out
│   ├── pgd_cluster_verify.out
│   ├── pgd_commit_scopes.out
│   ├── pgd_events_show.out
│   ├── pgd_groups_list.out
│   ├── pgd_nodes_list.out
│   ├── pgd_raft_show.out
│   ├── pgd_replication_show.out
│   ├── pgdgroupcleanups.yaml
│   ├── pgdgroups.yaml
│   └── proxy_pods
│       └── default__region-a-proxy-0     (only genuine PGD Proxy pods -
│           ├── describe_result.txt         matched by their operator-set
│           ├── postgres_previous.log       label, k8s.pgd.enterprisedb.io/
│           └── postgres.log                workloadType=pgd-proxy - ever
│                                            land here, never kube-proxy or
│                                            any other unrelated system pod)
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
