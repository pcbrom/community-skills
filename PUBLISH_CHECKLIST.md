# Publish checklist

Internal note. Tracks manual steps that cannot be automated from this session. Post-LinkedIn artefacts and outreach scheduling live in the `linkedin_master` project, not here.

---

## v0.1.0 (2026-05-06): historical, retained for audit trail

- [x] `gh repo create pcbrom/community-skills --public`.
- [x] Initial commit pushed to `main`.
- [ ] `.github/workflows/ci.yml` push (still pending: the `gh` CLI token in use at v0.1.0 lacked the `workflow` scope). Two ways to land it:
  - From a terminal with interactive TTY: `gh auth refresh -h github.com -s workflow`, then `git add .github/workflows/ci.yml && git commit -m "ci: workflow" && git push`.
  - Or paste the YAML manually via GitHub web UI (Actions tab, "set up a workflow yourself").
- [ ] Tag and release v0.1.0:
  ```bash
  git tag -a v0.1.0 -m "v0.1.0: bridge R + bgumbel skill"
  git push origin v0.1.0
  gh release create v0.1.0 --title "v0.1.0: bridge R + bgumbel" --notes-from-tag --latest
  ```
- [ ] Zenodo: connect the repo (https://zenodo.org/account/settings/github/); trigger a release; copy the DOI back into `CHANGELOG.md`, the README badge, `docs/citation.md`.

---

# v0.2.0 release checklist (cran-graph + cran-publisher + cran-workflow + curated CRAN skills)

This section covers only the technical release of the hub itself: tag, GitHub release, Zenodo deposit, badge updates. Post-LinkedIn artefacts and outreach scheduling do not live in this repository; those belong to the `linkedin_master` project and are coordinated from there.

## Repo prep (before tag)

- [ ] Promote the `## [Unreleased]` block in `CHANGELOG.md` to `## [0.2.0] - <date>` once the author approves the cut.
- [ ] `gh repo edit` description updated to mention `cran_graph` and LLM-callable skills.
- [ ] README and `skills/README.md` sanity check by the author (both updated in this session).
- [ ] `cran-graph optimize` smoke run on at least three real targets in a clean environment; output captured under `data/release_smoke/v0.2.0/`.

## Tag and Zenodo deposit

- [ ] `git tag -a v0.2.0 -m "v0.2.0: cran_graph + curated CRAN skills (Phase 1-3 of cran-graph sprint)"`.
- [ ] `git push origin v0.2.0`.
- [ ] `gh release create v0.2.0 --title "v0.2.0: cran_graph + curated CRAN skills" --notes-from-tag --latest`.
- [ ] Confirm the Zenodo webhook produced a fresh DOI; copy the DOI back into `CHANGELOG.md`, the README badge, `docs/citation.md`, and `linkedin_master/livro/REFERENCIAS.md` (the cross-reference itself lives in `linkedin_master`, but the DOI is the canonical anchor).
