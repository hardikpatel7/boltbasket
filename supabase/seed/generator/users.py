"""Generates 02b_users.sql.

Bulk users start at user_id = SMOKE_MAX_USER_ID + 1 = 6.
Phones use +9199-prefixed pool to avoid colliding with smoke seed.
"""
from datetime import datetime, timedelta, time
from pathlib import Path

from generator import common, config

IST = common.IST


def _generate_users():
    rng = common.get_rng("users")
    faker = common.get_faker("users")
    n = config.CARDINALITIES["users"]["users"]
    rows = []
    for i in range(n):
        # Phone pool: +91990XXXXXXXX (smoke uses +9198123400XX, no overlap)
        phone = f"+91990{i:08d}"
        has_email = rng.random() < 0.7
        first = faker.first_name()
        last = faker.last_name()
        email = (
            f"{first.lower()}.{last.lower()}{i}@example.fictional"
            if has_email else None
        )
        signup_city_id = int(rng.choice([1, 2, 3], p=[0.50, 0.35, 0.15]))
        # Signup anytime in the past 2 years up to anchor
        signup_offset = int(rng.integers(1, 730))
        signup_at = datetime.combine(
            config.ANCHOR_DATE - timedelta(days=signup_offset),
            time(int(rng.integers(0, 24)), int(rng.integers(0, 60))),
            tzinfo=IST,
        )
        # Last active: between signup and anchor
        last_active_offset = int(rng.integers(0, max(1, signup_offset)))
        last_active_at = datetime.combine(
            config.ANCHOR_DATE - timedelta(days=last_active_offset),
            time(int(rng.integers(0, 24)), int(rng.integers(0, 60))),
            tzinfo=IST,
        )
        rows.append((
            phone, email, first, last, signup_city_id, signup_at, last_active_at,
        ))
    return rows


def _generate_addresses(num_users: int):
    """4500 addresses for 3500 users — most have 1, ~28% have 2."""
    rng = common.get_rng("users.addresses")
    faker = common.get_faker("users.addresses")
    target = config.CARDINALITIES["users"]["addresses"]

    # All users start at user_id = SMOKE_MAX_USER_ID + 1 = 6
    bulk_user_ids = list(range(
        config.SMOKE_MAX_USER_ID + 1,
        config.SMOKE_MAX_USER_ID + 1 + num_users,
    ))

    # Pincode pool — match smoke seed (pincode_id 1..23)
    pincode_ids = list(range(1, 24))

    # Pincode weighting: BLR pincodes (1..9) more likely than BOM (10..16) than PNQ (17..23)
    pincode_weights = (
        [3.0] * 9 +    # BLR pincodes
        [2.0] * 7 +    # BOM pincodes
        [1.0] * 7      # PNQ pincodes
    )
    pincode_weights_arr = [w / sum(pincode_weights) for w in pincode_weights]

    rows = []
    # Each user gets 1 address; ~28% get a second
    for user_id in bulk_user_ids:
        pid = int(rng.choice(pincode_ids, p=pincode_weights_arr))
        rows.append((
            user_id, pid, faker.street_address()[:100], None, None, "home", True,
        ))
    # Add second addresses until we hit target
    while len(rows) < target:
        user_id = int(rng.choice(bulk_user_ids))
        pid = int(rng.choice(pincode_ids, p=pincode_weights_arr))
        addr_type = "work" if rng.random() < 0.7 else "other"
        rows.append((
            user_id, pid, faker.street_address()[:100], None, None, addr_type, True,
        ))
    return rows


def write(path: Path) -> None:
    user_rows = _generate_users()
    address_rows = _generate_addresses(num_users=len(user_rows))

    # chunk_size is set larger than either cardinality so that each table
    # section emits a single INSERT statement with no mid-section blank lines.
    # This is required for the test helpers which split on "\n\n" to count rows.
    common.write_sql_file(
        path=path,
        title="Phase 4b — 02b users",
        owns_imperfection="None (bulk additive layer; smoke seed owns #1)",
        sections=[
            ("users",
             ["phone", "email", "first_name", "last_name",
              "signup_city_id", "signup_at", "last_active_at"],
             user_rows),
            ("addresses",
             ["user_id", "pincode_id", "address_line_1", "address_line_2",
              "landmark", "address_type", "is_active"],
             address_rows),
        ],
        extra_header_lines=[
            f"Bulk user_id range: {config.SMOKE_MAX_USER_ID + 1}..{config.SMOKE_MAX_USER_ID + len(user_rows)}",
            "primary_address_id is left unset (NULL) for bulk users — the app",
            "would set it on first address creation. Setting it here would",
            "require a separate UPDATE pass which we skip for the bulk seed.",
        ],
        chunk_size=5_000,
    )
