# Changelog

All notable changes to this project are documented in this file. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release receives a Zenodo DOI. The DOI is added to the entry below once the deposit completes.

## [0.1.0] - 2026-05-06

Initial public release.

### Added
- `bridges/r.py`: subprocess + Rscript + JSON bridge for R packages.
- `bridges/__init__.py`: auto-router that dispatches a skill invocation to the bridge declared by the skill's `runtime` field.
- `bridges/python.py` and `bridges/julia.py`: placeholders raising `NotImplementedError`; community contributions invited.
- `skills/bgumbel/`: first canonical skill (R runtime) wrapping the [bgumbel](https://github.com/pcbrom/bgumbel) CRAN package, exposing `dbgumbel`, `pbgumbel`, `qbgumbel`, `rbgumbel`, `m1bgumbel`, `m2bgumbel`, and `mlebgumbel`.
- `templates/new_r_skill/`: copy-paste scaffold for new R skills.
- `docs/pattern.md`, `docs/architecture.md`, `docs/citation.md`, `docs/adding_r_skill.md`: design rationale and contribution guides.
- `CONTRIBUTING.md`, `CITATION.cff`, `.zenodo.json`, `pyproject.toml`, `LICENSE` (MIT).
- `tests/`: unit test for the R bridge and a smoke test for the bgumbel skill.
- `.github/workflows/ci.yml`: GitHub Actions matrix that installs R, the `bgumbel` package, and runs `pytest`.

### Zenodo DOI
- TBD (added after first release deposit).

### References
- Otiniano, C. E. G.; Vila, R.; Brom, P. C.; Bourguignon, M. (2023). *On the Bimodal Gumbel Model with Application to Environmental Data*. Austrian Journal of Statistics, **52**, 45-65. [DOI 10.17713/ajs.v52i2.1392](https://doi.org/10.17713/ajs.v52i2.1392).
