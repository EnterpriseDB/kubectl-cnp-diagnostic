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
1.1.0.

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
  matches genuine PGD Proxy pods. Reported by Alexey Shishkin.
- Added: PGD4K per-pod collection now dumps the entire `bdr` schema catalog
  (every table + view, ~127 files on PGD 5.9.4 / ~128 on 6.x) into a new
  `postgresql/bdr_catalog/` folder, instead of only the curated subset of
  `bdr.*` views collected by hand before. This is schema-discovery at
  runtime rather than a hand-maintained list, so it automatically adapts to
  whatever PGD version is installed and keeps pace with future PGD releases
  without going stale. Brings collection breadth in line with EDB's
  internal "Lasso" diagnostic tool. Suggested by Alexey Shishkin.
- Changed: PGD4K's scope-selection prompt now uses numbered options
  (`1`/`2`/`3`/`q`) instead of letters (`a`/`n`/`m`/`q`), matching the
  numbered style already used by the CNP/CNPG scope menu and the top-level
  variant-selection menu. Suggested by Alexey Shishkin.

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
