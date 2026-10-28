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
1.3.0.

## [1.3.0] - 2026-10-28

A handful of these came from real customers running into real walls with
the tool, and it's worth saying plainly: the pattern across all of them is
the same silent-failure problem — a command fails, the error gets thrown
away, and you're left staring at an empty file with no idea why. That's
now fixed in the specific spots below, and it changes how failures show up
going forward: you'll see the actual error instead of nothing.

- Fixed: the preflight check (`kubectl cluster-info`) needed `list
  services` in `kube-system` just to confirm the API server was reachable.
  That's a permission a lot of RBAC-locked-down environments won't hand to
  application/DB-team accounts, even when those same accounts can read
  everything they actually need — their own namespace and the operator's.
  The tool refused to run at all in that situation, even though a real
  collection would have worked fine. It now checks `kubectl get
  --raw=/livez` instead — a plain liveness endpoint any authenticated user
  can reach by default — which proves the same thing (server's up,
  credentials are good) without needing any extra privilege. (#1)
- Fixed: a related gap in operator-level collection (version, manifest,
  RBAC, logs). The pod search behind it used `kubectl get pods -A`, which
  needs a cluster-wide permission — so it failed even when the account
  could read the operator's own namespace just fine, exactly the situation
  above. It now tries a short list of common operator-namespace names with
  a scoped query first, falling back to the old cluster-wide search only
  if none of those hit.
- Added: `--operator-namespace=NAME`, for anyone running under
  RBAC-segregated access who already knows where their operator lives —
  skips the namespace guesswork above entirely and goes straight there.
- Fixed: on PGD 6.x, the tool went looking for PGD Proxy pods and printed
  "No PGD Proxy pods found," which reads like something might be missing.
  It isn't — PGD Proxy was folded into core PGD routing as of 6.x, so
  there's nothing there to find. The check is now skipped outright on 6.x
  and later, with a short note explaining why instead of a message that
  sounds like a warning. (#2)
- Fixed: several commands (`cluster_definition_full.yaml`,
  `cluster_describe.txt`, `backups_summary.txt`, `operator_clusterrole.txt`,
  and a few others) were discarding their error output on failure, so a
  real problem looked identical to "nothing here." Those files now keep
  the actual error instead, so a genuine failure is visible rather than a
  mysteriously empty file.

## [1.2.0] - 2026-09-23

- Added: a new `edbdiag_version.txt` file at the root of every collected
  bundle (alongside `clusters/`, `operator_info/`, `pgd_group_info/`,
  `pods-logs/`, and `storage/`). It contains the same output as `kubectl
  edbdiag version` (version + the script's own SHA-256), plus the
  collection timestamp (UTC), the operator variant (EDB Postgres® AI for
  CloudNativePG™ / CloudNativePG™ / EDB Postgres® AI for CloudNativePG™
  Global Cluster), and
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
- Fixed: the fallback status report's "Certificate expirations" section
  was always blank. kubectl's jsonpath dialect does not support the
  two-variable `range $k, $v := <map>` syntax used to print it — confirmed
  directly: `error: error parsing jsonpath ... unrecognized character in
  action: U+002C ','`. That error was, again, being silently swallowed.
  Certificate names/expiry dates are now read from the same field's plain
  JSON rendering instead.

## [1.1.1] - 2026-09-21

- Fixed: `backups_summary.txt` (`cluster_info/`) was always an empty file.
  It came from `kubectl cnp`/`kubectl cnpg get backups <cluster>`, which is
  not a real subcommand of either plugin — confirmed directly against a
  live cluster: `Error: unknown command "get" for "kubectl cnp"`. The
  error was being silently swallowed by `2>/dev/null || true`, so this had
  been broken since the line was first written, not a regression. Now
  built from the `Backup` CRs directly (`kubectl get backup -o
  custom-columns=...`), which needs no plugin and works identically on
  EDB Postgres® AI for CloudNativePG™, CloudNativePG™, and EDB Postgres®
  AI for CloudNativePG™ Global Cluster. Noticed because the file was
  empty even though completed backups were listed in `backups.yaml`.
- Fixed: `backups.yaml` collected every `Backup` in the namespace
  unfiltered, mixing different clusters' backups together whenever more
  than one cluster shares a namespace. Both `backups.yaml` and
  `backups_summary.txt` are now scoped to the current cluster via the
  label the operator itself sets on the `Backup` CR (`cnpg.io/cluster` on
  community CloudNativePG™, `k8s.enterprisedb.io/cluster` on EDB
  Postgres® AI for CloudNativePG™ / EDB Postgres® AI for CloudNativePG™
  Global Cluster).

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
- Added: EDB Postgres® AI for CloudNativePG™ Global Cluster per-pod collection now dumps the entire `bdr` schema catalog
  (every table + view, ~127 files on PGD 5.9.4 / ~128 on 6.x) into a new
  `postgresql/bdr_catalog/` folder, instead of only the curated subset of
  `bdr.*` views collected by hand before. This is schema-discovery at
  runtime rather than a hand-maintained list, so it automatically adapts to
  whatever PGD version is installed and keeps pace with future PGD releases
  without going stale. Brings collection breadth in line with EDB's
  internal "Lasso" diagnostic tool.
- Changed: the EDB Postgres® AI for CloudNativePG™ Global Cluster
  scope-selection prompt now uses numbered options (`1`/`2`/`3`/`q`)
  instead of letters (`a`/`n`/`m`/`q`), matching the numbered style
  already used by the EDB Postgres® AI for CloudNativePG™/CloudNativePG™
  scope menu and the top-level variant-selection menu.

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
