---
name: bgumbel
runtime: r
package: bgumbel
package_source: CRAN
package_url: https://github.com/pcbrom/bgumbel
package_version_pinned: ">=0.0.3"
license: MIT
maintainer: "Pedro Carvalho Brom <pcbrom@gmail.com>"
---

# Skill: bgumbel

Wraps the `bgumbel` R package, which implements a three-parameter bimodal
Gumbel distribution for environmental and reliability data with two extreme
regimes (e.g. seasonal temperature peaks, dual-mode flood-and-drought records,
two-failure-mode reliability, bull/bear financial returns).

The wrapped package is documented in:

> Otiniano, C. E. G.; Gabriel, R. V.; Brom, P. C.; Pereira, M. B. (2023).
> *On the Bimodal Gumbel Model with Application to Environmental Data*.
> Austrian Journal of Statistics, **52**, 45-65.
> DOI [10.17713/ajs.v52i2.1392](https://doi.org/10.17713/ajs.v52i2.1392).

The model has three real-valued parameters: `mu` (location), `sigma > 0`
(scale), and `delta` (the bimodality/asymmetry parameter). With `delta = 0`
the distribution reduces to a classical Gumbel; nonzero `delta` introduces
bimodality with parsimony (three parameters versus the five of a free
two-component Gumbel mixture, while remaining identifiable).

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("bgumbel")`.

## Functions exposed

The dispatcher selects on the `fn` field of the JSON payload.

### `dbgumbel` — density

Evaluate the bimodal Gumbel probability density at one or more points.

**Input**

```json
{
  "fn": "dbgumbel",
  "x":     [number, ...],
  "mu":    number,
  "sigma": number,
  "delta": number,
  "log":   boolean (optional, default false; when true, returns log-density)
}
```

**Output**

```json
{ "ok": true, "fn": "dbgumbel", "result": [number, ...] }
```

### `pbgumbel` — cumulative distribution

**Input**

```json
{
  "fn": "pbgumbel",
  "q":          [number, ...],
  "mu":         number,
  "sigma":      number,
  "delta":      number,
  "lower_tail": boolean (optional, default true)
}
```

**Output**

```json
{ "ok": true, "fn": "pbgumbel", "result": [number, ...] }
```

### `qbgumbel` — quantile function

Invert the CDF using a numerical search bracketed by `[initial, final]`.

**Input**

```json
{
  "fn": "qbgumbel",
  "p":       [number, ...],
  "mu":      number,
  "sigma":   number,
  "delta":   number,
  "initial": number (optional, default -10),
  "final":   number (optional, default  10)
}
```

**Output**

```json
{ "ok": true, "fn": "qbgumbel", "result": [number, ...] }
```

### `rbgumbel` — random variates

**Input**

```json
{
  "fn":    "rbgumbel",
  "n":     integer,
  "mu":    number,
  "sigma": number,
  "delta": number,
  "seed":  integer (optional; sets `set.seed` for reproducibility)
}
```

**Output**

```json
{ "ok": true, "fn": "rbgumbel", "result": [number, ...] }
```

### `m1bgumbel` — first moment

Closed-form $E[X]$ of the bimodal Gumbel.

**Input**

```json
{ "fn": "m1bgumbel", "mu": number, "sigma": number, "delta": number }
```

**Output**

```json
{ "ok": true, "fn": "m1bgumbel", "result": number }
```

### `m2bgumbel` — second moment

Closed-form $E[X^2]$ of the bimodal Gumbel.

**Input**

```json
{ "fn": "m2bgumbel", "mu": number, "sigma": number, "delta": number }
```

**Output**

```json
{ "ok": true, "fn": "m2bgumbel", "result": number }
```

### `init_theta` — robust starting values for MLE

Returns a robust starting triple `(mu, sigma, delta)` for the maximum-likelihood
estimator. Numerical MLE for the bimodal Gumbel is sensitive to initialization;
this function makes the heuristic explicit so the agent can inspect or
override the seed before running `mlebgumbel`.

**Input**

```json
{ "fn": "init_theta", "data": [number, ...] }
```

**Output**

```json
{
  "ok": true,
  "fn": "init_theta",
  "result": {
    "mu":       number,
    "sigma":    number,
    "delta":    number,
    "strategy": string,
    "n":        integer
  }
}
```

The strategy currently used is `median + MAD + delta=0.1`: `mu` is the sample
median (robust to outliers from the second mode), `sigma` is the median
absolute deviation rescaled to a Gumbel-equivalent scale (with a small floor
to prevent a degenerate seed), and `delta = 0.1` provides a near-unimodal
seed that lets the optimizer move toward the bimodal regime.

### `mlebgumbel` — maximum likelihood estimation

Fit `mu`, `sigma`, `delta` to a sample by numerical MLE. The agent may pass
its own `theta` triple; if absent, the dispatcher uses `init_theta`'s strategy
automatically. If the user-supplied `theta` causes the optimizer to fail, the
dispatcher transparently retries with the auto-init seed and reports which
strategy was used in the response.

**Input**

```json
{
  "fn":    "mlebgumbel",
  "data":  [number, ...],
  "theta": [number, number, number] (optional; [mu, sigma, delta] starting values),
  "auto":  boolean (optional, default true; passed through to bgumbel::mlebgumbel)
}
```

**Output**

```json
{
  "ok": true,
  "fn": "mlebgumbel",
  "result": {
    "estimate":       { "mu": number, "sigma": number, "delta": number },
    "standard_error": { "mu": number, "sigma": number, "delta": number },
    "loglik":         number,
    "n":              integer,
    "init_strategy":  "auto" | "user_supplied" | "fallback_auto_after_user_failed",
    "theta_used":     { "mu": number, "sigma": number, "delta": number }
  }
}
```

If both the user-supplied seed and the auto-init fallback fail, the function
returns `{"ok": false, "error": "MLE failed even after auto-init fallback: ..."}`
and recommends calling `init_theta` to inspect the heuristic seed.

## When to invoke

- The agent has tabular environmental, climatic, or extreme-value data and
  evidence of two distinct extreme regimes (cold/warm, wet/dry, two failure
  modes, two market regimes).
- The user asks to model bimodality without resorting to a five-parameter
  free mixture.
- The user wants closed-form moments rather than numerical integration.
- The agent needs MLE with sane defaults: pass `data` only, get the fit.

## Error contract

Any failure inside R returns:

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

Examples: missing or unparseable input, package not installed, `nlm` did not
converge, parameter out of admissible range. For `mlebgumbel`, the error
message points the caller toward `init_theta`.

## Worked examples

```bash
# Density at three points
echo '{"fn":"dbgumbel","x":[-1.0,0.0,1.0],"mu":0.0,"sigma":1.0,"delta":0.5}' \
  | Rscript --vanilla skills/bgumbel/invoke.R

# Sample 200 variates with a fixed seed
echo '{"fn":"rbgumbel","n":200,"mu":0.0,"sigma":1.0,"delta":0.5,"seed":42}' \
  | Rscript --vanilla skills/bgumbel/invoke.R

# Inspect the heuristic seed for MLE
echo '{"fn":"init_theta","data":[1.2,2.3,0.5,4.1,3.0,5.5,1.8,2.7,0.9,3.3]}' \
  | Rscript --vanilla skills/bgumbel/invoke.R

# Fit by MLE, letting the dispatcher pick init_theta automatically
echo '{"fn":"mlebgumbel","data":[<your data>]}' \
  | Rscript --vanilla skills/bgumbel/invoke.R
```
