"""Offline tests for Phase 3 scripts: triage filter, NAMESPACE/Rd parsers,
and SKILL.md validator.

Network-bound calls (cranlogs, CRAN tarballs, Ollama) are not exercised
here; their host scripts each have an explicit ``--snapshot`` /
``--triage`` input that this layer feeds with synthetic fixtures.
"""
from __future__ import annotations

import sys
import tarfile
import io
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import networkx as nx  # noqa: E402

from triage_top_cran import filter_candidates, existing_skill_names  # type: ignore  # noqa: E402
from extract_package_metadata import (  # type: ignore  # noqa: E402
    extract_from_tarball_bytes,
    parse_namespace,
    parse_rd,
)
from generate_skills_via_gemma import validate_skill_md  # type: ignore  # noqa: E402


# --------------------------------------------------------------------------- #
# triage_top_cran.filter_candidates
# --------------------------------------------------------------------------- #


@pytest.fixture()
def fake_graph() -> nx.MultiDiGraph:
    g = nx.MultiDiGraph()
    g.add_node("rlang", version="1.1.0", license="MIT", status="active")
    g.add_node("ggplot2", version="3.5.0", license="MIT", status="active")
    g.add_node("oldlib", version="0.0.1", license="GPL-2", status="soft_deprecated")
    g.add_node("removed", version="0.1", license="MIT", status="strong_deprecated")
    g.add_node("staleish", version="0.5", license="MIT", status="stale")
    return g


def test_filter_keeps_active_and_stale(fake_graph):
    top = [
        {"package": "rlang", "downloads_last_month": 1000},
        {"package": "ggplot2", "downloads_last_month": 900},
        {"package": "oldlib", "downloads_last_month": 700},
        {"package": "removed", "downloads_last_month": 500},
        {"package": "staleish", "downloads_last_month": 400},
    ]
    out = filter_candidates(top, fake_graph, excluded_names=set())
    names = [e["package"] for e in out]
    assert "rlang" in names
    assert "ggplot2" in names
    assert "staleish" in names
    assert "oldlib" not in names
    assert "removed" not in names


def test_filter_respects_existing_skills(fake_graph):
    top = [{"package": "rlang", "downloads_last_month": 1000}]
    out = filter_candidates(top, fake_graph, excluded_names={"rlang"})
    assert out == []


def test_filter_drops_unknown_names(fake_graph):
    top = [{"package": "not_in_graph", "downloads_last_month": 100}]
    out = filter_candidates(top, fake_graph, excluded_names=set())
    assert out == []


def test_existing_skill_names_skips_underscore_prefix(tmp_path):
    (tmp_path / "bgumbel").mkdir()
    (tmp_path / "_staging").mkdir()
    (tmp_path / ".git").mkdir()
    (tmp_path / "README.md").write_text("x", encoding="utf-8")
    names = existing_skill_names(tmp_path)
    assert names == {"bgumbel"}


# --------------------------------------------------------------------------- #
# NAMESPACE parser
# --------------------------------------------------------------------------- #


def test_parse_namespace_collects_exports():
    text = """\
export(foo)
export(bar, baz)
export("qux")
S3method(print, mything)
S3method(summary, mything)
exportPattern("^[a-z]")
"""
    exports, s3, has_pattern = parse_namespace(text)
    assert "foo" in exports
    assert "bar" in exports
    assert "baz" in exports
    assert "qux" in exports
    assert "print.mything" in s3
    assert has_pattern is True


def test_parse_namespace_empty():
    exports, s3, has_pattern = parse_namespace("")
    assert exports == []
    assert s3 == []
    assert has_pattern is False


# --------------------------------------------------------------------------- #
# Rd parser
# --------------------------------------------------------------------------- #


def test_parse_rd_extracts_blocks():
    rd = r"""
\name{foo}
\title{Compute foo}
\description{Performs the foo calculation, returning numeric.}
\examples{
foo(1, 2)
}
"""
    doc = parse_rd(rd)
    assert doc is not None
    assert doc.name == "foo"
    assert doc.title.startswith("Compute foo")
    assert "foo calculation" in doc.description
    assert "foo(1, 2)" in doc.example


def test_parse_rd_balances_nested_braces():
    rd = r"""
\name{bar}
\title{Bar with {nested} braces}
\examples{
list(a = list(b = 1))
}
"""
    doc = parse_rd(rd)
    assert doc is not None
    assert "nested" in doc.title
    assert "list(a = list(b = 1))" in doc.example


def test_parse_rd_returns_none_without_name():
    doc = parse_rd(r"\title{No name}")
    assert doc is None


def test_parse_rd_extracts_arguments_block():
    rd = r"""
\name{f}
\title{F}
\description{Describe.}
\arguments{
  \item{x}{a numeric vector}
  \item{y, z}{two related arguments}
  \item{na.rm}{logical, default FALSE}
}
\examples{
f(1)
}
"""
    doc = parse_rd(rd)
    assert doc is not None
    names = [a[0] for a in doc.arguments]
    assert names == ["x", "y", "z", "na.rm"]
    assert "numeric vector" in doc.arguments[0][1]
    assert doc.arguments[1][1] == doc.arguments[2][1]  # shared description for y, z
    assert "FALSE" in doc.arguments[3][1]


# --------------------------------------------------------------------------- #
# Tarball end-to-end (synthetic)
# --------------------------------------------------------------------------- #


def _build_synthetic_tarball() -> bytes:
    """Build a minimal CRAN-shaped source tarball in memory."""
    files = {
        "fakepkg/DESCRIPTION": (
            "Package: fakepkg\n"
            "Version: 1.0.0\n"
            "Title: Fake Test Package\n"
            "Description: A package used for offline testing of the\n"
            "    extractor. Performs nothing of note.\n"
            "License: MIT\n"
            "Author: Tester [aut, cre]\n"
            "Maintainer: Tester <test@example.com>\n"
            "Imports: Matrix, methods\n"
        ),
        "fakepkg/NAMESPACE": (
            "export(foo)\n"
            "export(bar)\n"
            "S3method(print, fakepkg)\n"
        ),
        "fakepkg/man/foo.Rd": (
            "\\name{foo}\n"
            "\\title{Compute foo}\n"
            "\\description{Performs foo.}\n"
            "\\examples{\nfoo(1)\n}\n"
        ),
        "fakepkg/man/bar.Rd": (
            "\\name{bar}\n"
            "\\title{Compute bar}\n"
            "\\description{Performs bar.}\n"
            "\\examples{\nbar(2)\n}\n"
        ),
    }
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for path, content in files.items():
            data = content.encode("utf-8")
            info = tarfile.TarInfo(name=path)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()


def test_extract_from_tarball_bytes_synthetic():
    raw = _build_synthetic_tarball()
    md = extract_from_tarball_bytes(raw, "fakepkg", "1.0.0")
    assert md.title == "Fake Test Package"
    assert md.license == "MIT"
    assert md.maintainer == "Tester <test@example.com>"
    assert "Matrix" in md.imports
    assert "foo" in md.exported_functions
    assert "bar" in md.exported_functions
    assert "print.fakepkg" in md.s3_methods
    assert any(d.name == "foo" for d in md.function_docs)
    assert any(d.name == "bar" for d in md.function_docs)


def _build_tarball_with_test_fixtures() -> bytes:
    """Build a tarball that mimics Rcpp's pattern: multiple NAMESPACE and
    DESCRIPTION files, with test fixtures under ``inst/``. The real metadata
    must win over fixture metadata.
    """
    files = {
        "fakepkg/DESCRIPTION": (
            "Package: fakepkg\nVersion: 1.0.0\nTitle: Real Package\n"
            "License: MIT\nMaintainer: Real <real@example.com>\n"
        ),
        "fakepkg/NAMESPACE": "export(real_export_one)\nexport(real_export_two)\n",
        "fakepkg/man/real_export_one.Rd": (
            "\\name{real_export_one}\n\\title{Real}\n\\description{Real fn.}\n"
        ),
        # Test fixtures that must be ignored:
        "fakepkg/inst/tinytest/testFakepkg/DESCRIPTION": (
            "Package: fixturepkg\nVersion: 0.0.0\nTitle: Fixture\n"
            "License: GPL-2\nMaintainer: Fixture <fixture@example.com>\n"
        ),
        "fakepkg/inst/tinytest/testFakepkg/NAMESPACE": "export(fixture_export)\n",
        "fakepkg/inst/tinytest/testFakepkg/man/fixture_export.Rd": (
            "\\name{fixture_export}\n\\title{Fixture}\n\\description{Fixture.}\n"
        ),
    }
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for path, content in files.items():
            data = content.encode("utf-8")
            info = tarfile.TarInfo(name=path)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()


def test_extract_ignores_inst_fixtures():
    """Real top-level metadata must win over /inst/ test fixtures.

    Reproduces the Rcpp-tarball pathology where multiple NAMESPACE and
    DESCRIPTION files exist and a naive walk lets the last one overwrite
    the real exports.
    """
    raw = _build_tarball_with_test_fixtures()
    md = extract_from_tarball_bytes(raw, "fakepkg", "1.0.0")
    assert md.title == "Real Package"
    assert md.maintainer == "Real <real@example.com>"
    assert md.license == "MIT"
    assert "real_export_one" in md.exported_functions
    assert "real_export_two" in md.exported_functions
    assert "fixture_export" not in md.exported_functions
    rd_names = {d.name for d in md.function_docs}
    assert "real_export_one" in rd_names
    assert "fixture_export" not in rd_names


# --------------------------------------------------------------------------- #
# validate_skill_md
# --------------------------------------------------------------------------- #


def test_validate_skill_md_accepts_well_formed():
    text = """---
name: pkg
runtime: r
package: pkg
package_source: CRAN
package_url: https://cran.r-project.org/package=pkg
package_version_pinned: ">=1.0"
license: MIT
maintainer: "Me <me@ex.com>"
---

# Skill: pkg

Body.

## Functions exposed

### `foo`

**Input**

```json
{}
```

**Output**

```json
{}
```

## When to invoke

- task A
"""
    res = validate_skill_md(text, "pkg")
    assert res.ok, res.issues


def test_validate_skill_md_flags_missing_frontmatter():
    res = validate_skill_md("# Skill: pkg\n\nbody", "pkg")
    assert not res.ok
    assert "missing_yaml_frontmatter" in res.issues


def test_validate_skill_md_flags_em_dash():
    em = chr(0x2014)
    text = f"""---
name: pkg
runtime: r
package: pkg
---

# Skill: pkg

This sentence has {em} an em-dash.

## Functions exposed
### `foo`
## When to invoke
- a
"""
    res = validate_skill_md(text, "pkg")
    assert "contains_em_dash" in res.issues


def test_validate_skill_md_flags_forbidden_terms():
    text = """---
name: pkg
runtime: r
package: pkg
---

# Skill: pkg

This is a crucial wrapper for the pkg package.

## Functions exposed
### `foo`
## When to invoke
- a
"""
    res = validate_skill_md(text, "pkg")
    assert "contains_forbidden_term:crucial" in res.issues


def test_validate_skill_md_flags_wrong_package_field():
    text = """---
name: other
runtime: r
package: other
---

# Skill: other

## Functions exposed
### `foo`
## When to invoke
- a
"""
    res = validate_skill_md(text, "expected_pkg")
    assert "missing_or_wrong_package_field" in res.issues
    assert "missing_or_wrong_name_field" in res.issues
