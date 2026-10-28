---
paths:
  - "R/**/*.R"
  - "tests/**/*.R"
  - "man/**"
  - "vignettes/**"
  - "inst/**"
  - "README.md"
  - "DESCRIPTION"
  - "NAMESPACE"
  - "NEWS.md"
  - "_pkgdown.yml"
---

# uci package conventions

**Standard:** a CRAN-ready package whose single number is right.
`R CMD check --as-cran` returns 0 errors, 0 warnings, and only explained notes.
New code reads like the code around it.

Part A describes how uci is written today (verified against v0.3.0). Items
tagged **[NEW]** are decisions for new or modified code only; never apply them
to untouched code as drive-bys. Part B is the general CRAN standard. When they
conflict, Part A wins; flag the conflict in the plan.

---

# Part A: uci house style

## A1. Namespacing

- **Always call `package::function()`**: `sf::`, `checkmate::`,
  `data.table::`, `spdep::`, `cppRouting::`, `fields::`, `pbapply::`,
  `future::`, `furrr::`, `utils::`.
- `@importFrom` is used only for `utils globalVariables` and `stats dist`
  (`R/uci_package.R`). Don't add more without a plan.
- Never use `library()`/`require()` in `R/`. Suggested packages (ggplot2 in the
  vignette) are guarded with `requireNamespace("pkg", quietly = TRUE)`.
- NSE column names go into `utils::globalVariables(c(...))` in
  `R/uci_package.R`; check for duplicates first.

## A2. The `uci()` contract

- **Single export.** Signature: `uci(sf_object, var_name, dist_type =
  "euclidean", bootstrap_border = FALSE, showProgress = TRUE, parallel =
  FALSE)`. Argument names and order are public API: renaming or reordering
  needs a deprecation cycle and the maintainer's decision. (`showProgress` is
  camelCase for consistency with Ipea's other packages — don't "fix" it.)
- **Inputs:** validated up front with `checkmate::assert_*` and the internal
  `assert_var_name()`. New enumerated options: `checkmate::assert_choice()`
  for a single value.
- **Output:** a one-row `data.frame` with columns `UCI`, `location_coef`,
  `spatial_separation`, `spatial_separation_max`. Adding columns is a
  user-facing change (NEWS); removing or renaming one is breaking.
- **`NA` in `var_name` means 0** (documented in `@param var_name`).
- **Global state:** every change to `pbapply::pboptions()` and
  `future::plan()` is restored with `on.exit(..., add = TRUE)`. The
  `pboptions` restore is the first `on.exit()` (no `add`); the
  `future::plan()` restore comes later with `add = TRUE`. Any new `on.exit()`
  uses `add = TRUE` and must not precede the first one.
- **Users may set their own `future::plan()`** before calling with
  `parallel = FALSE`; never override a user plan silently.

## A3. Numerical discipline (the core of this package)

- The index formula is `UCI = LC × (1 − V / V_max)` (Pereira et al. 2013).
  Changing any of `location_coef()`, `venables()`, the distance matrices, the
  self-distance term `sqrt(area / π)`, the border detection or the V_max
  search changes published numbers → maintainer decision, NEWS entry under a
  breaking/major heading, and the Gate 1 before/after table.
- Distances and areas must be in the same units (see the comment in
  `get_euclidean_dist_matrix()`). Any CRS change must keep this true; strip
  `units` explicitly (`as.numeric()`) only where intended.
- The bootstrap uses `sample()`: tests and comparisons set a seed. Parallel
  runs via `furrr` need `furrr::furrr_options(seed = TRUE)` for
  reproducibility if randomness ever moves into the parallel step [NEW].
- Compare doubles with `testthat::expect_equal()` (tolerance), never `==`.
- Distance matrices are dense n × n; anything that builds them more than once
  per call is a performance bug.

## A4. Messages and errors

- **Today:** base `stop()` and `message()`.
- **[NEW]** New or modified messages use `cli::cli_abort()`,
  `cli::cli_warn()`, `cli::cli_inform()` — but `cli` is **not** in Imports
  yet, so adopting it is itself a plan (new dependency). Until then, new code
  uses `stop(..., call. = FALSE)` and matches the existing wording style.
- **[NEW]** Informational messages are gated on `showProgress` (or a future
  `quiet`), never unconditional.

## A5. Style

- 2-space indent, `<-`, snake_case for new internals, explicit `return()` at
  the end of functions. Lines ≤ 80 columns in new code.
- The existing code has mixed spacing (`( x )`, `if(`) and commented-out
  `plot()` calls; match the surrounding file, don't reformat untouched code.
- Comments are lowercase prose explaining *why*, with references
  (e.g. "REF Crafts & Mulatu (2006)") where a formula comes from a paper.
- No `.lintr` yet: `lintr` defaults apply to new/changed lines only.

## A6. Documentation (roxygen2, markdown)

- `uci()` has `@family urban centrality index`; keep it if more exports appear.
- Internal helpers use `#' @keywords internal` (`R/internal_fun.R`).
- Examples load the fixture:
  ```r
  data_dir <- system.file("extdata", package = "uci")
  grid <- readRDS(file.path(data_dir, "grid_bho.rds"))
  ```
  Slow examples (bootstrap, parallel) go in `\donttest{}` [NEW].
- Cite the paper with `\doi{10.1111/gean.12002}`.
- `README.md` is hand-written (no `README.Rmd`); keep its example in sync with
  `uci()`'s signature and output columns.
- Never hand-edit generated files: `NAMESPACE`, `man/*.Rd` (`document()`),
  `docs/` (`pkgdown::build_site()`).

## A7. Tests (testthat)

- One file today: `tests/testthat/test_uci.R`, with a `tester()` wrapper whose
  defaults mirror `uci()`'s, and blocks headed `# Expected behavior` and
  `# ERRORS and messages`. New tests for `uci()` go there; a new internal with
  non-trivial math may get its own `test_<name>.R`.
- **New or modified behaviour needs at least:**
  - an input-type error test
  - an output class/columns test
  - a **numeric** test: a value checked with `expect_equal(tolerance =)`
    against a known case (e.g. all activity in one cell → LC near 1; uniform
    activity → LC = 0), or a regression value on `grid_bho` with a seed
  - "doesn't change the input": `grid2 <- grid; uci(grid2, ...);
    expect_identical(grid, grid2)`
- Slow paths (`parallel = TRUE`, `bootstrap_border = TRUE`) get
  `testthat::skip_on_cran()` in new tests [NEW].
- Restore global state with `on.exit()`; `withr` is not a dependency.

## A8. NEWS.md

Entries go under `# uci (development version)` (create it after a release).
Existing style: `* Major changes` / `* Minor changes` bullets with nested
items; keep that style.

```
# uci (development version)

* Major changes
  * `uci()` now ... (#issue).
* Minor changes
  * Fixed ... (#issue).
```

## A9. Figures (vignette, README, pkgdown)

- ggplot2 is in Suggests; vignette chunks that use it are gated.
- **[NEW]** New or modified figures: one consistent theme, a colour-blind-safe
  palette (viridis), labelled legends, fixed `fig.width`/`fig.height`/`dpi`.

---

# Part B: general CRAN standard

- **DESCRIPTION:** `Imports` for code in `R/`, `Suggests` for
  tests/vignettes/optional paths, `Depends` only for the R version.
- **Docs:** every export documents all `@param`s, `@return`, and runnable
  `@examples`. `\donttest{}` for slow-but-correct examples; never `\dontrun{}`
  to hide errors.
- **CPU:** CRAN machines allow at most 2 cores. Never use more than 2 cores in
  examples, tests or vignettes (`parallel = TRUE` uses `availableCores() - 1`).
- **Red flags:**

| Red flag | Do instead |
|---|---|
| `library()`/`require()` in `R/` | `pkg::fun()` |
| Writing outside `tempdir()` | Write only to `tempdir()` or user-supplied paths |
| `<<-` to global env | Return values |
| `print()`/`cat()` in functions | `message()` gated on `showProgress` |
| options / plan / RNG changed, not restored | `on.exit(..., add = TRUE)` |
| `T`/`F` | `TRUE`/`FALSE` |
| `==` on doubles | `all.equal()` / tolerance |
| Growing vectors in loops | Pre-allocate or vectorise |

- **Versioning:** dev versions use `x.y.z.9000`. The maintainer bumps release
  versions; Claude never does.

## Checklist (new or modified code)

```
[ ] pkg::fun() everywhere
[ ] checkmate validation; output data.frame columns unchanged (or NEWS)
[ ] input sf_object not modified; test proves it
[ ] global state (pboptions, future plan, RNG) restored with on.exit(add = TRUE)
[ ] numeric before/after on grid_bho for all 4 dist_type × bootstrap combos (if math touched)
[ ] numeric test with a known value, not only class checks
[ ] slow tests/examples: skip_on_cran() / \donttest{}; ≤ 2 cores
[ ] style matches file; return(); lintr clean on changed lines
[ ] roxygen complete; devtools::document() run; no hand-edited generated files
[ ] NEWS.md bullet for user-facing changes
[ ] perf claims backed by bench::mark with equal results
```

## Cross-references

- [`quality-gates.md`](quality-gates.md): when each check must pass.
- `.claude/agents/r-package-reviewer.md` enforces this rule. It is local to the
  maintainer's setup and may be absent in a fresh clone; if so, apply the
  checklist manually.
