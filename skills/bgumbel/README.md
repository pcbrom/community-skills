# bgumbel skill

Wraps the [bgumbel](https://github.com/pcbrom/bgumbel) R package, available on CRAN since 2021-03-31 with roughly 48,000 cumulative downloads and ten papers citing the underlying [Austrian Journal of Statistics article](https://doi.org/10.17713/ajs.v52i2.1392).

The bimodal Gumbel distribution models real-valued phenomena that exhibit two extreme regimes (for example, seasonal temperature peaks, dual-mode flood/drought records, two-failure-mode reliability, and bull/bear financial returns). Compared with a free five-parameter mixture of two Gumbel distributions, the bimodal Gumbel achieves bimodality with three parameters (`mu`, `sigma`, `delta`) while remaining identifiable.

The skill goes beyond a thin wrap of the package: it adds an `init_theta` function that returns a robust starting triple for the MLE, and `mlebgumbel` automatically falls back to that seed if the user-supplied initial values cause the optimizer to diverge. This is the most common pain point when fitting the model by hand, and the skill handles it transparently.

## Prerequisites

- R available on `PATH` (`Rscript --version`).
- The package installed: `install.packages("bgumbel")`.
- For the Python wrapper: install community-skills with `pip install -e .` from the repo root.

## Usage from a shell

```bash
echo '{"fn":"dbgumbel","x":[-1.0,0.0,1.0],"mu":0.0,"sigma":1.0,"delta":0.5}' \
  | Rscript --vanilla skills/bgumbel/invoke.R
```

Expected output:

```json
{"ok":true,"fn":"dbgumbel","result":[0.304,0.384,0.166]}
```

## Usage from Python

```python
from bridges import invoke

result = invoke("bgumbel", {
    "fn": "dbgumbel",
    "x": [-1.0, 0.0, 1.0],
    "mu": 0.0, "sigma": 1.0, "delta": 0.5,
})
# {"ok": True, "fn": "dbgumbel", "result": [...]}
```

Or via the typed wrapper:

```python
from skills.bgumbel.invoke import rbgumbel, init_theta, mlebgumbel

# Sample from a bimodal Gumbel
sample = rbgumbel(n=500, mu=0.0, sigma=1.0, delta=0.5, seed=42)["result"]

# Inspect the heuristic seed before fitting
print(init_theta(sample)["result"])

# Recover parameters from the sample (auto-init by default)
fit = mlebgumbel(sample)
print(fit["result"]["estimate"], "init:", fit["result"]["init_strategy"])
```

## Usage from inside an agent (Claude Code, Codex, OpenCode)

Most agents can run a subprocess and parse JSON. The simplest invocation is:

```
Run the following:
echo '{"fn":"mlebgumbel","data":[<your data>]}' | Rscript --vanilla skills/bgumbel/invoke.R
```

The agent receives a JSON object with `ok`, `fn`, and `result` (or `error` on failure) and can act on it directly. The `init_strategy` field in the response tells the agent whether the user-supplied seed worked, the auto-init was used, or a fallback was triggered.

## Functions

See [SKILL.md](SKILL.md) for the full machine-readable contract. Quick reference:

| Function | Purpose |
|---|---|
| `dbgumbel` | Probability density. |
| `pbgumbel` | Cumulative distribution. |
| `qbgumbel` | Quantile (inverse CDF). |
| `rbgumbel` | Pseudo-random samples. |
| `m1bgumbel` | First moment $E[X]$. |
| `m2bgumbel` | Second moment $E[X^2]$. |
| `init_theta` | Robust starting values for the MLE (median + MAD + delta=0.1). |
| `mlebgumbel` | Maximum-likelihood fit with auto-init and fallback. |

## Citation

See [CITATION.md](CITATION.md). When citing in academic work, please cite both the canonical paper (Otiniano et al., 2023) and the community-skills release you used.
