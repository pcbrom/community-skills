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


def test_python_bridge_missing_invoke_py(tmp_path):
    """The Python bridge surfaces a structured error when the skill dir
    has no invoke.py, mirroring the R bridge contract."""
    from bridges.python import invoke as invoke_py
    result = invoke_py(tmp_path, {"fn": "x"})
    assert result["ok"] is False
    assert "missing invoke.py" in result["error"]


def test_python_bridge_payload_not_serializable(tmp_path):
    """Sets are not JSON-serializable; the bridge catches the error
    instead of letting the subprocess fail with a useless stderr."""
    from bridges.python import invoke as invoke_py
    (tmp_path / "invoke.py").write_text("import sys; sys.exit(0)\n", encoding="utf-8")
    result = invoke_py(tmp_path, {"fn": "x", "bad": {1, 2, 3}})
    assert result["ok"] is False
    assert "JSON-serializable" in result["error"]


def test_python_bridge_emits_ok_for_well_formed_skill(tmp_path):
    """End-to-end happy path with a one-line dispatcher."""
    from bridges.python import invoke as invoke_py
    (tmp_path / "invoke.py").write_text(
        "import json, sys\n"
        "p = json.loads(sys.stdin.read())\n"
        "print(json.dumps({'ok': True, 'fn': p['fn'], 'result': p.get('value')}))\n",
        encoding="utf-8",
    )
    result = invoke_py(tmp_path, {"fn": "echo", "value": 42})
    assert result["ok"] is True
    assert result["fn"] == "echo"
    assert result["result"] == 42


def test_julia_runtime_is_reported_as_unknown(tmp_path, monkeypatch):
    """Julia is out of scope for this project (decided 2026-05-09).
    A SKILL.md that declares ``runtime: julia`` is reported as unknown,
    same as ``cobol``."""
    fake = tmp_path / "julia_skill"
    fake.mkdir()
    (fake / "SKILL.md").write_text("---\nruntime: julia\n---\n", encoding="utf-8")
    monkeypatch.setattr("bridges.SKILLS_DIR", tmp_path)
    result = invoke("julia_skill", {"fn": "x"})
    assert result["ok"] is False
    assert "unknown runtime" in result["error"].lower()


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
