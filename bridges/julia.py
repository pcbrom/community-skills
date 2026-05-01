"""Julia bridge: placeholder.

A future implementation will spawn `julia` and exchange JSON via stdin/stdout,
mirroring the `bridges.r` design. Until then, calling this bridge raises
NotImplementedError.

Track the implementation here:
    https://github.com/pcbrom/community-skills/issues
    Tag: bridge:julia
"""
from __future__ import annotations

from pathlib import Path
from typing import Any


def invoke(skill_dir: Path | str, payload: dict[str, Any]) -> dict[str, Any]:
    raise NotImplementedError(
        "The Julia bridge is not implemented yet. "
        "See CONTRIBUTING.md for the design and open an issue tagged "
        "`bridge:julia` to coordinate."
    )


__all__ = ["invoke"]
