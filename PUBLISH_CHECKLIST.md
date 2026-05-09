# Publish checklist (community-skills v0.1.0 → 2026-05-06)

Internal note. Track manual steps that cannot be automated from this session.

## GitHub

- [x] `gh repo create pcbrom/community-skills --public` (done)
- [x] Initial commit pushed to `main` (done)
- [ ] **`.github/workflows/ci.yml` is NOT yet pushed**: current `gh` CLI token lacks the `workflow` scope. Two options to land it:
  - From a terminal with interactive TTY: `gh auth refresh -h github.com -s workflow`, then `git add .github/workflows/ci.yml && git commit -m "ci: workflow" && git push`.
  - Or paste the YAML manually via GitHub web UI (Actions tab → "set up a workflow yourself").
- [ ] Tag and release v0.1.0 (run after the workflow lands so the first release shows green CI):
  ```bash
  git tag -a v0.1.0 -m "v0.1.0: bridge R + bgumbel skill"
  git push origin v0.1.0
  gh release create v0.1.0 --title "v0.1.0: bridge R + bgumbel" --notes-from-tag --latest
  ```

## Zenodo

- [ ] Connect the repo to Zenodo (https://zenodo.org/account/settings/github/): toggle ON for `pcbrom/community-skills`.
- [ ] Trigger a fresh release (the v0.1.0 above suffices) so Zenodo deposits the snapshot.
- [ ] Copy the assigned DOI back into:
  - `CHANGELOG.md` (replace `TBD`)
  - `README.md` badge (`zenodo.0000000` → real DOI)
  - `docs/citation.md` (`<DOI assigned at first release>`)
  - `linkedin_master/livro/REFERENCIAS.md` (community-skills entry)
- [ ] `.zenodo.json` is already present so the metadata is auto-populated.

## LinkedIn (manual publishing on 2026-05-06 09:00 BRT)

The full set of artifacts will live in `linkedin_master/`:

- [ ] Schedule the LinkedIn Pulse article (EN) for 2026-05-06 09:00 BRT.
- [ ] Schedule the short LinkedIn post (EN) co-publish via "Share article" flow.
- [ ] Auto-comment on the post: link to Convergência Digital / community-skills DOI / 5 hashtags.
- [ ] Tag co-authors of the bgumbel paper + UnB-cluster citing authors per `linkedin_master/registry/STAT-001_authors.json`.
- [ ] Cross-post the PT-BR translation to TabNews with prefix `[IA]`.

## Snapshots after publication

Per the existing GitHub-traffic rule (CLAUDE.md), record on every snapshot:

```bash
gh api repos/pcbrom/bgumbel/traffic/views
gh api repos/pcbrom/bgumbel/traffic/clones
gh api repos/pcbrom/bgumbel/traffic/popular/referrers
gh api repos/pcbrom/community-skills/traffic/views
gh api repos/pcbrom/community-skills/traffic/clones
gh api repos/pcbrom/community-skills/traffic/popular/referrers
```

Plus the LinkedIn `PostAnalytics_*.xlsx` exports at +24h / +96h / +168h.

---

# v0.2.0 release checklist (cran-graph + curated CRAN skills, Phase 1-3 of the sprint)

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
