"""Generates 02d_orders.sql.

Carts → orders → order_items → order_events → payments → refunds.
References from prior phases:
  - users (02b): bulk user_ids start at 6, count 3500
  - dark_stores (smoke): 1..12
  - riders (02a): bulk rider_ids 4..53 (50 bulk riders)
  - addresses (02b): bulk address_ids start at 6
  - products (smoke): product_id 1..10 (BASE_PRICES + PRODUCT_NAMES from generator.products)
"""
from datetime import datetime, timedelta, time, date
from pathlib import Path
import math

from generator import common, config, products

IST = common.IST

# --- ID ranges ---
BULK_USER_IDS = list(range(
    config.SMOKE_MAX_USER_ID + 1,
    config.SMOKE_MAX_USER_ID + 1 + config.CARDINALITIES["users"]["users"],
))
BULK_ADDRESS_IDS = list(range(
    config.SMOKE_MAX_ADDRESS_ID + 1,
    config.SMOKE_MAX_ADDRESS_ID + 1 + config.CARDINALITIES["users"]["addresses"],
))
BULK_RIDER_IDS = list(range(
    config.SMOKE_MAX_RIDER_ID + 1,
    config.SMOKE_MAX_RIDER_ID + 1 + config.CARDINALITIES["operational"]["riders"],
))
DARK_STORE_IDS = list(range(1, 13))
ACTIVE_PRODUCT_IDS = products.ACTIVE_PRODUCT_IDS

# Hour-of-day distribution (favors lunch + dinner peaks)
HOUR_DIST = {
    0: 0.001, 1: 0.001, 2: 0.001, 3: 0.001, 4: 0.001, 5: 0.001,
    6: 0.005, 7: 0.015, 8: 0.04,  9: 0.06,  10: 0.05, 11: 0.04,
    12: 0.10, 13: 0.09, 14: 0.06, 15: 0.04, 16: 0.04, 17: 0.05,
    18: 0.06, 19: 0.10, 20: 0.10, 21: 0.07, 22: 0.04, 23: 0.02,
}

# Smoke seed order codes to never collide with
_SMOKE_ORDER_CODES = frozenset({
    "BB-20251012-000001",
    "BB-20251013-000002",
    "BB-20231215-000003",
})


def write(path: Path) -> None:
    rng = common.get_rng("orders")

    # --- Carts ---
    n_carts = config.CARDINALITIES["orders"]["carts"]
    carts: list[tuple] = []
    converted_cart_ids: list[int] = []   # cart_ids that became orders
    for i in range(n_carts):
        cart_offset = i + 1
        cart_id = config.SMOKE_MAX_CART_ID + cart_offset
        user_id = int(rng.choice(BULK_USER_IDS))
        store_id = int(rng.choice(DARK_STORE_IDS))
        is_converted = rng.random() < 0.77
        if is_converted:
            status = "converted"
            converted_cart_ids.append(cart_id)
        else:
            status = "abandoned"
        item_count = int(rng.integers(1, 8))
        subtotal = round(float(rng.uniform(99, 1499)), 2)
        created = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END, HOUR_DIST,
        )
        updated = created + timedelta(minutes=int(rng.integers(2, 60)))
        abandoned_at = updated if status == "abandoned" else None
        converted_at = updated if status == "converted" else None
        carts.append((
            user_id, store_id, status, item_count, subtotal,
            created, updated, abandoned_at, converted_at,
        ))

    # --- Orders ---
    n_orders = config.CARDINALITIES["orders"]["orders"]
    orders_rows: list[tuple] = []
    order_metadata: list[dict] = []
    cart_pool = converted_cart_ids.copy()
    rng.shuffle(cart_pool)
    cart_idx = 0
    used_codes: set[str] = set()

    for i in range(n_orders):
        order_offset = i + 1
        order_id = config.SMOKE_MAX_ORDER_ID + order_offset

        if rng.random() < 0.97 and cart_idx < len(cart_pool):
            cart_id = cart_pool[cart_idx]
            cart_idx += 1
        else:
            cart_id = None

        user_id = int(rng.choice(BULK_USER_IDS))
        store_id = int(rng.choice(DARK_STORE_IDS))
        delivery_address_id = int(rng.choice(BULK_ADDRESS_IDS))
        rider_id = int(rng.choice(BULK_RIDER_IDS))

        placed_at = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END, HOUR_DIST,
        )
        date_str = placed_at.strftime("%Y%m%d")
        seq = order_offset
        order_code = f"BB-{date_str}-{seq:06d}"
        suffix = 0
        while order_code in used_codes or order_code in _SMOKE_ORDER_CODES:
            suffix += 1
            order_code = f"BB-{date_str}-{(seq + suffix * n_orders):06d}"
        used_codes.add(order_code)

        confirmed_at = placed_at + timedelta(seconds=int(rng.integers(15, 90)))
        picked_at = placed_at + timedelta(minutes=int(rng.integers(3, 8)))
        delivered_at = placed_at + timedelta(minutes=int(rng.integers(8, 25)))

        subtotal = round(float(rng.uniform(99, 999)), 2)
        discount = 0.0 if rng.random() < 0.7 else round(subtotal * 0.10, 2)
        delivery_fee = 0.0 if rng.random() < 0.6 else 15.0
        tax = round(subtotal * 0.05, 2)
        total = round(subtotal - discount + delivery_fee + tax, 2)

        promised_min = int(rng.choice([12, 15, 18]))
        actual_min = int((delivered_at - placed_at).total_seconds() // 60)

        orders_rows.append((
            order_code, user_id, cart_id, store_id, delivery_address_id, rider_id,
            "delivered", subtotal, discount, delivery_fee, tax, total,
            placed_at, confirmed_at, picked_at, delivered_at, None,
            promised_min, actual_min, None, False, False, False,
        ))
        order_metadata.append({
            "order_id": order_id,
            "store_id": store_id,
            "rider_id": rider_id,
            "subtotal": subtotal,
            "total_amount": total,
            "placed_at": placed_at,
            "confirmed_at": confirmed_at,
            "picked_at": picked_at,
            "delivered_at": delivered_at,
        })

    # --- Order items ---
    n_items_target = config.CARDINALITIES["orders"]["order_items"]
    items_per_order = [max(1, int(rng.poisson(3.0))) for _ in range(n_orders)]
    while sum(items_per_order) < n_items_target:
        items_per_order[int(rng.integers(0, n_orders))] += 1
    while sum(items_per_order) > n_items_target:
        idx = int(rng.integers(0, n_orders))
        if items_per_order[idx] > 1:
            items_per_order[idx] -= 1

    items_rows: list[tuple] = []
    for ord_idx, n in enumerate(items_per_order):
        order_id = order_metadata[ord_idx]["order_id"]
        pids = common.zipf_indices(rng, n=10, size=n, alpha=1.5)
        for pid_offset in pids:
            product_id = ACTIVE_PRODUCT_IDS[int(pid_offset)]
            name, sku, brand, category_path, mrp = products.PRODUCT_NAMES[product_id]
            unit_price = products.BASE_PRICES[product_id]
            qty_ordered = int(rng.integers(1, 4))
            qty_delivered = qty_ordered
            line_subtotal = round(unit_price * qty_ordered, 2)
            line_discount = 0.0
            line_total = line_subtotal - line_discount
            items_rows.append((
                order_id, product_id, name, sku, brand, category_path,
                unit_price, mrp, qty_ordered, qty_delivered,
                line_subtotal, line_discount, line_total, False, None,
            ))

    # --- Order events ---
    events_rows: list[tuple] = []
    for meta in order_metadata:
        order_id = meta["order_id"]
        events_rows.append((
            order_id, "placed", meta["placed_at"], "system", None, {},
        ))
        events_rows.append((
            order_id, "confirmed", meta["confirmed_at"], "system", None, {},
        ))
        events_rows.append((
            order_id, "picked", meta["picked_at"], "employee",
            int(rng.integers(1, 15)), {},
        ))
        if rng.random() < 0.25:
            events_rows.append((
                order_id, "packed", meta["picked_at"] + timedelta(minutes=1),
                "employee", int(rng.integers(1, 15)), {},
            ))
        events_rows.append((
            order_id, "delivered", meta["delivered_at"],
            "rider", meta["rider_id"], {},
        ))

    target_events = config.CARDINALITIES["orders"]["order_events"]
    # Trim by removing only optional 'packed' events. Mandatory lifecycle
    # events (placed/confirmed/picked/delivered) must remain on every order
    # so downstream event-sourcing analysis can reconstruct order state.
    while len(events_rows) > target_events:
        packed_indices = [i for i, r in enumerate(events_rows) if r[1] == "packed"]
        if not packed_indices:
            break  # cannot trim further without breaking mandatory lifecycle
        events_rows.pop(packed_indices[int(rng.integers(0, len(packed_indices)))])
    while len(events_rows) < target_events:
        idx = int(rng.integers(0, len(order_metadata)))
        meta = order_metadata[idx]
        events_rows.append((
            meta["order_id"], "rider_assigned",
            meta["picked_at"] - timedelta(seconds=30),
            "system", None, {"rider_id": meta["rider_id"]},
        ))

    # --- Payments ---
    # payment.amount = order.total_amount (must reconcile, otherwise mart
    # queries summing payments cannot match orders.total_amount).
    payments_rows: list[tuple] = []
    methods = ["upi", "card", "wallet", "cod", "netbanking", "plus_credit"]
    method_weights = [0.55, 0.20, 0.10, 0.08, 0.05, 0.02]
    for meta in order_metadata:
        method = methods[int(rng.choice(6, p=method_weights))]
        amount = meta["total_amount"]
        payments_rows.append((
            meta["order_id"], method, round(amount, 2), "success",
            f"PAY-{meta['order_id']:08d}",
            meta["placed_at"], meta["confirmed_at"], None,
        ))

    # --- Refunds ---
    n_refunds = config.CARDINALITIES["orders"]["refunds"]
    refund_indices = rng.choice(len(order_metadata), size=n_refunds, replace=False)
    refunds_rows: list[tuple] = []
    refund_reasons = ["damaged_item", "wrong_item", "missing_item", "delivery_delay"]
    for idx in refund_indices:
        meta = order_metadata[int(idx)]
        order_id = meta["order_id"]
        # Payments are inserted in order_metadata order, so the i-th payment
        # corresponds to the i-th order. Offset by SMOKE_MAX_PAYMENT_ID so this
        # stays correct if the smoke seed ever starts inserting payments.
        payment_id = config.SMOKE_MAX_PAYMENT_ID + int(idx) + 1
        rtype = ["full", "partial", "item_level"][int(rng.choice(3, p=[0.2, 0.3, 0.5]))]
        # Refund amount can never exceed the original payment.
        raw_amount = round(float(rng.uniform(50, 500)), 2)
        amount = min(raw_amount, meta["total_amount"])
        reason = refund_reasons[int(rng.choice(4))]
        initiated = meta["delivered_at"] + timedelta(minutes=int(rng.integers(5, 240)))
        processed = initiated + timedelta(hours=int(rng.integers(1, 48)))
        refunds_rows.append((
            order_id, payment_id, rtype, amount, reason,
            initiated, processed, "completed",
        ))

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02d orders (transactional core)",
        owns_imperfection="None directly (smoke seed owns #5, #6, #12 demos)",
        sections=[
            ("carts",
             ["user_id", "dark_store_id", "status", "item_count", "subtotal",
              "created_at", "updated_at", "abandoned_at", "converted_at"],
             carts),
            ("orders",
             ["order_code", "user_id", "cart_id", "dark_store_id",
              "delivery_address_id", "rider_id", "current_status",
              "subtotal", "discount_amount", "delivery_fee", "tax_amount", "total_amount",
              "placed_at", "confirmed_at", "picked_at", "delivered_at", "cancelled_at",
              "promised_minutes", "actual_minutes", "cancellation_reason",
              "was_substituted", "is_first_order", "used_subscription_benefit"],
             orders_rows),
            ("order_items",
             ["order_id", "product_id", "product_name_snapshot", "product_sku_snapshot",
              "brand_name_snapshot", "category_path_snapshot",
              "unit_price_snapshot", "mrp_snapshot",
              "quantity_ordered", "quantity_delivered",
              "line_subtotal", "line_discount", "line_total",
              "was_substituted", "substitute_product_id"],
             items_rows),
            ("order_events",
             ["order_id", "event_type", "occurred_at", "actor_type", "actor_id", "metadata"],
             events_rows),
            ("payments",
             ["order_id", "payment_method", "amount", "status", "provider_ref",
              "attempted_at", "completed_at", "failure_reason"],
             payments_rows),
            ("refunds",
             ["order_id", "payment_id", "refund_type", "amount", "reason",
              "initiated_at", "processed_at", "status"],
             refunds_rows),
        ],
        extra_header_lines=[
            f"Bulk order_id range: {config.SMOKE_MAX_ORDER_ID + 1}..{config.SMOKE_MAX_ORDER_ID + n_orders}",
            "All orders are status='delivered' (simplest stable state).",
        ],
    )
