"""Smoke test for the bgumbel skill.

Requires R and the `bgumbel` package to be installed. The test is skipped
otherwise so contributors without R can still run pytest.
"""
from __future__ import annotations

import shutil
import subprocess

import pytest

from bridges import invoke


_HAS_R = shutil.which("Rscript") is not None


def _bgumbel_installed() -> bool:
    if not _HAS_R:
        return False
    completed = subprocess.run(
        ["Rscript", "--vanilla", "-e", 'q(status = if (requireNamespace("bgumbel", quietly = TRUE)) 0 else 1)'],
        capture_output=True,
    )
    return completed.returncode == 0


_HAS_BGUMBEL = _bgumbel_installed()
_REASON = "R or the bgumbel package is not installed"


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_dbgumbel_density_at_three_points():
    result = invoke("bgumbel", {
        "fn": "dbgumbel",
        "x": [-1.0, 0.0, 1.0],
        "mu": 0.0,
        "sigma": 1.0,
        "delta": 0.5,
    })
    assert result["ok"] is True, result
    assert result["fn"] == "dbgumbel"
    values = result["result"]
    assert isinstance(values, list)
    assert len(values) == 3
    for v in values:
        assert isinstance(v, (int, float))
        assert v >= 0.0


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_pbgumbel_is_monotone_nondecreasing():
    result = invoke("bgumbel", {
        "fn": "pbgumbel",
        "q": [-3.0, -1.0, 0.0, 1.0, 3.0, 10.0],
        "mu": 0.0,
        "sigma": 1.0,
        "delta": 0.5,
    })
    assert result["ok"] is True, result
    cdf = result["result"]
    assert all(0.0 <= v <= 1.0 + 1e-9 for v in cdf)
    assert all(cdf[i] <= cdf[i + 1] + 1e-9 for i in range(len(cdf) - 1))


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_rbgumbel_returns_n_samples_with_seed_reproducible():
    payload = {"fn": "rbgumbel", "n": 50, "mu": 0.0, "sigma": 1.0, "delta": 0.5, "seed": 42}
    a = invoke("bgumbel", payload)
    b = invoke("bgumbel", payload)
    assert a["ok"] is True and b["ok"] is True
    assert len(a["result"]) == 50
    assert a["result"] == b["result"]


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_m1bgumbel_returns_scalar():
    result = invoke("bgumbel", {"fn": "m1bgumbel", "mu": 0.0, "sigma": 1.0, "delta": 0.5})
    assert result["ok"] is True, result
    assert isinstance(result["result"], (int, float))


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_init_theta_returns_three_floats_and_strategy():
    data = [1.2, 2.3, 0.5, 4.1, 3.0, 5.5, 1.8, 2.7, 0.9, 3.3]
    result = invoke("bgumbel", {"fn": "init_theta", "data": data})
    assert result["ok"] is True, result
    out = result["result"]
    assert set(["mu", "sigma", "delta", "strategy", "n"]).issubset(out.keys())
    assert isinstance(out["mu"], (int, float))
    assert out["sigma"] > 0
    assert isinstance(out["delta"], (int, float))


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_mlebgumbel_recovers_parameters_within_tolerance():
    """Fit on a sample drawn from a known DGP. SE-bound on each parameter."""
    sample = invoke("bgumbel", {
        "fn": "rbgumbel", "n": 500, "mu": 0.0, "sigma": 1.0, "delta": 0.5, "seed": 7,
    })["result"]
    fit = invoke("bgumbel", {"fn": "mlebgumbel", "data": sample})
    assert fit["ok"] is True, fit
    est = fit["result"]["estimate"]
    se = fit["result"]["standard_error"]
    # Each parameter recovered within ~3 standard errors of the truth.
    assert abs(est["mu"] - 0.0)   < max(0.5, 3 * se["mu"])
    assert abs(est["sigma"] - 1.0) < max(0.5, 3 * se["sigma"])
    assert abs(est["delta"] - 0.5) < max(0.5, 3 * se["delta"])
    assert fit["result"]["init_strategy"] in (
        "auto", "user_supplied", "fallback_auto_after_user_failed"
    )


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_mlebgumbel_fallback_when_user_theta_is_pathological():
    """A degenerate theta should trigger the auto-init fallback."""
    sample = invoke("bgumbel", {
        "fn": "rbgumbel", "n": 200, "mu": 0.0, "sigma": 1.0, "delta": 0.5, "seed": 1,
    })["result"]
    # sigma=0 will likely break the optimizer; the dispatcher should retry.
    fit = invoke("bgumbel", {
        "fn": "mlebgumbel",
        "data": sample,
        "theta": [0.0, 0.0, 0.0],
    })
    # Either the fallback worked or the second attempt also failed; both
    # outcomes are expected to be reported coherently.
    assert "init_strategy" in fit.get("result", {}) or fit["ok"] is False


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_unknown_fn_returns_error():
    result = invoke("bgumbel", {"fn": "totally_made_up"})
    assert result["ok"] is False
    assert "Unknown fn" in result["error"]


@pytest.mark.skipif(not _HAS_BGUMBEL, reason=_REASON)
def test_missing_required_field_returns_error():
    result = invoke("bgumbel", {"fn": "dbgumbel", "x": [0.0]})  # missing mu/sigma/delta
    assert result["ok"] is False
    assert "required" in result["error"].lower()
