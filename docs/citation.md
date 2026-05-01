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
  title        = {community-skills: A community hub for wrapping packages as agent-callable skills},
  version      = {0.1.0},
  date         = {2026-05-13},
  publisher    = {Zenodo},
  doi          = {<DOI assigned at first release>},
  url          = {https://github.com/pcbrom/community-skills}
}
```

### APA

> Brom, P. C., & contributors. (2026). *community-skills: A community hub for wrapping packages as agent-callable skills* (Version 0.1.0) [Computer software]. Zenodo. https://doi.org/<DOI>

## Citing a specific skill

Each skill in `skills/<name>/CITATION.md` documents how to credit the
upstream package. Cite **both** the upstream work and the
community-skills release you used. Example for bgumbel:

```bibtex
@article{otiniano2023bgumbel,
  author  = {Otiniano, Cira E. G. and Vila, Roberto and Brom, Pedro Carvalho and Pereira, Marcelo B.},
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
