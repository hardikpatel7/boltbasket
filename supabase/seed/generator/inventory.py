"""Generates 02c_inventory.sql.

Owns Imperfection #3: snapshot/log drift. For 5 of 120 (store, product) cells,
the store_inventory.quantity_on_hand DELIBERATELY does not match the sum of
inventory_movements.quantity_change for that cell.
"""
from datetime import datetime, timedelta, time
from pathlib import Path

from generator import common, config

IST = common.IST

STORE_IDS = list(range(1, 13))         # 12 dark stores from smoke seed
ACTIVE_PRODUCT_IDS = list(range(1, 11))  # 10 active products from smoke seed


def write(path: Path) -> None:
    rng = common.get_rng("inventory")

    # Step 1: pick 5 cells to drift, deterministically
    all_cells = [(s, p) for s in STORE_IDS for p in ACTIVE_PRODUCT_IDS]
    drift_indices = rng.choice(len(all_cells), size=5, replace=False)
    drift_cells: dict[tuple[int, int], int] = {}
    drift_directions = [-1, -1, -1, +1, +1]  # 3 negative, 2 positive
    for sign, idx in zip(drift_directions, drift_indices):
        cell = all_cells[int(idx)]
        magnitude = int(rng.integers(2, 16))  # 2..15
        drift_cells[cell] = sign * magnitude

    # Step 2: generate movements for each cell across the window
    movements: list[tuple] = []
    snapshot_truth: dict[tuple[int, int], int] = {}

    movements_per_cell_target = (
        config.CARDINALITIES["inventory"]["inventory_movements"] // len(all_cells)
    )

    for store_id, product_id in all_cells:
        cell_qty = int(rng.integers(50, 200))   # starting quantity
        snapshot_truth[(store_id, product_id)] = cell_qty

        # Initial inbound restock at start of window
        movements.append((
            store_id, product_id, "inbound_restock", cell_qty, "initial_stock",
            "restock_pr", None,
            datetime.combine(config.ACTIVITY_START, time(6, 0), tzinfo=IST),
            None,
        ))

        # Random additional movements
        n_extra = max(1, int(rng.normal(movements_per_cell_target - 1, 5)))
        for _ in range(n_extra):
            mtype = ["outbound_order", "inbound_restock", "adjustment_loss",
                     "adjustment_count"][int(rng.choice(4, p=[0.78, 0.15, 0.04, 0.03]))]
            if mtype == "outbound_order":
                qty = -int(rng.integers(1, 6))
                ref_type, ref_id = "order_item", int(rng.integers(1, 30001))
            elif mtype == "inbound_restock":
                qty = int(rng.integers(20, 80))
                ref_type, ref_id = "restock_pr", int(rng.integers(1, 1000))
            elif mtype == "adjustment_loss":
                qty = -int(rng.integers(1, 5))
                ref_type, ref_id = "audit", None
            else:  # adjustment_count
                qty = int(rng.integers(-3, 4))
                ref_type, ref_id = "audit", None

            occurred = datetime.combine(
                config.ACTIVITY_START + timedelta(days=int(rng.integers(0, 7))),
                time(int(rng.integers(6, 23)), int(rng.integers(0, 60))),
                tzinfo=IST,
            )
            movements.append((
                store_id, product_id, mtype, qty, mtype, ref_type, ref_id,
                occurred, None,
            ))
            cell_qty += qty
        snapshot_truth[(store_id, product_id)] = max(0, cell_qty)

    # Step 3: build store_inventory rows.
    # For non-drift cells: quantity_on_hand = replay total.
    # For drift cells: quantity_on_hand = replay total + drift_delta (with floor at 0).
    inventory_rows: list[tuple] = []
    for store_id, product_id in all_cells:
        truth = snapshot_truth[(store_id, product_id)]
        delta = drift_cells.get((store_id, product_id), 0)
        on_hand = max(0, truth + delta)
        reorder_point = 20
        last_restock = datetime.combine(
            config.ACTIVITY_START, time(6, 0), tzinfo=IST,
        ) + timedelta(days=int(rng.integers(0, 7)))
        last_updated = last_restock
        inventory_rows.append((
            store_id, product_id, on_hand, 0, reorder_point,
            last_restock, last_updated, True,
        ))

    # Construct the drift comment block
    drift_lines = ["DRIFTED CELLS (Imperfection #3 — snapshot/log mismatch):"]
    for (s, p), delta in sorted(drift_cells.items()):
        sign = "+" if delta > 0 else ""
        drift_lines.append(f"drifted: (store={s}, product={p}) delta={sign}{delta}")

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02c inventory",
        owns_imperfection="Imperfection #3 (snapshot/log drift)",
        sections=[
            ("store_inventory",
             ["dark_store_id", "product_id", "quantity_on_hand", "quantity_reserved",
              "reorder_point", "last_restocked_at", "last_updated_at", "is_listed"],
             inventory_rows),
            ("inventory_movements",
             ["dark_store_id", "product_id", "movement_type", "quantity_change",
              "reason_code", "reference_type", "reference_id",
              "occurred_at", "notes"],
             movements),
        ],
        extra_header_lines=drift_lines,
    )
