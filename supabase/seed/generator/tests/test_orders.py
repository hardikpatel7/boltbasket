import re
from pathlib import Path

import pytest
from generator import orders, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02d_orders.sql"


def test_order_count(out_path):
    orders.write(out_path)
    text = out_path.read_text()
    section = text.split("-- orders: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["orders"]["orders"]


def test_order_codes_avoid_smoke_codes(out_path):
    orders.write(out_path)
    text = out_path.read_text()
    for forbidden in ("BB-20251012-000001", "BB-20251013-000002", "BB-20231215-000003"):
        assert forbidden not in text


def test_order_items_avg_per_order_close_to_3(out_path):
    orders.write(out_path)
    text = out_path.read_text()
    items_section = text.split("-- order_items: ")[1].split("\n\n")[0]
    item_rows = [ln for ln in items_section.splitlines() if ln.startswith("  (")]
    n_orders = config.CARDINALITIES["orders"]["orders"]
    avg = len(item_rows) / n_orders
    assert 2.8 <= avg <= 3.2, f"items/order avg = {avg}"


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    orders.write(p1)
    orders.write(p2)
    assert p1.read_text() == p2.read_text()


def test_every_order_has_mandatory_lifecycle_events(out_path):
    """Mandatory events (placed/confirmed/picked/delivered) must survive the trim."""
    orders.write(out_path)
    text = out_path.read_text()
    events_section = text.split("-- order_events: ")[1].split("\n\n")[0]
    placed_orders: set[int] = set()
    confirmed_orders: set[int] = set()
    picked_orders: set[int] = set()
    delivered_orders: set[int] = set()
    for ln in events_section.splitlines():
        m = re.match(r"\s*\((\d+),\s*'(\w+)',", ln)
        if not m:
            continue
        order_id, event_type = int(m.group(1)), m.group(2)
        if event_type == "placed":
            placed_orders.add(order_id)
        elif event_type == "confirmed":
            confirmed_orders.add(order_id)
        elif event_type == "picked":
            picked_orders.add(order_id)
        elif event_type == "delivered":
            delivered_orders.add(order_id)

    n_orders = config.CARDINALITIES["orders"]["orders"]
    expected = set(range(
        config.SMOKE_MAX_ORDER_ID + 1,
        config.SMOKE_MAX_ORDER_ID + 1 + n_orders,
    ))
    for label, got in [("placed", placed_orders), ("confirmed", confirmed_orders),
                       ("picked", picked_orders), ("delivered", delivered_orders)]:
        missing = expected - got
        assert not missing, f"{len(missing)} orders missing '{label}' event"
