"""Tests for operational module (02a)."""
from pathlib import Path

import pytest

from generator import operational, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02a_operational_baseline.sql"


def test_write_creates_file(out_path):
    operational.write(out_path)
    assert out_path.exists()


def test_riders_block_contains_50_rows(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    insert_block = text.split("-- riders: ")[1].split("\n\n")[0]
    rider_lines = [ln for ln in insert_block.splitlines() if ln.startswith("  ('BB-RDR-")]
    assert len(rider_lines) == 50


def test_rider_ids_start_after_smoke_max(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    # smoke has BB-RDR-00001/2/3, so bulk should start at BB-RDR-00004
    assert "'BB-RDR-00004'" in text
    assert "'BB-RDR-00003'" not in text  # not in this file


def test_ad_campaigns_count(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_campaigns: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["operational"]["ad_campaigns"]


def test_price_lists_have_three_scope_types(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    pl_section = text.split("-- price_lists: ")[1].split("\n\n")[0]
    assert "'global'" in pl_section
    assert "'city'" in pl_section
    assert "'store'" in pl_section


def test_imperfection_7_overlap_count(out_path):
    """At least 10 products appear in all 3 scope types (global + city + store)."""
    operational.write(out_path)
    text = out_path.read_text()

    pl_section = text.split("-- price_lists: ")[1].split("\n\n")[0]
    pli_section = text.split("-- price_list_items: ")[1].split("\n\n")[0]

    import re
    items: list[tuple[int, int]] = []
    for ln in pli_section.splitlines():
        m = re.match(r"\s*\(\s*(\d+),\s*(\d+),", ln)
        if m:
            items.append((int(m.group(1)), int(m.group(2))))

    # build map of price_list_id → scope_type by matching position in pl_section to scope_type
    pl_scopes: dict[int, str] = {}
    pl_scope_re = re.compile(r"'(global|city|store)'")
    pl_position = 1
    for ln in pl_section.splitlines():
        if ln.startswith("  ("):
            m = pl_scope_re.search(ln)
            if m:
                pl_scopes[pl_position] = m.group(1)
                pl_position += 1

    # for each product_id, collect set of scope_types it belongs to
    prod_scopes: dict[int, set[str]] = {}
    for pl_id, prod_id in items:
        prod_scopes.setdefault(prod_id, set()).add(pl_scopes.get(pl_id, "?"))

    triple_overlap = sum(1 for s in prod_scopes.values() if {"global", "city", "store"}.issubset(s))
    assert triple_overlap >= 10, f"only {triple_overlap} products in all 3 scopes; expected ≥10"


def test_deterministic_run(out_path, tmp_path):
    p1 = tmp_path / "run1.sql"
    p2 = tmp_path / "run2.sql"
    operational.write(p1)
    operational.write(p2)
    assert p1.read_text() == p2.read_text()
