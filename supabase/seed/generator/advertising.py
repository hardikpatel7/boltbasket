"""Generates 02f_advertising.sql.

Owns Imperfection #10: same order → multiple ad_attributions rows from
different attribution models (last_click, view_through, multi_touch_linear).
"""
import uuid
from datetime import datetime, timedelta
from pathlib import Path

from generator import common, config

IST = common.IST

BULK_ORDER_IDS = list(range(
    config.SMOKE_MAX_ORDER_ID + 1,
    config.SMOKE_MAX_ORDER_ID + 1 + config.CARDINALITIES["orders"]["orders"],
))
BULK_USER_IDS = list(range(
    config.SMOKE_MAX_USER_ID + 1,
    config.SMOKE_MAX_USER_ID + 1 + config.CARDINALITIES["users"]["users"],
))
N_CAMPAIGNS = config.CARDINALITIES["operational"]["ad_campaigns"]
N_PLACEMENTS = config.CARDINALITIES["operational"]["ad_placements"]


def _gen_session_uuid(rng) -> str:
    raw = bytes(int(b) for b in rng.integers(0, 256, size=16))
    return str(uuid.UUID(bytes=raw, version=4))


def write(path: Path) -> None:
    rng = common.get_rng("advertising")

    # --- ad_impressions ---
    n_imp = config.CARDINALITIES["advertising"]["ad_impressions"]
    imp_rows: list[tuple] = []
    for _ in range(n_imp):
        placement_id = int(rng.integers(1, N_PLACEMENTS + 1))
        user_id = int(rng.choice(BULK_USER_IDS)) if rng.random() < 0.85 else None
        session_id = _gen_session_uuid(rng)
        shown_at = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        context = {"page": "home", "position": int(rng.integers(0, 10))}
        imp_rows.append((placement_id, user_id, session_id, shown_at, context))

    # --- ad_clicks ---
    # ~10% CTR
    n_clicks = config.CARDINALITIES["advertising"]["ad_clicks"]
    click_rows: list[tuple] = []
    # Sample n_clicks impressions, randomly
    impression_indices = rng.choice(n_imp, size=n_clicks, replace=False)
    for idx in impression_indices:
        impression_id = int(idx) + 1  # SERIAL is 1-based
        # placement_id matches the impression's
        placement_id = imp_rows[int(idx)][0]
        user_id = imp_rows[int(idx)][1]
        # clicked_at = shown_at + 0..30s
        shown_at = imp_rows[int(idx)][3]
        clicked_at = shown_at + timedelta(seconds=int(rng.integers(1, 30)))
        click_rows.append((impression_id, placement_id, user_id, clicked_at))

    # --- ad_attributions (Imperfection #10) ---
    # ~30% of orders are attributable
    n_orders = len(BULK_ORDER_IDS)
    n_attributable = int(n_orders * 0.30)
    attributable_indices = rng.choice(n_orders, size=n_attributable, replace=False)
    attributable_order_ids = [BULK_ORDER_IDS[int(i)] for i in attributable_indices]

    attr_rows: list[tuple] = []
    for order_id in attributable_order_ids:
        # 100% get last_click
        campaign_id = int(rng.integers(1, N_CAMPAIGNS + 1))
        placement_id = int(rng.integers(1, N_PLACEMENTS + 1))
        attr_value = round(float(rng.uniform(20, 200)), 2)
        attr_at = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        attr_rows.append((
            order_id, campaign_id, placement_id, "last_click",
            attr_value, 1.0, 24, attr_at,
        ))

        # 10% get view_through
        if rng.random() < 0.10:
            campaign_id_vt = int(rng.integers(1, N_CAMPAIGNS + 1))
            placement_id_vt = int(rng.integers(1, N_PLACEMENTS + 1))
            attr_rows.append((
                order_id, campaign_id_vt, placement_id_vt, "view_through",
                round(attr_value * 0.6, 2), 1.0, 24, attr_at,
            ))

        # 5% get multi_touch_linear (1-3 rows weighted to sum to 1.0)
        if rng.random() < 0.05:
            n_touches = int(rng.integers(1, 4))
            weight_each = round(1.0 / n_touches, 4)
            # Adjust the last weight to make the sum exactly 1.0
            weights = [weight_each] * (n_touches - 1)
            weights.append(round(1.0 - sum(weights), 4))
            for w in weights:
                cmp_id = int(rng.integers(1, N_CAMPAIGNS + 1))
                pl_id = int(rng.integers(1, N_PLACEMENTS + 1))
                attr_rows.append((
                    order_id, cmp_id, pl_id, "multi_touch_linear",
                    round(attr_value * w, 2), w, 24, attr_at,
                ))

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02f advertising",
        owns_imperfection="Imperfection #10 (multi-model ad_attributions)",
        sections=[
            ("ad_impressions",
             ["placement_id", "user_id", "session_id", "shown_at", "context"],
             imp_rows),
            ("ad_clicks",
             ["impression_id", "placement_id", "user_id", "clicked_at"],
             click_rows),
            ("ad_attributions",
             ["order_id", "campaign_id", "placement_id", "attribution_model",
              "attributed_value", "attributed_weight",
              "attribution_window_hours", "attributed_at"],
             attr_rows),
        ],
        extra_header_lines=[
            "Imperfection #10: ~30% of orders attributable, with same",
            "order_id appearing under multiple attribution_model values.",
            "100% last_click, 10% view_through, 5% multi_touch_linear.",
        ],
    )
