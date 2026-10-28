---
paths:
  - "R/**"
  - "tests/**"
  - "vignettes/**"
  - "inst/**"
  - "README.md"
  - "DESCRIPTION"
  - "NEWS.md"
  - "_pkgdown.yml"
---

# Quality gates (uci)

Gates are **pass/fail checks**, not scores. A task is "done" only when the gate
for its checkpoint passes and the output has actually been seen; "should work"
doesn't count.

## Gate 1: Task done / commit

All must hold for the files touched:

| Check | Command | Pass |
|---|---|---|
| Docs regenerated | `devtools::document()` then `git diff --stat man/ NAMESPACE` | No unexpected content drift (use `git diff`, not `git status`: `core.autocrlf` may rewrite line endings only); intended changes staged with the source |
| Tests | `devtools::test()` (one test file; the whole suite is the targeted run) | 0 failures, 0 errors, 0 new warnings |
| Lint | `lintr::lint("R/<file>.R")` per changed file | No new lints on changed lines (the existing code is not lint-clean; don't fix untouched lines) |
| Numeric before/after | if `R/uci.R` or `R/internal_fun.R` computation changed: run `uci()` on `grid_bho.rds` for `dist_type` ∈ {euclidean, spatial_link} × `bootstrap_border` ∈ {FALSE, TRUE} (`set.seed(42)`) on old and new code | Identical, or every difference explained and approved; table recorded in the plan or session log |
| NEWS | user-facing change | Bullet under `# uci (development version)` |
| pkgdown | if an `@export` was added or removed: `pkgdown::check_pkgdown()` | No missing topics |
| Staging hygiene | `git diff --cached --name-only` | No `.RData`/`.Rhistory`; no new `.rds` outside `inst/extdata/`; no workflow files except `CLAUDE.md` and `.claude/rules/` |
| Conventions | `.claude/rules/r-package-conventions.md` checklist | All items hold |

## Gate 2: Push / pull request

Gate 1, plus:

| Check | Command | Pass |
|---|---|---|
| CRAN check | `devtools::check(args = "--as-cran")` (background; several minutes) | 0 errors, 0 warnings; each NOTE triaged (pre-existing vs new); example/test timing NOTEs taken seriously |
| Review loop | parallel review lenses (`orchestrator-protocol.md`) | Converged: 0 open CRITICAL/MAJOR |
| Package review | `r-package-reviewer` agent on changed files | 0 CRITICAL/MAJOR |
| Performance | if the change claims or risks a speed change | `bench::mark` evidence recorded |

## Gate 3: Release (maintainer-driven)

Gate 2, plus `/uci-package-check` (full report), `devtools::check_win_devel()`
and/or R-hub, a reverse-dependency check if CRAN lists any, `cran-comments.md`
updated, `urlchecker::url_check()`. Claude prepares; the maintainer bumps the
version and submits.

## Overrides

A gate may be skipped only on an explicit user instruction ("commit anyway"),
and the reason is recorded in the commit body and the session log. Never use
`git commit --no-verify`.

## Pre-existing failures

If a gate fails for reasons unrelated to the change, don't fix it as a drive-by.
Report it and add it to the backlog
(`quality_reports/specs/2026-10-27_package-backlog.md` or a newer one).
