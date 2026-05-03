"""Generates 02a_operational_baseline.sql.

Owns Imperfection #7: price_list scope overlaps. The 10 base products will each
appear in 3 price_lists (one global, one city, one store) so the 'most specific
wins' rule has data to chew on.
"""
from datetime import date, datetime, timedelta, time
from pathlib import Path
from zoneinfo import ZoneInfo

from generator import common, config, products

IST = ZoneInfo("Asia/Kolkata")
ANCHOR = config.ANCHOR_DATE
WINDOW_START = config.ACTIVITY_START

# All 13 brands from smoke seed (brand_id 1..13). Hardcoded — must match smoke.
BRAND_IDS = list(range(1, 14))

# All 12 dark stores from smoke seed (dark_store_id 1..12)
STORE_IDS = list(range(1, 13))

# Cities (city_id 1..3)
CITY_IDS = [1, 2, 3]

# Active products from the shared products module (canonical for the generator)
ACTIVE_PRODUCT_IDS = products.ACTIVE_PRODUCT_IDS


def _generate_riders():
    """50 riders: rider_ids 4..53 (smoke holds 1..3)."""
    rng = common.get_rng("operational.riders")
    faker = common.get_faker("operational.riders")
    rider_types = ["gig", "payroll"]
    vehicle_types = ["bike", "scooter", "cycle", "on_foot"]
    rider_type_weights = [0.7, 0.3]
    vehicle_weights = [0.55, 0.30, 0.10, 0.05]

    rows = []
    start_id = config.SMOKE_MAX_RIDER_ID + 1  # 4
    for i in range(50):
        rider_id_offset = i  # for rider_code numbering
        code_num = start_id + rider_id_offset
        rider_code = f"BB-RDR-{code_num:05d}"
        full_name = faker.name()
        # phone: +919876500004..+919876500053 (smoke uses 00001-3)
        phone = f"+91987650{code_num:04d}"
        city_id = int(rng.choice(CITY_IDS, p=[0.50, 0.35, 0.15]))
        # primary store from city
        city_stores = {1: list(range(1, 7)), 2: list(range(7, 11)), 3: list(range(11, 13))}
        primary_store = int(rng.choice(city_stores[city_id]))
        rider_type = rider_types[int(rng.choice(2, p=rider_type_weights))]
        vehicle_type = vehicle_types[int(rng.choice(4, p=vehicle_weights))]
        joined_offset_days = int(rng.integers(60, 720))  # 2 mo to 2 yr ago
        joined_at = ANCHOR - timedelta(days=joined_offset_days)
        rating = round(float(rng.uniform(4.2, 4.95)), 2)
        total_deliveries = int(rng.integers(50, 1500))
        rows.append((
            rider_code, full_name, phone, city_id, primary_store,
            rider_type, vehicle_type, True, joined_at, rating, total_deliveries,
        ))
    return rows


def _generate_ad_campaigns():
    """20 campaigns across the 13 brands."""
    rng = common.get_rng("operational.campaigns")
    faker = common.get_faker("operational.campaigns")
    types = ["search_sponsored", "banner", "push_notification",
             "category_takeover", "product_listing_ads"]

    rows = []
    for i in range(config.CARDINALITIES["operational"]["ad_campaigns"]):
        brand_id = int(rng.choice(BRAND_IDS))
        campaign_type = types[int(rng.choice(5))]
        budget = round(float(rng.uniform(50_000, 500_000)), 2)
        spent = round(budget * float(rng.uniform(0.0, 0.85)), 2)
        starts = datetime.combine(
            ANCHOR - timedelta(days=int(rng.integers(2, 14))),
            time(0, 0), tzinfo=IST,
        )
        ends = starts + timedelta(days=int(rng.integers(7, 30)))
        status = "active" if ends.date() >= WINDOW_START else "ended"
        targeting = {"min_user_age_days": int(rng.integers(0, 365))}
        rows.append((
            brand_id, f"{faker.bs().title()[:40]} Campaign", campaign_type,
            budget, spent, starts, ends, status, targeting,
        ))
    return rows


def _generate_ad_placements(num_campaigns: int):
    """60 placements (~3 per campaign)."""
    rng = common.get_rng("operational.placements")
    types = ["home_banner", "category_banner", "search_result",
             "product_detail_recommended", "cart_recommended", "push"]
    bid_types = ["cpm", "cpc", "cpa"]
    rows = []
    for i in range(config.CARDINALITIES["operational"]["ad_placements"]):
        campaign_id = int(rng.integers(1, num_campaigns + 1))
        placement_type = types[int(rng.choice(6))]
        bid_type = bid_types[int(rng.choice(3))]
        bid_amount = round(float(rng.uniform(0.5, 50.0)), 2)
        # ~30% are SKU-level
        product_id = int(rng.choice(ACTIVE_PRODUCT_IDS)) if rng.random() < 0.3 else None
        rows.append((
            campaign_id, placement_type, product_id, bid_amount, bid_type, True,
        ))
    return rows


def _generate_promotions():
    """25 promotions, varied types + time bounds."""
    rng = common.get_rng("operational.promotions")
    types = ["flat_discount", "percent_discount", "free_delivery",
             "bogo", "category_discount", "first_order_bonus"]
    rows = []
    for i in range(config.CARDINALITIES["operational"]["promotions"]):
        code = f"PROMO{i+1:03d}"
        name = f"Test Promotion {i+1}"
        ptype = types[int(rng.choice(6))]
        if ptype == "flat_discount":
            discount = round(float(rng.uniform(20, 200)), 2)
        elif ptype == "percent_discount":
            discount = round(float(rng.uniform(5, 25)), 2)
        else:
            discount = 0.0
        min_order = round(float(rng.uniform(99, 499)), 2)
        max_disc = round(float(rng.uniform(50, 250)), 2)
        starts = datetime.combine(
            ANCHOR - timedelta(days=int(rng.integers(0, 10))), time(0, 0), tzinfo=IST,
        )
        ends = starts + timedelta(days=int(rng.integers(3, 21)))
        budget = round(float(rng.uniform(50_000, 300_000)), 2)
        spent = round(budget * float(rng.uniform(0.0, 0.7)), 2)
        rules = {"applies_to": "all_users"}
        rows.append((
            code, name, ptype, discount, min_order, max_disc, rules,
            starts, ends, True, budget, spent,
        ))
    return rows


def _generate_price_lists():
    """15 price_lists with deliberate scope overlap (Imperfection #7).

    Allocation:
        - 1 global (active for whole window)
        - 6 city (2 per city, varying time bounds)
        - 8 store (chosen from 12 stores; varying time bounds)
    Total = 15.
    """
    rng = common.get_rng("operational.price_lists")
    rows = []

    # 1 global, always active across window
    starts = datetime.combine(WINDOW_START, time(0, 0), tzinfo=IST)
    ends = datetime.combine(ANCHOR + timedelta(days=14), time(23, 59, 59), tzinfo=IST)
    rows.append(("Global Festive Pricing", "global", None, starts, ends, True))

    # 6 city: 2 per city
    for city_id in CITY_IDS:
        for n in range(2):
            offset_start = int(rng.integers(0, 5))
            duration = int(rng.integers(2, 7))
            s = datetime.combine(WINDOW_START + timedelta(days=offset_start), time(0, 0), tzinfo=IST)
            e = s + timedelta(days=duration)
            rows.append((
                f"{config.CITY_CODES[city_id]} Promo Wave {n+1}",
                "city", city_id, s, e, True,
            ))

    # 8 store: spread across stores
    chosen_stores = list(rng.choice(STORE_IDS, size=8, replace=False))
    for store_id in chosen_stores:
        offset_start = int(rng.integers(0, 5))
        duration = int(rng.integers(1, 5))
        s = datetime.combine(WINDOW_START + timedelta(days=offset_start), time(0, 0), tzinfo=IST)
        e = s + timedelta(days=duration)
        rows.append((
            f"Store {store_id} Premium Pricing",
            "store", int(store_id), s, e, True,
        ))

    assert len(rows) == 15
    return rows


def _generate_price_list_items():
    """~300 items with 10 products covered by all 3 scope types simultaneously.

    Produces (price_list_id_offset, product_id, override_price, is_active) tuples
    where price_list_id_offset is 1-based offset into the price_lists order:
        1     = global
        2..7  = city
        8..15 = store
    """
    rng = common.get_rng("operational.pli")
    rows = []

    # The 10 active products will each appear in:
    #   - the 1 global price list
    #   - 1 randomly-chosen city price list (out of 6)
    #   - 1 randomly-chosen store price list (out of 8)
    # = 30 rows of guaranteed triple-overlap

    for product_id in ACTIVE_PRODUCT_IDS:
        base_price = products.BASE_PRICES[product_id]
        # Global override: ~5% off base
        override_global = round(float(rng.uniform(0.93, 0.97)) * base_price, 2)
        rows.append((1, product_id, override_global, True))

        # One city override (2..7)
        city_pl_id = int(rng.integers(2, 8))
        override_city = round(float(rng.uniform(0.90, 0.95)) * base_price, 2)
        rows.append((city_pl_id, product_id, override_city, True))

        # One store override (8..15)
        store_pl_id = int(rng.integers(8, 16))
        override_store = round(float(rng.uniform(0.85, 0.92)) * base_price, 2)
        rows.append((store_pl_id, product_id, override_store, True))

    # 30 rows so far. Fill the remaining slots up to the cap by enumerating ALL
    # valid (price_list_id, product_id) pairs, removing the ones we already have,
    # shuffling deterministically, and taking exactly enough to fill.
    # This avoids the birthday-paradox tail where random-with-rejection can
    # finish a few rows short of the cap.
    existing_pairs = {(r[0], r[1]) for r in rows}
    all_pairs = [(pl, p) for pl in range(1, 16) for p in ACTIVE_PRODUCT_IDS]
    remaining = [pair for pair in all_pairs if pair not in existing_pairs]
    needed = config.CARDINALITIES["operational"]["price_list_items"] - len(rows)
    if needed > 0:
        # Deterministic shuffle via permutation indices
        order = rng.permutation(len(remaining))
        for idx in order[:needed]:
            pl_id, product_id = remaining[int(idx)]
            override = round(
                float(rng.uniform(0.80, 0.99)) * products.BASE_PRICES[product_id], 2
            )
            rows.append((pl_id, product_id, override, True))

    return rows


def write(path: Path) -> None:
    riders = _generate_riders()
    campaigns = _generate_ad_campaigns()
    placements = _generate_ad_placements(num_campaigns=len(campaigns))
    promos = _generate_promotions()
    price_lists = _generate_price_lists()
    price_list_items = _generate_price_list_items()

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02a operational baseline",
        owns_imperfection="Imperfection #7 (price_list scope overlap)",
        sections=[
            ("riders",
             ["rider_code", "full_name", "phone", "city_id", "primary_dark_store_id",
              "rider_type", "vehicle_type", "is_active", "joined_at", "rating",
              "total_deliveries"],
             riders),
            ("ad_campaigns",
             ["brand_id", "campaign_name", "campaign_type",
              "total_budget", "spent_so_far", "starts_at", "ends_at", "status",
              "targeting_rules"],
             campaigns),
            ("ad_placements",
             ["campaign_id", "placement_type", "product_id", "bid_amount",
              "bid_type", "is_active"],
             placements),
            ("promotions",
             ["promo_code", "promo_name", "promo_type", "discount_value",
              "min_order_value", "max_discount", "eligibility_rules",
              "starts_at", "ends_at", "is_active", "total_budget", "spent_so_far"],
             promos),
            ("price_lists",
             ["list_name", "scope_type", "scope_id", "starts_at", "ends_at", "is_active"],
             price_lists),
            ("price_list_items",
             ["price_list_id", "product_id", "override_price", "is_active"],
             price_list_items),
        ],
        extra_header_lines=[
            "Owned imperfection: #7 — 10 active products are each covered by 1",
            "global + 1 city + 1 store price_list simultaneously. The 'most",
            "specific wins' rule lives in app code, not DB.",
        ],
    )
