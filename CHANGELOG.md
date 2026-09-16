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
1.0.1.

## [1.0.1] - 2026-09-16

- Fixed: PGD Proxy pod discovery (`pgd_group_info/proxy_pods/`) used a
  `-proxy-` name/substring match, which also matched Kubernetes' own
  built-in `kube-proxy-<hash>` pods (kube-system, present on every cluster
  regardless of PGD) — noise from a component completely unrelated to PGD.
  Now uses the PGD Proxy StatefulSet's actual operator-set label
  (`k8s.pgd.enterprisedb.io/workloadType=pgd-proxy`), which only ever
  matches genuine PGD Proxy pods. Reported by Alexey Shishkin. Recommended
  for all PGD4K users.

## [1.0.0] - 2026-09-16

- Initial versioned release. Added `kubectl edbdiag version` (also `-v` /
  `--version`), which prints the script's own SHA-256 so you can confirm
  your installed copy is byte-for-byte current with `main`. Unlike the
  compiled `kubectl cnp`/`kubectl cnpg` plugins, this is a plain shell
  script with no build step to stamp a commit hash into automatically —
  the SHA-256 is the equivalent check.
