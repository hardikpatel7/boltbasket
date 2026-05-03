import re
import json
from pathlib import Path

import pytest
from generator import engagement, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02e_engagement.sql"


def test_app_events_count(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    section = text.split("-- app_events: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["engagement"]["app_events"]
    assert abs(len(rows) - target) <= int(target * 0.02)


def test_jsonb_has_key_spelling_drift(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    # We expect to see all three spellings somewhere
    assert "\"product_id\"" in text or '"product_id"' in text
    assert "\"productId\"" in text or '"productId"' in text
    assert "\"prod_id\"" in text or '"prod_id"' in text


def test_jsonb_has_rupee_string_for_cart_value(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    # Some cart_value is a string with rupee symbol
    assert "₹" in text


def test_distinct_key_count(out_path):
    """Approximate count of distinct keys across all properties. Target ~600."""
    engagement.write(out_path)
    text = out_path.read_text()
    # Extract all JSONB literals in app_events section
    section = text.split("-- app_events: ")[1].split("\n\n")[0]
    keys = set()
    # crude regex: keys are quoted, followed by colon
    for m in re.finditer(r'\"([a-zA-Z_][a-zA-Z0-9_]*)\"\s*:', section):
        keys.add(m.group(1))
    # Allow 400-800 range (target 600)
    assert 400 <= len(keys) <= 800, f"distinct keys = {len(keys)}; expected 400-800"


def test_pipeline_runs_count(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    section = text.split("-- pipeline_runs: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["engagement"]["pipeline_runs"]


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    engagement.write(p1)
    engagement.write(p2)
    assert p1.read_text() == p2.read_text()
