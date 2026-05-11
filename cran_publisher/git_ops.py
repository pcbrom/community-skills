"""Minimal git operations the cran_publisher fix loop needs.

Phase 5.2 wraps fix proposals in attempt branches:

- start an attempt branch off the run branch,
- apply the proposed file edits,
- if ``R CMD check`` improves, merge the branch into the run branch,
- if not, abandon the attempt branch (hard reset and switch back).

The functions here are thin shells over ``git``; they capture stdout and
stderr so the fix loop can attach them to its audit trail.
"""
from __future__ import annotations

import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path

DEFAULT_TIMEOUT_S = 60


@dataclass(slots=True)
class GitResult:
    cmd: tuple[str, ...]
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


def _run(cmd: list[str], cwd: Path | str, timeout: float = DEFAULT_TIMEOUT_S) -> GitResult:
    completed = subprocess.run(
        cmd, cwd=str(cwd),
        capture_output=True, timeout=timeout, check=False,
    )
    return GitResult(
        cmd=tuple(cmd),
        returncode=completed.returncode,
        stdout=completed.stdout.decode("utf-8", errors="replace"),
        stderr=completed.stderr.decode("utf-8", errors="replace"),
    )


def is_inside_work_tree(repo: Path | str) -> bool:
    return _run(["git", "rev-parse", "--is-inside-work-tree"], cwd=repo).ok


def current_branch(repo: Path | str) -> str:
    res = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo)
    return res.stdout.strip()


def is_clean(repo: Path | str) -> bool:
    """True iff there are no uncommitted changes (staged or unstaged)."""
    res = _run(["git", "status", "--porcelain"], cwd=repo)
    return res.ok and res.stdout.strip() == ""


def create_branch(repo: Path | str, name: str, *, from_ref: str | None = None) -> GitResult:
    cmd = ["git", "checkout", "-b", name]
    if from_ref:
        cmd.append(from_ref)
    return _run(cmd, cwd=repo)


def checkout(repo: Path | str, ref: str) -> GitResult:
    return _run(["git", "checkout", ref], cwd=repo)


def add_and_commit(
    repo: Path | str,
    paths: list[str],
    message: str,
    *,
    author: str | None = None,
) -> GitResult:
    add = _run(["git", "add", *paths], cwd=repo)
    if not add.ok:
        return add
    cmd = ["git", "commit", "-m", message]
    if author:
        cmd.extend(["--author", author])
    return _run(cmd, cwd=repo)


def reset_hard(repo: Path | str, ref: str = "HEAD") -> GitResult:
    return _run(["git", "reset", "--hard", ref], cwd=repo)


def merge_no_ff(repo: Path | str, branch: str, message: str) -> GitResult:
    return _run(["git", "merge", "--no-ff", branch, "-m", message], cwd=repo)


def delete_branch(repo: Path | str, branch: str, *, force: bool = False) -> GitResult:
    flag = "-D" if force else "-d"
    return _run(["git", "branch", flag, branch], cwd=repo)


def short_sha(repo: Path | str, ref: str = "HEAD") -> str:
    return _run(["git", "rev-parse", "--short", ref], cwd=repo).stdout.strip()


def format_cmd(result: GitResult) -> str:
    return " ".join(shlex.quote(p) for p in result.cmd)


__all__ = [
    "GitResult",
    "add_and_commit",
    "checkout",
    "create_branch",
    "current_branch",
    "delete_branch",
    "format_cmd",
    "is_clean",
    "is_inside_work_tree",
    "merge_no_ff",
    "reset_hard",
    "short_sha",
]
