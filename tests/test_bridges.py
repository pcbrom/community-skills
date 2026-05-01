"""Unit tests for the bridge dispatcher.

These tests exercise the routing layer in `bridges/__init__.py` without
requiring R to be installed (except the dedicated R smoke test which is
skipped when Rscript is missing).
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from bridges import invoke
from bridges import _read_runtime, SKILLS_DIR


def test_invoke_unknown_skill_returns_error_not_raises():
    result = invoke("does-not-exist", {"fn": "anything"})
    assert result["ok"] is False
    assert "skill not found" in result["error"]


def test_invoke_skill_without_skill_md(tmp_path, monkeypatch):
    fake_skill = tmp_path / "fake_skill"
    fake_skill.mkdir()
    monkeypatch.setattr("bridges.SKILLS_DIR", tmp_path)
    result = invoke("fake_skill", {"fn": "x"})
    assert result["ok"] is False
    assert "missing SKILL.md" in result["error"]


def test_read_runtime_parses_front_matter(tmp_path):
    skill_md = tmp_path / "SKILL.md"
    skill_md.write_text("---\nname: foo\nruntime: r\n---\n# body\n", encoding="utf-8")
    assert _read_runtime(skill_md) == "r"


def test_read_runtime_case_insensitive(tmp_path):
    skill_md = tmp_path / "SKILL.md"
    skill_md.write_text("---\nRUNTIME: Python\n---\n", encoding="utf-8")
    assert _read_runtime(skill_md) == "python"


def test_read_runtime_raises_when_missing(tmp_path):
    skill_md = tmp_path / "SKILL.md"
    skill_md.write_text("---\nname: foo\n---\n", encoding="utf-8")
    with pytest.raises(ValueError, match="runtime"):
        _read_runtime(skill_md)


def test_python_bridge_is_placeholder():
    """The Python bridge raises NotImplementedError until implemented."""
    from bridges.python import invoke as invoke_py
    with pytest.raises(NotImplementedError):
        invoke_py("any/path", {"fn": "x"})


def test_julia_bridge_is_placeholder():
    from bridges.julia import invoke as invoke_jl
    with pytest.raises(NotImplementedError):
        invoke_jl("any/path", {"fn": "x"})


def test_bridge_handles_unknown_runtime(tmp_path, monkeypatch):
    """An unknown `runtime:` value is reported, not raised."""
    fake = tmp_path / "weird_skill"
    fake.mkdir()
    (fake / "SKILL.md").write_text("---\nruntime: cobol\n---\n", encoding="utf-8")
    monkeypatch.setattr("bridges.SKILLS_DIR", tmp_path)
    result = invoke("weird_skill", {"fn": "x"})
    assert result["ok"] is False
    assert "unknown runtime" in result["error"].lower()


@pytest.mark.skipif(shutil.which("Rscript") is None, reason="R not installed")
def test_r_bridge_payload_not_serializable():
    from bridges.r import invoke as invoke_r
    skill_dir = SKILLS_DIR / "bgumbel"
    # set objects are not JSON-serializable
    bad = {"fn": "dbgumbel", "x": {1, 2, 3}}
    result = invoke_r(skill_dir, bad)
    assert result["ok"] is False
    assert "JSON-serializable" in result["error"]


@pytest.mark.skipif(shutil.which("Rscript") is None, reason="R not installed")
def test_r_bridge_missing_invoke_r(tmp_path):
    from bridges.r import invoke as invoke_r
    result = invoke_r(tmp_path, {"fn": "x"})
    assert result["ok"] is False
    assert "missing invoke.R" in result["error"]
