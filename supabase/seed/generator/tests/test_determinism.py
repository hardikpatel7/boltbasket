"""Generate the full output twice; assert byte-identical."""
import hashlib
from pathlib import Path

import pytest

from generator import operational, users, inventory, orders, engagement, advertising, orphans

WRITERS = {
    "02a_operational_baseline.sql": operational.write,
    "02b_users.sql": users.write,
    "02c_inventory.sql": inventory.write,
    "02d_orders.sql": orders.write,
    "02e_engagement.sql": engagement.write,
    "02f_advertising.sql": advertising.write,
    "02g_orphans.sql": orphans.write,
}


@pytest.mark.parametrize("filename,writer", list(WRITERS.items()))
def test_byte_identical_across_runs(filename, writer, tmp_path):
    p1 = tmp_path / "1" / filename
    p2 = tmp_path / "2" / filename
    p1.parent.mkdir()
    p2.parent.mkdir()
    writer(p1)
    writer(p2)

    h1 = hashlib.sha256(p1.read_bytes()).hexdigest()
    h2 = hashlib.sha256(p2.read_bytes()).hexdigest()
    assert h1 == h2, f"{filename}: hashes differ"
