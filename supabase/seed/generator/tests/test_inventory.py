import re
from pathlib import Path

import pytest
from generator import inventory, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02c_inventory.sql"


def test_store_inventory_count(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    section = text.split("-- store_inventory: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["inventory"]["store_inventory"]


def test_movements_count_in_range(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    section = text.split("-- inventory_movements: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["inventory"]["inventory_movements"]
    assert abs(len(rows) - target) <= int(target * 0.02)  # ±2%


def test_drift_block_listed_in_header(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    assert "DRIFTED CELLS" in text
    drift_lines = re.findall(r"-- drifted: \(store=(\d+), product=(\d+)\) delta=([+-]\d+)", text)
    assert len(drift_lines) == 5
    deltas = [int(d) for _, _, d in drift_lines]
    assert sum(1 for d in deltas if d < 0) == 3
    assert sum(1 for d in deltas if d > 0) == 2


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    inventory.write(p1)
    inventory.write(p2)
    assert p1.read_text() == p2.read_text()
