# Architecture

community-skills is a thin three-layer system. There is no daemon, no RPC
server, no shared state between calls.

## Layers

```
+----------------------------------------------------+
|  Agent harness                                     |   any tool that can spawn a subprocess
|  (Claude Code, Codex, OpenCode, custom agent)      |   and exchange JSON
+--------------------|-------------------------------+
                     |
                     |  invoke("bgumbel", { "fn": "dbgumbel", ... })
                     v
+----------------------------------------------------+
|  bridges/__init__.py    auto-router                |   reads `runtime:` field
+--------------------|-------------------------------+
                     |
              +------+------+
              |             |
              v             v
+-------------+--+   +------+--------+
| bridges/r.py   |   | bridges/      |
| (canonical;    |   |  python.py    |
|  all CRAN pkg) |   | (in-tree only)|
+--------|-------+   +---------------+
         |
         |  subprocess.run([Rscript, invoke.R], stdin=json, capture stdout)
         v
+----------------------------------------------------+
|  skills/<name>/invoke.R                            |
|  - reads JSON from stdin                           |
|  - dispatches on `fn` field                        |
|  - calls the wrapped package function              |
|  - writes JSON to stdout                           |
+----------------------------------------------------+
                     |
                     v
        the wrapped upstream package
        (e.g. CRAN bgumbel, system R)
```

## Data flow

1. The agent constructs a JSON payload: `{"fn": "...", ...arguments}`.
2. It calls `bridges.invoke(skill, payload)` (or runs `Rscript invoke.R`
   directly with the payload on stdin).
3. The router reads the `runtime:` field from the skill's `SKILL.md` and
   delegates to the matching bridge.
4. The bridge spawns the runtime, sends the payload on stdin, captures
   stdout and stderr, and parses the result.
5. The result is always a Python dict with at least `ok: bool`. On
   success it also has `fn: str` and `result: Any`. On failure it has
   `error: str`.

## Failure modes and where they surface

| Failure | Surfaces as | Returncode |
|---|---|---|
| `Rscript` not on PATH | `{"ok": false, "error": "Rscript not found..."}` | n/a (bridge short-circuits) |
| Upstream package not installed | `{"ok": false, "error": "...not installed..."}` | 1 |
| Invalid JSON on stdin | `{"ok": false, "error": "Invalid JSON..."}` | 1 |
| Missing `fn` field | `{"ok": false, "error": "Field `fn` is required."}` | 1 |
| Unknown `fn` | `{"ok": false, "error": "Unknown fn..."}` | 1 |
| Wrapped function raises | `{"ok": false, "error": "<R error message>"}` | 1 |
| Timeout exceeded | `{"ok": false, "error": "R skill timed out..."}` | n/a (Python kills subprocess) |
| Non-JSON stdout | `{"ok": false, "error": "...non-JSON stdout..."}` | bridge propagates returncode |

A well-behaved skill never produces stdout other than the single result
JSON object. If a skill's underlying R code prints diagnostics, those
should go to stderr.

## Concurrency

Each call is independent: a fresh subprocess is spawned and torn down.
Skills are safe to invoke in parallel from threads or processes; the
bridge does not maintain any shared state. The wrapped package may have
its own assumptions (some R packages cache global state), but those are
isolated within each subprocess.

## Versioning

community-skills follows semantic versioning for the **hub itself** (the
bridges, the contract format, the CLI). Each skill declares the version
range it supports for the upstream package via the `package_version_pinned`
field in its `SKILL.md` front matter. A breaking change in an upstream
package may force a major bump for the affected skill but does not affect
others.
