"""Generates 02e_engagement.sql.

Owns Imperfection #8: app_events.properties JSONB chaos.
"""
import uuid
from datetime import datetime, timedelta, time
from pathlib import Path

from generator import common, config

IST = common.IST

EVENT_TYPES = [
    "app_open", "screen_view", "search", "product_view",
    "add_to_cart", "remove_from_cart", "checkout_started",
    "order_placed", "push_received", "push_clicked",
    "app_background", "app_close",
]
DEVICE_TYPES = ["android", "ios", "web"]
DEVICE_WEIGHTS = [0.65, 0.30, 0.05]

BULK_USER_IDS = list(range(
    config.SMOKE_MAX_USER_ID + 1,
    config.SMOKE_MAX_USER_ID + 1 + config.CARDINALITIES["users"]["users"],
))

# Large pool of misc keys that contribute to ~600 distinct key count.
# Grouped by theme so they look organic in an analytics event schema.
_MISC_KEYS = [
    # User / session context
    "user_segment", "user_tier", "user_cohort", "city_code", "store_zone",
    "device_model", "device_brand", "os_version", "os_name",
    "network_type", "network_carrier", "network_speed_kbps",
    # A/B testing & feature flags
    "feature_flag_a", "feature_flag_b", "feature_flag_c",
    "experiment_id", "experiment_variant", "experiment_group",
    "ab_test_bucket", "ab_test_name", "ab_test_version",
    # Attribution & campaigns
    "campaign_attribution_id", "campaign_source", "campaign_medium",
    "campaign_term", "campaign_content", "campaign_channel",
    "deeplink_path", "deeplink_source", "deeplink_campaign",
    "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term",
    "referral_code", "referral_source",
    # Screen / UI
    "previous_screen", "next_screen", "scroll_depth_pct", "scroll_direction",
    "tab_index", "tab_name", "modal_name", "bottom_sheet_name",
    "viewport_width", "viewport_height", "list_position",
    # Search / discovery
    "filter_applied", "filter_value", "sort_order", "sort_field",
    "search_source", "search_variant", "autocomplete_used",
    "category_filter", "brand_filter", "price_filter_min", "price_filter_max",
    # Product / catalog
    "subcategory", "brand_name", "sku", "in_stock",
    "is_sponsored", "is_new_product", "is_express_eligible",
    "product_rating", "review_count", "discount_pct",
    # Cart / checkout
    "promo_code_entered", "promo_code_valid", "coupon_applied",
    "cart_item_count", "checkout_step", "payment_method_shown",
    "address_autofilled", "delivery_slot_chosen",
    # Notifications
    "notification_id", "notification_channel", "notification_template",
    "push_delivery_ms", "badge_count",
    # Performance / telemetry
    "response_time_ms", "render_time_ms", "api_latency_ms",
    "cache_hit", "cdn_edge", "js_error", "crash_id",
    # Engagement scoring
    "engagement_score", "engagement_level", "session_depth",
    "time_on_screen_ms", "idle_time_ms", "bounce",
    # Misc operational
    "warehouse_id", "picker_id", "slot_id", "zone_id",
    "fulfillment_type", "delivery_promise_mins",
    # Legacy / stale keys still present in old clients
    "old_user_id", "v1_session", "legacy_device_id",
    "client_ts", "server_ts_offset_ms",
    # Debug / stray keys (Imperfection #8 stray keys)
    "debug", "_test", "_internal", "tmp_flag", "exp_var",
    "ab_test_bucket_v2", "debug_mode", "_debug_payload",
    # More product keys with varied naming (key drift)
    "productID", "product_identifier", "item_id", "item_identifier",
    "pid", "p_id",
    # More value keys with varied naming
    "cart_total", "basket_value", "order_value", "total_value",
    "cv", "cartVal", "cart_val",
    # Screen naming variants
    "screenName", "screen_id", "screen_path", "page_name", "page_id",
    # Session variants
    "sessionId", "session_token", "sess_id",
    # Timestamps
    "client_event_time", "event_ts", "fired_at",
    # Geo
    "lat", "lng", "geo_accuracy_m", "pincode", "locality",
    # Push variants
    "fcm_token_refresh", "apns_token", "push_token_hash",
    # Order variants
    "orderId", "order_ref", "order_token",
]


def _gen_session_uuid(rng) -> str:
    """Build a deterministic UUID (uuid4 from rng bytes)."""
    raw = bytes(int(b) for b in rng.integers(0, 256, size=16))
    return str(uuid.UUID(bytes=raw, version=4))


def _gen_properties(rng, event_type: str) -> dict:
    """Build a properties JSONB blob with deliberate chaos for Imperfection #8."""
    props: dict = {}

    # --- product_id key spelling drift (70/20/10) ---
    pid_roll = int(rng.integers(0, 100))
    if pid_roll < 70:
        pid_key = "product_id"
    elif pid_roll < 90:
        pid_key = "productId"
    else:
        pid_key = "prod_id"

    # --- cart_value type drift: number 80% / "₹X" string 20% ---
    cv_as_string = rng.random() < 0.2

    # --- Chaos knobs ---
    drop_key = rng.random() < 0.05    # 5% chance to drop an expected key
    add_stray = rng.random() < 0.05   # 5% chance to add a stray key

    if event_type == "screen_view":
        if not (drop_key and rng.random() < 0.5):
            props["screen_name"] = [
                "home", "category", "product", "cart", "checkout",
            ][int(rng.integers(0, 5))]
        if not drop_key:
            props["session_duration_ms"] = int(rng.integers(100, 60_000))

    elif event_type == "search":
        props["query"] = [
            "milk", "bread", "atta", "tea", "biscuit",
            "shampoo", "yogurt",
        ][int(rng.integers(0, 7))]
        if not drop_key:
            props["result_count"] = int(rng.integers(0, 100))

    elif event_type in ("product_view", "add_to_cart", "remove_from_cart"):
        if not drop_key:
            props[pid_key] = int(rng.integers(1, 11))
        if not drop_key:
            props["category"] = [
                "dairy", "snacks", "personal_care", "atta_rice",
            ][int(rng.integers(0, 4))]

    elif event_type == "checkout_started":
        # Type drift (#8): cart_value is always present (it's the key payload of
        # this event); what varies is its *type* — numeric vs. rupee string.
        # drop_key instead drops the secondary key (item_count).
        raw_val = round(float(rng.uniform(99, 1500)), 2)
        if cv_as_string:
            props["cart_value"] = f"₹{raw_val}"
        else:
            props["cart_value"] = raw_val
        if not drop_key:
            props["item_count"] = int(rng.integers(1, 8))

    elif event_type == "order_placed":
        if not drop_key:
            props["order_total"] = round(float(rng.uniform(99, 1500)), 2)
            props[pid_key] = int(rng.integers(1, 11))

    elif event_type in ("push_received", "push_clicked"):
        props["campaign_code"] = f"PUSH_{int(rng.integers(1, 50)):03d}"

    elif event_type == "app_open":
        props["referrer"] = ["organic", "deeplink", "push", "ad"][int(rng.integers(0, 4))]
        props["app_version"] = ["4.12.0", "4.13.0", "4.14.0"][int(rng.integers(0, 3))]

    # else: app_background, app_close — minimal/empty props

    # --- Stray key (Imperfection #8) ---
    if add_stray:
        stray_keys = ["debug", "_test", "_internal", "tmp_flag", "exp_var", "ab_test_bucket"]
        props[stray_keys[int(rng.integers(0, 6))]] = "yes"

    # --- Misc keys sprinkled across events to drive distinct-key count toward ~600 ---
    # Each event has a ~30% chance of getting 1-3 additional misc keys.
    # With 30K events and a pool of ~140 misc keys, this yields
    # (0.30 * 30000 * 2) / 140 ≈ 128 exposures per key on average →
    # virtually all keys appear, giving ~140 misc + ~20 core = ~160 total,
    # well within 400-800.  To push higher we add per-row indexed variants.
    if rng.random() < 0.30:
        n_extra = int(rng.integers(1, 4))
        pool_len = len(_MISC_KEYS)
        for _ in range(n_extra):
            k = _MISC_KEYS[int(rng.integers(0, pool_len))]
            props[k] = "v"

    # --- Indexed feature-flag / experiment keys (organic distribution) ---
    # Real mobile analytics corpora typically have hundreds of feature_flag_<N>
    # and experiment_<N> keys from per-feature rollouts. We sprinkle them at
    # 5% per event to push the distinct-key count toward the ~600 the
    # imperfection #8 doc claims for the BoltBasket production corpus.
    if rng.random() < 0.05:
        roll = int(rng.integers(0, 100))
        if roll < 60:
            key_name = f"feature_flag_{int(rng.integers(0, 350))}"
        elif roll < 90:
            key_name = f"experiment_{int(rng.integers(0, 120))}_variant"
        else:
            key_name = f"rollout_{int(rng.integers(0, 80))}_bucket"
        props[key_name] = "1"

    return props


def write(path: Path) -> None:
    rng = common.get_rng("engagement")

    # --- app_events ---
    n_events = config.CARDINALITIES["engagement"]["app_events"]
    event_rows: list[tuple] = []
    sessions: list[str] = []

    # Pre-generate ~6000 unique sessions (avg 5 events/session)
    for _ in range(6_000):
        sessions.append(_gen_session_uuid(rng))

    for _ in range(n_events):
        user_id = int(rng.choice(BULK_USER_IDS)) if rng.random() < 0.85 else None
        session_id = sessions[int(rng.integers(0, len(sessions)))]
        event_type = EVENT_TYPES[int(rng.integers(0, 12))]
        event_time = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        properties = _gen_properties(rng, event_type)
        device = DEVICE_TYPES[int(rng.choice(3, p=DEVICE_WEIGHTS))]
        app_version = ["4.12.0", "4.13.0", "4.14.0"][int(rng.integers(0, 3))]
        event_rows.append((
            user_id, session_id, event_type, event_time, properties,
            device, app_version,
        ))

    # --- search_queries ---
    n_searches = config.CARDINALITIES["engagement"]["search_queries"]
    search_terms = [
        "milk", "bread", "atta", "tea", "biscuit", "shampoo",
        "yogurt", "cooking oil", "salt", "sugar", "rice",
        "noodles", "chocolate", "soap",
    ]
    search_rows: list[tuple] = []
    for _ in range(n_searches):
        user_id = int(rng.choice(BULK_USER_IDS)) if rng.random() < 0.95 else None
        session_id = sessions[int(rng.integers(0, len(sessions)))]
        query_text = search_terms[int(rng.integers(0, len(search_terms)))]
        search_at = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        result_count = int(rng.integers(0, 80))
        clicked_pid = int(rng.choice(list(range(1, 11)))) if rng.random() < 0.4 else None
        led_to_order = rng.random() < 0.15
        search_rows.append((
            user_id, session_id, query_text, search_at, result_count,
            clicked_pid, led_to_order, None,  # led_to_order_id None for simplicity
        ))

    # --- push_notifications ---
    n_pushes = config.CARDINALITIES["engagement"]["push_notifications"]
    push_titles = [
        "Your order is on its way!", "20% off snacks today",
        "Milk back in stock", "Plus members get free delivery",
        "Weekend offer", "Restock your essentials",
    ]
    push_rows: list[tuple] = []
    for i in range(n_pushes):
        user_id = int(rng.choice(BULK_USER_IDS))
        campaign_code = f"PUSH_{int(rng.integers(1, 50)):03d}"
        title = push_titles[int(rng.integers(0, len(push_titles)))]
        body = f"Special offer for you, user {user_id}"
        sent_at = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        delivered = rng.random() < 0.92
        opened = delivered and rng.random() < 0.18
        opened_at = (
            sent_at + timedelta(minutes=int(rng.integers(1, 120)))
        ) if opened else None
        led_to_order = opened and rng.random() < 0.05
        push_rows.append((
            user_id, campaign_code, title, body, sent_at,
            delivered, opened, opened_at, led_to_order, None,
        ))

    # --- pipeline_runs ---
    n_runs = config.CARDINALITIES["engagement"]["pipeline_runs"]
    pipeline_names = [
        "raw_to_staging_users", "staging_to_marts_orders",
        "daily_revenue_calc", "ad_attribution_recompute",
        "inventory_snapshot_refresh", "search_index_rebuild",
    ]
    runs_rows: list[tuple] = []
    for _ in range(n_runs):
        name = pipeline_names[int(rng.integers(0, len(pipeline_names)))]
        started = common.random_ist_datetime(
            rng, config.ACTIVITY_START, config.ACTIVITY_END,
        )
        finished = started + timedelta(seconds=int(rng.integers(30, 1800)))
        status = [
            "success", "success", "success", "success", "failed", "partial",
        ][int(rng.integers(0, 6))]
        rows_processed = int(rng.integers(100, 100_000))
        runs_rows.append((
            name, started, finished, status, rows_processed, None,
        ))

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02e engagement",
        owns_imperfection="Imperfection #8 (app_events.properties JSONB chaos)",
        sections=[
            (
                "app_events",
                [
                    "user_id", "session_id", "event_name", "event_time",
                    "properties", "device_type", "app_version",
                ],
                event_rows,
            ),
            (
                "search_queries",
                [
                    "user_id", "session_id", "query_text", "search_at",
                    "result_count", "clicked_product_id", "led_to_order",
                    "led_to_order_id",
                ],
                search_rows,
            ),
            (
                "push_notifications",
                [
                    "user_id", "campaign_code", "title", "body", "sent_at",
                    "delivered", "opened", "opened_at", "led_to_order",
                    "led_to_order_id",
                ],
                push_rows,
            ),
            (
                "pipeline_runs",
                [
                    "pipeline_name", "started_at", "finished_at", "status",
                    "rows_processed", "notes",
                ],
                runs_rows,
            ),
        ],
        extra_header_lines=[
            "Imperfection #8: app_events.properties has key-spelling drift",
            "(product_id / productId / prod_id), type drift on cart_value,",
            "missing keys ~5%, stray keys ~5%. Target distinct keys ~600.",
        ],
    )
