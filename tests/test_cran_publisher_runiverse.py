"""Tests for the cran_publisher r-universe channel.

Three functions are exercised: the r-universe readiness preflight, the
packages.json registration, and the r-universe API status query. The
status query talks to the network in production; here the HTTP layer is
replaced with a stub so the tests stay offline and deterministic.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from cran_publisher import (
    RuniversePreflightResult,
    RuniverseRegisterResult,
    RuniverseStatusResult,
    runiverse_preflight,
    runiverse_register,
    runiverse_status,
)
from cran_publisher import runiverse as runiverse_mod

CLEAN_CHECK = "* using log directory\nStatus: 2 NOTEs\n"
WARN_CHECK = "* checking foo ... WARNING\ndetail\nStatus: 1 WARNING\n"
ERROR_CHECK = "* checking bar ... ERROR\ndetail\nStatus: 1 ERROR\n"
MULTICORE_CHECK = (
    "* checking tests ... NOTE\n"
    "  Running R code in 'testthat.R' had CPU time 3.7 times elapsed time\n"
    "Status: 1 NOTE\n"
)

DESCRIPTION = """\
Package: demopkg
Version: {version}
Title: A Demonstration Package
Description: A small package used to exercise the r-universe preflight.
License: MIT + file LICENSE
Authors@R: person("A", "Maintainer", email = "a@example.org",
    role = c("aut", "cre"))
"""


def _failed_gate_names(result: RuniversePreflightResult) -> list[str]:
    return [g.name for g in result.blocking_failures]


def _make_pkg(root: Path, *, version="0.1.0", news=True, git=True) -> Path:
    """Write a minimal package source tree and return its path.

    When ``git`` is set the tree is turned into a Git repository with an
    ``origin`` remote, the state the r-universe preflight expects.
    """
    pkg = root / "demopkg"
    pkg.mkdir()
    (pkg / "DESCRIPTION").write_text(DESCRIPTION.format(version=version),
                                     encoding="utf-8")
    if news:
        (pkg / "NEWS.md").write_text(f"# demopkg {version}\n\n* First.\n",
                                     encoding="utf-8")
    if git:
        subprocess.run(["git", "init", "-q"], cwd=pkg, check=True)
        subprocess.run(
            ["git", "remote", "add", "origin",
             "https://github.com/pcbrom/demopkg"],
            cwd=pkg, check=True,
        )
    return pkg


# --- runiverse_preflight --------------------------------------------------

def test_ready_package_passes_every_blocking_gate(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = runiverse_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert isinstance(result, RuniversePreflightResult)
    assert result.ready is True
    assert result.blocking_failures == []
    assert any("r-universe" in line.lower() for line in result.handoff)


def test_development_version_does_not_block(tmp_path):
    # Unlike the CRAN preflight, r-universe builds development versions.
    pkg = _make_pkg(tmp_path, version="0.0.0.9000")
    result = runiverse_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert result.ready is True


def test_check_warning_does_not_block(tmp_path):
    # r-universe publishes a package with check warnings; it renders the
    # badge rather than rejecting the package.
    pkg = _make_pkg(tmp_path)
    result = runiverse_preflight(pkg, check_stdout=WARN_CHECK)
    assert result.ready is True
    check_gate = next(g for g in result.gates if g.name == "R CMD check")
    assert check_gate.passed is True


def test_check_error_blocks(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = runiverse_preflight(pkg, check_stdout=ERROR_CHECK)
    assert result.ready is False
    assert "R CMD check" in _failed_gate_names(result)


def test_multicore_note_does_not_block(tmp_path):
    # The CRAN two-core rule does not apply to r-universe.
    pkg = _make_pkg(tmp_path)
    result = runiverse_preflight(pkg, check_stdout=MULTICORE_CHECK)
    assert result.ready is True


def test_missing_check_log_is_non_blocking(tmp_path):
    # r-universe runs its own check on every build, so a missing local
    # check log leaves the package ready, unlike the CRAN preflight.
    pkg = _make_pkg(tmp_path)
    result = runiverse_preflight(pkg)
    assert result.ready is True
    check_gate = next(g for g in result.gates if g.name == "R CMD check")
    assert check_gate.passed is None
    assert check_gate.blocking is False


def test_missing_git_remote_blocks(tmp_path):
    pkg = _make_pkg(tmp_path, git=False)
    result = runiverse_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert result.ready is False
    assert "git origin remote" in _failed_gate_names(result)


def test_missing_description_returns_not_ready(tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()
    result = runiverse_preflight(empty)
    assert result.ready is False


# --- runiverse_register ---------------------------------------------------

def test_register_dry_run_writes_nothing(tmp_path):
    universe = tmp_path / "pcbrom.r-universe.dev"
    universe.mkdir()
    result = runiverse_register(
        universe, package="demopkg",
        url="https://github.com/pcbrom/demopkg",
    )
    assert isinstance(result, RuniverseRegisterResult)
    assert result.dry_run is True
    assert result.written is False
    assert result.action == "added"
    assert not (universe / "packages.json").exists()


def test_register_confirm_writes_packages_json(tmp_path):
    universe = tmp_path / "pcbrom.r-universe.dev"
    universe.mkdir()
    result = runiverse_register(
        universe, package="demopkg",
        url="https://github.com/pcbrom/demopkg",
        branch="main", confirm=True,
    )
    assert result.written is True
    written = json.loads((universe / "packages.json").read_text())
    assert written == [
        {"package": "demopkg", "url": "https://github.com/pcbrom/demopkg",
         "branch": "main"}
    ]


def test_register_updates_existing_entry(tmp_path):
    universe = tmp_path / "pcbrom.r-universe.dev"
    universe.mkdir()
    (universe / "packages.json").write_text(
        json.dumps([
            {"package": "demopkg", "url": "https://example.org/old"},
            {"package": "other", "url": "https://github.com/pcbrom/other"},
        ]),
        encoding="utf-8",
    )
    result = runiverse_register(
        universe, package="demopkg",
        url="https://github.com/pcbrom/demopkg", confirm=True,
    )
    assert result.action == "updated"
    written = json.loads((universe / "packages.json").read_text())
    assert len(written) == 2
    demo = next(e for e in written if e["package"] == "demopkg")
    assert demo["url"] == "https://github.com/pcbrom/demopkg"
    # The unrelated entry survives the merge untouched.
    assert any(e["package"] == "other" for e in written)


def test_register_identical_entry_is_unchanged(tmp_path):
    universe = tmp_path / "pcbrom.r-universe.dev"
    universe.mkdir()
    entry = {"package": "demopkg", "url": "https://github.com/pcbrom/demopkg"}
    (universe / "packages.json").write_text(json.dumps([entry]),
                                            encoding="utf-8")
    result = runiverse_register(
        universe, package="demopkg",
        url="https://github.com/pcbrom/demopkg", confirm=True,
    )
    assert result.action == "unchanged"
    assert result.written is False


def test_register_missing_universe_dir_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        runiverse_register(
            tmp_path / "does-not-exist", package="demopkg",
            url="https://github.com/pcbrom/demopkg",
        )


# --- runiverse_status -----------------------------------------------------

class _StubResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        if self._payload is _NO_JSON:
            raise ValueError("not JSON")
        return self._payload


_NO_JSON = object()


def _stub_get(monkeypatch, response):
    def fake_get(url, timeout=None):  # noqa: ARG001
        return response
    monkeypatch.setattr(runiverse_mod.requests, "get", fake_get)


def test_status_single_package(monkeypatch):
    payload = {
        "Package": "gpumetropolis", "Version": "0.1.0",
        "_status": "success",
        "_buildurl": "https://github.com/r-universe/pcbrom/actions/runs/1",
        "RemoteUrl": "https://github.com/pcbrom/gpumetropolis",
        "RemoteSha": "abc123",
        "_published": "2026-05-22T13:00:00.000Z",
        "_binaries": [{"os": "linux", "r": "4.7.0"}],
        "_jobs": [{"config": "linux-release-x86_64", "check": "OK"}],
    }
    _stub_get(monkeypatch, _StubResponse(200, payload))
    result = runiverse_status("pcbrom", "gpumetropolis")
    assert isinstance(result, RuniverseStatusResult)
    assert result.found is True
    assert result.status == "success"
    assert result.version == "0.1.0"
    assert result.jobs == [{"config": "linux-release-x86_64", "check": "OK"}]
    assert result.binaries == [{"os": "linux", "r": "4.7.0"}]


def test_status_whole_universe(monkeypatch):
    payload = [
        {"Package": "gpumetropolis", "Version": "0.1.0", "_status": "success"},
        {"Package": "bgumbel", "Version": "0.0.2", "_status": "success"},
    ]
    _stub_get(monkeypatch, _StubResponse(200, payload))
    result = runiverse_status("pcbrom")
    assert result.found is True
    assert result.package is None
    assert len(result.packages) == 2
    assert {p["package"] for p in result.packages} == {"gpumetropolis",
                                                        "bgumbel"}


def test_status_404_reports_not_found(monkeypatch):
    _stub_get(monkeypatch, _StubResponse(404, None))
    result = runiverse_status("pcbrom", "missingpkg")
    assert result.found is False
    assert "404" in result.reason


def test_status_normalizes_universe_argument(monkeypatch):
    _stub_get(monkeypatch, _StubResponse(200, []))
    for given in ("pcbrom", "pcbrom.r-universe.dev",
                  "https://pcbrom.r-universe.dev"):
        result = runiverse_status(given)
        assert result.universe == "pcbrom"
