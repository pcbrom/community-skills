"""Smoke tests for the autoresearch skill (Python runtime).

The dispatcher shells out to the ``autoresearch`` CLI; tests are
skipped when the CLI is not on PATH.
"""
from __future__ import annotations

import shutil

import pytest

from bridges import invoke


pytestmark = pytest.mark.skipif(
    shutil.which("autoresearch") is None,
    reason="autoresearch CLI not on PATH",
)


def test_dispatcher_rejects_missing_fn():
    r = invoke("autoresearch", {})
    assert r["ok"] is False
    assert "fn" in r["error"].lower()


def test_dispatcher_rejects_unknown_fn():
    r = invoke("autoresearch", {"fn": "does_not_exist"})
    assert r["ok"] is False
    assert "Unknown" in r["error"]


def test_init_requires_problem_and_target():
    r = invoke("autoresearch", {"fn": "init"})
    assert r["ok"] is False
    assert "problem" in r["error"] or "target" in r["error"]


def test_init_requires_target_when_problem_present():
    r = invoke("autoresearch", {"fn": "init", "problem": "/tmp/no.yaml"})
    assert r["ok"] is False
    assert "target" in r["error"]


def test_critic_dry_run_returns_subprocess_outcome():
    """Dry-run skips the Ollama call so this works even when Ollama
    is not running. We do not assert on the exact stdout content
    because the project's `problem.yaml` may not be present; instead
    the contract is that the dispatcher returns a structured outcome
    with an exit_code, stdout, and stderr."""
    r = invoke("autoresearch", {"fn": "critic", "dry_run": True})
    assert r["ok"] is True
    payload = r["result"]
    assert "exit_code" in payload
    assert "stdout" in payload
    assert "stderr" in payload
