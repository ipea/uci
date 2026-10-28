# CLAUDE.md — uci

**uci** is an R package that calculates the Urban Centrality Index (UCI) as in
Pereira et al. (2013) <doi:10.1111/gean.12002>. The UCI measures how far the
spatial organisation of a city or region sits between extreme polycentric (0)
and extreme monocentric (1). Published on CRAN; developed at Ipea (GitHub org `ipea`).
Maintainer: Rafael H. M. Pereira. License MIT. Docs:
<https://ipea.github.io/uci/>. Default branch: `main`.

---

## Core principles

- **Correct numbers first.** The package returns one index; a silently wrong
  value is the worst possible bug. Any change to the computation needs a
  before/after comparison of `uci()` output on `grid_bho.rds` (all four
  `dist_type` × `bootstrap_border` combinations, seeded) and an explanation of
  every difference.
- **Never surprise the caller.** `uci()` does not modify the user's `sf`
  object, global options, environment variables or the RNG beyond what it
  restores.
- **CRAN-ready at all times.** `R CMD check --as-cran`: 0 errors, 0 warnings.
- **Plan first.** Enter plan mode before non-trivial tasks. Every plan is
  reviewed by two adversarial agents (Minimalist + Skeptic) that improve it and
  make it simpler, with as little code intervention as possible. Present the
  plan only when both reach consensus (max 3 rounds, then escalate the
  disagreement). Plans live in `quality_reports/plans/`.
- **Verify after.** Every task ends with the gates below, not with "should work".
- **Learn from corrections.** Log `[LEARN:category] wrong → right` in
  `MEMORY.md`.
- **Code style.** Always use the convention `package::function()`. Exception:
  ggplot2 functions in the vignette and README.

Conventions are in [`.claude/rules/r-package-conventions.md`](.claude/rules/r-package-conventions.md);
gates are in [`.claude/rules/quality-gates.md`](.claude/rules/quality-gates.md).

---

## Repository map

```
uci/
├── DESCRIPTION, NAMESPACE        # NAMESPACE is roxygen-generated; never hand-edit
├── R/
│   ├── uci.R                     # the only export: uci()
│   ├── internal_fun.R            # helpers: location_coef, venables_blockwise, self-distance,
│   │                             #   distance matrices / spatial-link graph, normalize_distribution
│   └── uci_package.R             # package doc, importFrom, utils::globalVariables()
├── tests/testthat/test_uci.R     # single test file (tester() wrapper)
├── tests/tests_rafa/             # maintainer scratch scripts; not part of the suite
├── inst/extdata/grid_bho.rds     # fixture: hexagonal grid of Belo Horizonte, column `jobs`
├── inst/CITATION, REFERENCES.bib
├── vignettes/uci.Rmd
├── README.md                     # hand-written (no README.Rmd)
├── NEWS.md                       # user-facing changelog
├── _pkgdown.yml                  # pkgdown site (docs/ is generated)
└── .github/workflows/            # rcmdcheck, test-coverage, pkgdown
```

How `uci()` works (`R/uci.R`):
1. Validate inputs; reproject to EPSG:3857; replace `NA` in `var_name` with 0.
2. **Location coefficient** `LC` = ½ Σ|xᵢ − 1/n| on the normalised distribution.
3. **Observed Venables spatial separation** `V = bᵀ D b`, with `D` the
   Euclidean (centroids, `fields::rdist`) or spatial-link (queen contiguity,
   `spdep` + `cppRouting` shortest paths) distance matrix, plus a self-distance
   `sqrt(area/π)` on the diagonal (Crafts & Mulatu 2006). `D` is built in row
   blocks (`venables_blockwise()`), never as a full n × n matrix.
4. **Max Venables** from activities spread along the border cells: one
   heuristic configuration (`bootstrap_border = FALSE`, `mean(D_border)`) or
   400 × 50 random border configurations (`TRUE`, `mean(D_border[u, u])` each).
   `parallel` sets the spatial-link shortest-path threads (FALSE = 1 thread).
5. `UCI = LC × (1 − V / V_max)`; returns a one-row `data.frame`
   (`UCI`, `location_coef`, `spatial_separation`, `spatial_separation_max`).

Local-only workflow files (gitignored and Rbuildignored): `MEMORY.md`,
`quality_reports/`, `templates/`, and everything in `.claude/` except `rules/`.

---

## Commands

```r
devtools::load_all()
devtools::document()                         # regenerate man/ + NAMESPACE
devtools::test()                             # full suite (slow: bootstrap + parallel)
devtools::check(args = "--as-cran")          # long; run in background
lintr::lint("R/<file>.R")                    # no .lintr yet: lintr defaults
pkgdown::build_site()
covr::package_coverage()
```

- Run R through the **PowerShell** tool or from script files: `>` and `|`
  inside `Rscript -e '...'` are mangled by the shell (see `MEMORY.md`).
- `bootstrap_border = TRUE` evaluates 20,000 border configurations (cheap
  submatrix means); `parallel = TRUE` lets cppRouting use all cores for
  spatial-link distances, so keep it out of CRAN tests and examples.

---

## Quality gates (summary)

| Checkpoint | Must hold |
|---|---|
| Commit | `document()` produces no content drift (`git diff`); `devtools::test()` passes; `lintr` clean on changed lines; numeric before/after recorded if the computation changed; `NEWS.md` entry for user-facing changes |
| Push / PR | `check(--as-cran)` gives 0 errors / 0 warnings, NOTEs triaged; review loop converged; `r-package-reviewer` 0 CRITICAL/MAJOR |
| Release | `/uci-package-check`; win-builder + R-hub; `cran-comments.md` updated |

Details: `.claude/rules/quality-gates.md`.

---

## Skills and agents

These are local to the maintainer's Claude setup and are not in git. In a fresh
clone, follow the rules in `.claude/rules/` directly.

Project skills carry a `uci-` prefix so user-level skills with the same base
name can't shadow them. **In this repo, always use the `uci-` version**
(`/uci-commit`, not a generic `/commit`). Where user-level rules conflict with
`.claude/rules/`, the project rules win.

- `/uci-package-check`: document, test, check `--as-cran`, triage, reviewer
  report.
- `/uci-commit`: Gate 1, then commit. Push only when asked, after Gate 2.
- `/uci-diagnose`: root-cause a failing test or a wrong UCI value.
- `/uci-deep-audit`: repo-wide consistency audit (docs ↔ code ↔ NEWS ↔ DESCRIPTION).
- `/uci-checkpoint`, `/uci-compress-session`, `/context-status`: session state.
- `/uci-learn`: turn a session discovery into a reusable skill.
- Agent `r-package-reviewer`: read-only CRAN, convention and numerical review
  of package source.

---

## Working mode

1. **Plan:** for non-trivial tasks, enter plan mode, explore, ask only about
   real decisions, pass the adversarial plan review, and get approval.
2. **Execute (contractor mode):** after approval, work autonomously through
   implement → verify → parallel review → fix, looping until reviews come
   back dry (see `.claude/rules/orchestrator-protocol.md`). Come back only for
   ambiguity or a decision that belongs to the user.
3. **Report:** summarise what changed, gate results, open questions; log the
   session.

No commits, pushes, PRs, version bumps or `.github/workflows/` changes without
an explicit request. Never hand-edit generated files (`NAMESPACE`, `man/*.Rd`,
`docs/`).
