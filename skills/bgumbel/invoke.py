"""Optional Python wrapper for the bgumbel skill.

Thin convenience layer over `bridges.invoke("bgumbel", ...)`. R must be on
PATH and the `bgumbel` R package installed.
"""
from __future__ import annotations

from typing import Any, Sequence

from bridges import invoke as _invoke


_SKILL = "bgumbel"


def _call(fn: str, **payload: Any) -> dict[str, Any]:
    payload = {"fn": fn, **payload}
    return _invoke(_SKILL, payload)


def dbgumbel(
    x: Sequence[float], mu: float, sigma: float, delta: float, log: bool = False
) -> dict[str, Any]:
    return _call("dbgumbel", x=list(x), mu=mu, sigma=sigma, delta=delta, log=log)


def pbgumbel(
    q: Sequence[float],
    mu: float,
    sigma: float,
    delta: float,
    lower_tail: bool = True,
) -> dict[str, Any]:
    return _call("pbgumbel", q=list(q), mu=mu, sigma=sigma, delta=delta, lower_tail=lower_tail)


def qbgumbel(
    p: Sequence[float],
    mu: float,
    sigma: float,
    delta: float,
    initial: float = -10.0,
    final: float = 10.0,
) -> dict[str, Any]:
    return _call(
        "qbgumbel", p=list(p), mu=mu, sigma=sigma, delta=delta, initial=initial, final=final
    )


def rbgumbel(
    n: int, mu: float, sigma: float, delta: float, seed: int | None = None
) -> dict[str, Any]:
    payload: dict[str, Any] = dict(n=int(n), mu=mu, sigma=sigma, delta=delta)
    if seed is not None:
        payload["seed"] = int(seed)
    return _call("rbgumbel", **payload)


def m1bgumbel(mu: float, sigma: float, delta: float) -> dict[str, Any]:
    return _call("m1bgumbel", mu=mu, sigma=sigma, delta=delta)


def m2bgumbel(mu: float, sigma: float, delta: float) -> dict[str, Any]:
    return _call("m2bgumbel", mu=mu, sigma=sigma, delta=delta)


def init_theta(data: Sequence[float]) -> dict[str, Any]:
    """Return robust starting values (mu, sigma, delta) for the MLE."""
    return _call("init_theta", data=list(data))


def mlebgumbel(
    data: Sequence[float],
    theta: Sequence[float] | None = None,
    auto: bool = True,
) -> dict[str, Any]:
    """Fit the bimodal Gumbel by MLE.

    If `theta` is None, the dispatcher uses init_theta automatically. If a
    user-supplied `theta` causes the optimizer to fail, the dispatcher
    retries with the auto-init seed and reports the strategy used.
    """
    payload: dict[str, Any] = dict(data=list(data), auto=bool(auto))
    if theta is not None:
        payload["theta"] = list(theta)
    return _call("mlebgumbel", **payload)


__all__ = [
    "dbgumbel", "pbgumbel", "qbgumbel", "rbgumbel",
    "m1bgumbel", "m2bgumbel",
    "init_theta", "mlebgumbel",
]
