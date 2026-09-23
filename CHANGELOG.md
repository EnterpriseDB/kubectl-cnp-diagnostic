# Changelog

All notable changes to `kubectl-edbdiag` are documented here, most recent
first.

Versioning follows [Semantic Versioning](https://semver.org/):
`MAJOR.MINOR.PATCH`
- **MAJOR** — breaking changes (renamed/removed flags, changed output
  directory structure, anything that could break existing automation
  around this tool)
- **MINOR** — new, backward-compatible features
- **PATCH** — bug fixes, no behavior change

Check your installed version with `kubectl edbdiag version`, then compare
it against the entries below to see whether you're missing anything — see
the README's "Checking for Updates & Upgrading" section for how to update.

---

## [Unreleased]

Nothing pending yet — this section fills in as changes are made after
1.2.0.

## [1.2.0] - 2026-09-23

- Added: a new `edbdiag_version.txt` file at the root of every collected
  bundle (alongside `clusters/`, `operator_info/`, `pgd_group_info/`,
  `pods-logs/`, and `storage/`). It contains the same output as `kubectl
  edbdiag version` (version + the script's own SHA-256), plus the
  collection timestamp (UTC), the operator variant (CNP/CNPG/PGD4K), and
  whether `kubectl` or `oc` was used. Previously there was no way to tell
  which version of the tool produced a given report short of asking
  whoever ran it.
- Added: `cluster_info/cluster_status.txt` no longer ends up empty when the
  `kubectl-cnp`/`kubectl-cnpg` plugin isn't installed on the machine
  running the collection. That case is now detected directly from
  kubectl's own error for an unrecognized plugin verb, and instead of
  leaving the file empty, an equivalent status report (phase, instance
  counts, current/target primary, certificate expirations, and a
  per-instance table from pod labels) is built straight from the Cluster
  CR and pod list, which needs no plugin at all. Also: when the plugin
  IS installed but the status call fails for some other real reason
  (RBAC, unreachable cluster, etc.), that error is now kept in the file
  instead of being silently discarded — the same class of bug already
  fixed for `backups_summary.txt` in 1.1.1.

## [1.1.1] - 2026-09-21

- Fixed: `backups_summary.txt` (`cluster_info/`) was always an empty file.
  It came from `kubectl cnp`/`kubectl cnpg get backups <cluster>`, which is
  not a real subcommand of either plugin — confirmed directly against a
  live cluster: `Error: unknown command "get" for "kubectl cnp"`. The
  error was being silently swallowed by `2>/dev/null || true`, so this had
  been broken since the line was first written, not a regression. Now
  built from the `Backup` CRs directly (`kubectl get backup -o
  custom-columns=...`), which needs no plugin and works identically on
  CNP, CNPG, and PGD4K. Noticed because the file was empty even though
  completed backups were listed in `backups.yaml`.
- Fixed: `backups.yaml` collected every `Backup` in the namespace
  unfiltered, mixing different clusters' backups together whenever more
  than one cluster shares a namespace. Both `backups.yaml` and
  `backups_summary.txt` are now scoped to the current cluster via the
  label the operator itself sets on the `Backup` CR (`cnpg.io/cluster` on
  community CNPG, `k8s.enterprisedb.io/cluster` on CNP/PGD4K).

## [1.1.0] - 2026-09-16

This release supersedes 1.0.1 — it contains everything from 1.0.1 below
plus the two additions here. If you're upgrading from 1.0.0 or earlier,
you're picking up both sets of changes at once.

- Fixed (carried forward from 1.0.1): PGD Proxy pod discovery
  (`pgd_group_info/proxy_pods/`) used a `-proxy-` name/substring match,
  which also matched Kubernetes' own built-in `kube-proxy-<hash>` pods
  (kube-system, present on every cluster regardless of PGD) — noise from a
  component completely unrelated to PGD. Now uses the PGD Proxy
  StatefulSet's actual operator-set label
  (`k8s.pgd.enterprisedb.io/workloadType=pgd-proxy`), which only ever
  matches genuine PGD Proxy pods.
- Added: PGD4K per-pod collection now dumps the entire `bdr` schema catalog
  (every table + view, ~127 files on PGD 5.9.4 / ~128 on 6.x) into a new
  `postgresql/bdr_catalog/` folder, instead of only the curated subset of
  `bdr.*` views collected by hand before. This is schema-discovery at
  runtime rather than a hand-maintained list, so it automatically adapts to
  whatever PGD version is installed and keeps pace with future PGD releases
  without going stale. Brings collection breadth in line with EDB's
  internal "Lasso" diagnostic tool.
- Changed: PGD4K's scope-selection prompt now uses numbered options
  (`1`/`2`/`3`/`q`) instead of letters (`a`/`n`/`m`/`q`), matching the
  numbered style already used by the CNP/CNPG scope menu and the top-level
  variant-selection menu.

## [1.0.1] - 2026-09-16

Superseded by 1.1.0 — see that entry above for details (this version's
fix is included there in full).

## [1.0.0] - 2026-09-04

- Initial versioned release. Added `kubectl edbdiag version` (also `-v` /
  `--version`), which prints the script's own SHA-256 so you can confirm
  your installed copy is byte-for-byte current with `main`. Unlike the
  compiled `kubectl cnp`/`kubectl cnpg` plugins, this is a plain shell
  script with no build step to stamp a commit hash into automatically —
  the SHA-256 is the equivalent check.
