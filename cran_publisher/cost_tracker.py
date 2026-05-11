"""Token / cost accounting for the CRAN publisher fix loop.

Phase 5.2 runs entirely on local Gemma; cost is zero in monetary terms
but the tracker still records token counts so the operator can audit
prompt size against context-window budget. Phase 5.3 adds Claude API
escalation; the same tracker records token counts plus the dollar cost
derived from a per-model pricing table.

Pricing is injectable; the module ships with no hard-coded rates so a
mismatch with the live Anthropic schedule cannot quietly inflate the
cost numbers. The operator wires the live rates in
``ClaudePricing.from_dict({...})`` when Phase 5.3 is approved.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable


@dataclass(slots=True)
class CallRecord:
    """One LLM call captured for audit."""

    backend: str
    model: str
    input_tokens: int
    output_tokens: int
    cost_usd: float
    purpose: str = ""

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens


@dataclass(slots=True)
class ClaudePricing:
    """Per-model pricing in USD per million tokens.

    Wire the operator's currently approved rates here when Phase 5.3
    starts. Defaults are zero so a missing wiring is loud, not silent.
    """

    input_per_mtok: dict[str, float] = field(default_factory=dict)
    output_per_mtok: dict[str, float] = field(default_factory=dict)

    def cost_for(self, model: str, input_tokens: int, output_tokens: int) -> float:
        in_rate = self.input_per_mtok.get(model, 0.0)
        out_rate = self.output_per_mtok.get(model, 0.0)
        return (input_tokens * in_rate / 1_000_000.0
                + output_tokens * out_rate / 1_000_000.0)


@dataclass(slots=True)
class CostTracker:
    """Aggregate token and dollar accounting across calls.

    The tracker never makes the call itself; the orchestrator does and
    then records the outcome here. ``soft_cap_usd`` and
    ``hard_cap_usd`` are advisory: the orchestrator should consult
    :meth:`approaching_soft_cap` / :meth:`exceeded_hard_cap` between
    calls. The default caps mirror the Phase 5 operator policy ($1
    soft, $5 hard per package processed).
    """

    pricing: ClaudePricing = field(default_factory=ClaudePricing)
    soft_cap_usd: float = 1.0
    hard_cap_usd: float = 5.0
    records: list[CallRecord] = field(default_factory=list)

    def record_gemma_call(
        self,
        *,
        input_tokens: int,
        output_tokens: int,
        model: str = "gemma4:26b-fast",
        purpose: str = "",
    ) -> CallRecord:
        rec = CallRecord(
            backend="gemma_local",
            model=model,
            input_tokens=int(input_tokens),
            output_tokens=int(output_tokens),
            cost_usd=0.0,
            purpose=purpose,
        )
        self.records.append(rec)
        return rec

    def record_claude_call(
        self,
        *,
        input_tokens: int,
        output_tokens: int,
        model: str,
        purpose: str = "",
    ) -> CallRecord:
        cost = self.pricing.cost_for(model, input_tokens, output_tokens)
        rec = CallRecord(
            backend="claude_api",
            model=model,
            input_tokens=int(input_tokens),
            output_tokens=int(output_tokens),
            cost_usd=cost,
            purpose=purpose,
        )
        self.records.append(rec)
        return rec

    @property
    def total_cost_usd(self) -> float:
        return sum(r.cost_usd for r in self.records)

    @property
    def total_input_tokens(self) -> int:
        return sum(r.input_tokens for r in self.records)

    @property
    def total_output_tokens(self) -> int:
        return sum(r.output_tokens for r in self.records)

    def approaching_soft_cap(self) -> bool:
        return self.total_cost_usd >= self.soft_cap_usd

    def exceeded_hard_cap(self) -> bool:
        return self.total_cost_usd >= self.hard_cap_usd

    def summary(self) -> dict:
        return {
            "n_calls": len(self.records),
            "total_input_tokens": self.total_input_tokens,
            "total_output_tokens": self.total_output_tokens,
            "total_cost_usd": round(self.total_cost_usd, 4),
            "soft_cap_usd": self.soft_cap_usd,
            "hard_cap_usd": self.hard_cap_usd,
            "by_backend": _group_by(self.records, lambda r: r.backend),
        }


def _group_by(records: Iterable[CallRecord], key) -> dict:
    out: dict = {}
    for r in records:
        k = key(r)
        agg = out.setdefault(k, {"n_calls": 0, "input_tokens": 0,
                                  "output_tokens": 0, "cost_usd": 0.0})
        agg["n_calls"] += 1
        agg["input_tokens"] += r.input_tokens
        agg["output_tokens"] += r.output_tokens
        agg["cost_usd"] += r.cost_usd
    for v in out.values():
        v["cost_usd"] = round(v["cost_usd"], 4)
    return out


__all__ = [
    "CallRecord",
    "ClaudePricing",
    "CostTracker",
]
