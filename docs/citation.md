# Citation

community-skills is published on Zenodo with a DOI assigned per release.
The version-evolving DOI lets papers cite the exact code that was run.

## Citing the hub

The machine-readable form lives at the repo root in [`CITATION.cff`](../CITATION.cff).
GitHub renders it under "Cite this repository" on the project page.

### BibTeX

```bibtex
@software{brom2026community_skills,
  author       = {Brom, Pedro Carvalho and contributors},
  title        = {community-skills: An R-focused hub of agent-callable skills for the CRAN ecosystem},
  version      = {0.2.0},
  date         = {2026-06-04},
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.20543565},
  url          = {https://doi.org/10.5281/zenodo.20543565}
}
```

The concept DOI (resolves to the latest version): `10.5281/zenodo.20543564`.

### APA

> Brom, P. C., & contributors. (2026). *community-skills: An R-focused hub of agent-callable skills for the CRAN ecosystem* (Version 0.2.0) [Computer software]. Zenodo. https://doi.org/<DOI>

## Citing a specific skill

Each skill in `skills/<name>/CITATION.md` documents how to credit the
upstream package. Cite **both** the upstream work and the
community-skills release you used. Example for bgumbel:

```bibtex
@article{otiniano2023bgumbel,
  author  = {Otiniano, Cira E. G. and Vila, Roberto and Brom, Pedro Carvalho and Bourguignon, Marcelo},
  title   = {On the Bimodal Gumbel Model with Application to Environmental Data},
  journal = {Austrian Journal of Statistics},
  year    = {2023},
  volume  = {52},
  pages   = {45--65},
  doi     = {10.17713/ajs.v52i2.1392}
}
```

## Citing a specific call

For reproducibility in agentic workflows, log:

- The community-skills version (e.g. `v0.1.0`).
- The skill name (e.g. `bgumbel`).
- The upstream package version observed at runtime (R: `packageVersion("bgumbel")`).
- The exact JSON payload sent and the JSON response received.

This is enough information for another team to replay the call.
