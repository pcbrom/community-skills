# Curated CRAN-skill generation pipeline

This pipeline turns a list of top-downloaded CRAN packages into agent-callable
SKILL.md files with bounded human review at the gate. It is the implementation
of Phase 3 of the cran-graph sprint.

## Stages

```
cranlogs (top-N)
   |
   v
triage_top_cran.py  --snapshot data/cran_snapshot_<DATE>.sqlite
   |  cross-reference status, version, license; drop deprecated and covered
   v
data/top_cran_curated.json
   |
   v
generate_skills_via_gemma.py  --triage data/top_cran_curated.json
   |  fetch tarball -> parse DESCRIPTION + NAMESPACE + Rd
   |  build prompt with editorial contract pinned
   |  call Ollama (gemma4:26b-fast, temperature 0.2)
   |  validate front matter, required sections, em-dash, forbidden terms
   v
skills/_staging/<package>/{SKILL.md, _meta.json}
   |
   v
[human review]
   |
   v
skills/<package>/  (promotion: copy SKILL.md, hand-write invoke.R, add tests)
```

Each stage is a standalone script under `scripts/` so the human reviewer can
re-run the last stage without rebuilding the snapshot or refetching the
download counts.

## Operator commands

```bash
# 1. Build (or refresh) the CRAN graph snapshot.
cran-graph build --output data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite

# 2. Rank, cross-reference, filter.
python -m scripts.triage_top_cran \
    --snapshot data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite \
    --top 200 \
    --output data/top_cran_curated.json

# 3. Generate the first batch of 10 to staging.
python -m scripts.generate_skills_via_gemma \
    --triage data/top_cran_curated.json \
    --output-dir skills/_staging \
    --log data/skill_generation_log.jsonl \
    --limit 10

# 4. Inspect the staging output.
ls skills/_staging/
cat data/skill_generation_log.jsonl | jq '.'
```

## Editorial contract enforced by `validate_skill_md`

A generated SKILL.md is rejected (and one retry is attempted) when any of
the following holds:

- The file does not begin with a balanced YAML front matter block (`---` ...
  `---`).
- The front matter is missing `runtime: r`, `name: <package>`, or
  `package: <package>`.
- The body is missing `## Functions exposed` or `## When to invoke`.
- The body contains the U+2014 character.
- The body contains any of: crucial, essential, fundamental, revolutionary,
  incredible, important, robust.

The intent is not to prove the file is correct: it is to trip the worst
classes of LLM drift before a human spends time on review.

## Promotion (review-to-skills) checklist

The reviewer copies an approved SKILL.md from `skills/_staging/<pkg>/` into
`skills/<pkg>/` and adds the runtime artifacts:

1. Copy the SKILL.md verbatim.
2. Copy `templates/new_r_skill/invoke.R.template` to `skills/<pkg>/invoke.R`,
   wire each exposed function declared in SKILL.md to the corresponding R call.
3. Copy `templates/new_r_skill/README.md.template` to `skills/<pkg>/README.md`.
4. Add a smoke test under `tests/test_skills/test_<pkg>.py` that exercises one
   hard-coded invocation per exposed function and asserts on shape, not values.
5. Append the new skill to `skills/README.md`.

The bgumbel skill is the canonical worked example. Reading `skills/bgumbel/`
end-to-end is the fastest way to internalize the pattern.

## Generation log schema

Each line in `data/skill_generation_log.jsonl` is one attempt:

| Field                  | When present | Meaning                                      |
| ---------------------- | ------------ | -------------------------------------------- |
| `package`              | always       | package name                                  |
| `version`              | always       | pinned version from triage                    |
| `ok`                   | always       | true on success, false on any failure         |
| `stage`                | always       | `extract`, `ollama_attempt_<n>`, `validation_after_retries`, or `ok` |
| `attempts`             | success only | number of LLM round trips needed              |
| `wall_clock_s`         | always       | seconds from start of this attempt to outcome |
| `n_exports`            | success only | exports parsed from NAMESPACE                 |
| `n_rd_docs`            | success only | Rd files folded into the prompt               |
| `rank`                 | success only | rank position in the triage list              |
| `downloads_last_month` | success only | from cranlogs                                 |
| `issues`               | failure only | list of validator issue tokens                |
| `error`                | failure only | string from the underlying exception          |

Append-only by design: a re-run of the same package adds a fresh line so
the audit trail captures every attempt.

## Why a staging directory

The promotion barrier exists because Gemma 4 26b-fast at temperature 0.2 is
fast and cheap, not perfect. The validator catches the worst drift but not
content correctness: a SKILL.md that names the wrong function signature, or
that hallucinates a citation, will pass the validator. Human review catches
those before the file ships in `skills/`.

The acceptance threshold for the first batch is at least 8 of 10 SKILL.md
files passing review without rewrite. If fewer than 8 pass, the prompt
template is reformulated before scaling to the next batch.
