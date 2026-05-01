# Design rationale

The community-skills hub turns a package into an agent-callable skill by
combining three pieces: a machine-readable contract (`SKILL.md`), a per-runtime
bridge (`bridges/<runtime>.py`), and a JSON transport. The choice of these
pieces is deliberate.

## Why a contract per skill instead of free-form prompting

LLM agents that must call external code benefit from a formal description
of what is callable. Without it, the agent invents APIs (hallucinates
arguments, misuses defaults), and the developer pays the cost in retries
and incident reports. `SKILL.md` declares for each function the input
schema, the output schema, and a worked example that the agent can imitate.
This is the same logic behind OpenAPI for HTTP services and behind
function-calling schemas in modern LLM toolchains, applied at package
granularity.

## Why subprocess + JSON instead of in-process embedding

In-process bridges (rpy2 for R, PyJulia for Julia, JPype for Java) are
tempting because they avoid the per-call spawn cost. They are also fragile:
they require the calling Python to be ABI-compatible with the target
runtime, they pull large native dependencies, and they tend to produce
opaque crashes when versions drift.

community-skills targets agentic invocation, where each call is an
intentional decision by the agent rather than an inner-loop computation.
A spawn cost of roughly 100ms is irrelevant in that regime, and the
benefits are immediate:

- **Zero compile-time dependencies**: the calling code only needs Python's
  standard library plus `subprocess`.
- **Portability**: any environment that can install the upstream package
  and run its interpreter works.
- **Manual debuggability**: a developer can run
  `Rscript --vanilla skills/bgumbel/invoke.R < payload.json` and inspect
  the result without touching the agent harness.
- **Same pattern across languages**: the contract for an R skill, a
  Python skill, and a Julia skill is identical. Only the bridge changes.

When a skill becomes hot enough that spawn cost matters, an embedded bridge
can be added as an optional accelerator without breaking the JSON contract.

## Why one bridge per runtime instead of per skill

Bridges live in `bridges/<runtime>.py` so that every skill of a given
runtime shares the same dispatcher logic: payload validation, subprocess
spawn, stderr capture, timeout, JSON parsing, and graceful error reporting.
A skill author writes only the dispatcher in the package's native language
(`invoke.R`, `invoke.py`, `invoke.jl`) plus a `SKILL.md`, and inherits the
hardened bridge for free.

## Why JSON instead of binary or RPC

JSON is human-readable, language-independent, and trivially debuggable.
The hub does not target high-throughput data movement; if a skill needs
to ship gigabytes of arrays, it should write them to disk and pass paths
in the JSON payload. For numeric vectors below a few thousand elements,
JSON is fast enough.

## What this hub deliberately does *not* do

- It does not run the LLM. It assumes an external agent harness has
  decided to invoke a skill and produced the JSON payload.
- It does not ship a hosting layer. There is no daemon, no socket, no
  RPC server. Each call is a fresh subprocess.
- It does not virtualize the upstream package. R is invoked from the
  system R; Python skills will use the system or chosen virtualenv;
  Julia, the system Julia. Reproducibility relies on documenting the
  upstream version in `SKILL.md` front matter.
