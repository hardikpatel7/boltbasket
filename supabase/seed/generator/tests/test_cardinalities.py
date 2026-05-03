"""Run the full generator and verify total row counts."""
import re
from pathlib import Path

import pytest

from generator import (
    operational, users, inventory, orders, engagement, advertising, orphans, config,
)

WRITERS = [
    ("02a_operational_baseline.sql", operational.write, "operational"),
    ("02b_users.sql", users.write, "users"),
    ("02c_inventory.sql", inventory.write, "inventory"),
    ("02d_orders.sql", orders.write, "orders"),
    ("02e_engagement.sql", engagement.write, "engagement"),
    ("02f_advertising.sql", advertising.write, "advertising"),
    ("02g_orphans.sql", orphans.write, "orphans"),
]


def _count_inserts_per_table(text: str) -> dict[str, int]:
    """Count tuples per `-- <table>: N rows` comment block."""
    counts: dict[str, int] = {}
    for m in re.finditer(r"-- (\w+): (\d+) rows", text):
        counts[m.group(1)] = int(m.group(2))
    return counts


@pytest.mark.parametrize("filename,writer,module", WRITERS)
def test_per_module_cardinalities_within_2pct(tmp_path, filename, writer, module):
    p = tmp_path / filename
    writer(p)
    counts = _count_inserts_per_table(p.read_text())
    for table, expected in config.CARDINALITIES[module].items():
        assert table in counts, f"{module}: missing table {table} in {filename}"
        actual = counts[table]
        tolerance = max(2, int(expected * 0.02))
        assert abs(actual - expected) <= tolerance, (
            f"{module}.{table}: actual={actual} expected={expected} (±{tolerance})"
        )


def test_total_rows_in_target_range(tmp_path):
    total = 0
    for filename, writer, _ in WRITERS:
        p = tmp_path / filename
        writer(p)
        counts = _count_inserts_per_table(p.read_text())
        total += sum(counts.values())
    assert 200_000 <= total <= 220_000, f"total={total} outside 200K-220K"
