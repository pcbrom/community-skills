"""Deprecation heuristics for CRAN packages.

Three statuses are emitted:

- ``active``: package was published within the last :data:`ACTIVE_MONTHS`
  months, regardless of archive presence.
- ``soft_deprecated``: last publication is older than :data:`SOFT_MONTHS`
  months.
- ``strong_deprecated``: package appears in the ``/Archive/`` listing but
  not in the current PACKAGES index, or its ``Maintainer`` line contains
  ``ORPHANED``.

Anything between :data:`ACTIVE_MONTHS` and :data:`SOFT_MONTHS` months is
treated as ``stale`` (informational only, not deprecated).

The heuristic intentionally avoids per-package GitHub lookups; those are
deferred to a later phase that needs richer signals (issue activity, last
commit date) and accepts the rate cost.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable

from .scrape import PackageRecord

ACTIVE_MONTHS = 12
SOFT_MONTHS = 36
ORPHAN_MARKER = "ORPHANED"

STATUS_ACTIVE = "active"
STATUS_STALE = "stale"
STATUS_SOFT = "soft_deprecated"
STATUS_STRONG = "strong_deprecated"


@dataclass(slots=True)
class DeprecationFlag:
    """Annotation attached to one :class:`PackageRecord`."""

    status: str
    is_deprecated: bool
    is_orphaned: bool
    reason: str
    months_since_update: float | None


def _parse_published(value: str | None) -> datetime | None:
    """Parse a ``Published`` field. Returns None on any failure."""
    if not value:
        return None
    head = value.strip().split(" UTC")[0].strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(head, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _months_between(then: datetime, now: datetime) -> float:
    """Approximate month delta (1 month = 30.4375 days, Gregorian average)."""
    return (now - then).total_seconds() / (30.4375 * 86400)


def classify(
    record: PackageRecord,
    now: datetime | None = None,
    archived_only_names: set[str] | None = None,
) -> DeprecationFlag:
    """Apply deprecation heuristics to one :class:`PackageRecord`.

    Parameters
    ----------
    record : PackageRecord
        Package to classify.
    now : datetime, optional
        Reference timestamp; defaults to current UTC time. Pass an explicit
        value in tests for determinism.
    archived_only_names : set[str], optional
        Names that appear in CRAN ``/Archive/`` but not in the current
        PACKAGES index. Membership marks ``strong_deprecated``.
    """
    now = now or datetime.now(tz=timezone.utc)
    archived_only_names = archived_only_names or set()
    maintainer = record.raw.get("Maintainer", "")
    is_orphaned = ORPHAN_MARKER in maintainer.upper()

    if record.name in archived_only_names:
        return DeprecationFlag(
            status=STATUS_STRONG,
            is_deprecated=True,
            is_orphaned=is_orphaned,
            reason="removed_from_cran",
            months_since_update=None,
        )

    if is_orphaned:
        return DeprecationFlag(
            status=STATUS_STRONG,
            is_deprecated=True,
            is_orphaned=True,
            reason="maintainer_orphaned",
            months_since_update=None,
        )

    published = _parse_published(record.published)
    if published is None:
        return DeprecationFlag(
            status=STATUS_STALE,
            is_deprecated=False,
            is_orphaned=False,
            reason="missing_published_date",
            months_since_update=None,
        )

    delta = _months_between(published, now)
    if delta >= SOFT_MONTHS:
        return DeprecationFlag(
            status=STATUS_SOFT,
            is_deprecated=True,
            is_orphaned=False,
            reason=f"no_update_for_{delta:.1f}_months",
            months_since_update=delta,
        )
    if delta >= ACTIVE_MONTHS:
        return DeprecationFlag(
            status=STATUS_STALE,
            is_deprecated=False,
            is_orphaned=False,
            reason=f"updated_{delta:.1f}_months_ago",
            months_since_update=delta,
        )
    return DeprecationFlag(
        status=STATUS_ACTIVE,
        is_deprecated=False,
        is_orphaned=False,
        reason=f"updated_{delta:.1f}_months_ago",
        months_since_update=delta,
    )


def classify_all(
    records: Iterable[PackageRecord],
    archived_only_names: set[str] | None = None,
    now: datetime | None = None,
) -> dict[str, DeprecationFlag]:
    """Map each record name to its :class:`DeprecationFlag`."""
    now = now or datetime.now(tz=timezone.utc)
    archived_only_names = archived_only_names or set()
    return {
        rec.name: classify(rec, now=now, archived_only_names=archived_only_names)
        for rec in records
    }


__all__ = [
    "ACTIVE_MONTHS",
    "SOFT_MONTHS",
    "STATUS_ACTIVE",
    "STATUS_STALE",
    "STATUS_SOFT",
    "STATUS_STRONG",
    "DeprecationFlag",
    "classify",
    "classify_all",
]
