"""Tests for config: SEED, ANCHOR_DATE, CARDINALITIES, sub_seed determinism."""
from datetime import date

from generator import config


def test_seed_is_42():
    assert config.SEED == 42


def test_anchor_date_is_2025_10_15():
    assert config.ANCHOR_DATE == date(2025, 10, 15)


def test_activity_window_is_7_days_ending_anchor():
    assert config.ACTIVITY_START == date(2025, 10, 9)
    assert config.ACTIVITY_END == date(2025, 10, 15)
    assert (config.ACTIVITY_END - config.ACTIVITY_START).days == 6  # inclusive 7-day window


def test_cardinalities_present_for_all_modules():
    expected_modules = {
        "operational", "users", "inventory", "orders",
        "engagement", "advertising", "orphans",
    }
    assert set(config.CARDINALITIES.keys()) == expected_modules


def test_total_cardinality_in_target_range():
    total = sum(sum(rows.values()) for rows in config.CARDINALITIES.values())
    assert 200_000 <= total <= 220_000, f"total={total} outside 200K-220K"


def test_sub_seed_is_deterministic():
    s1 = config.sub_seed("users")
    s2 = config.sub_seed("users")
    assert s1 == s2


def test_sub_seed_isolates_modules():
    assert config.sub_seed("users") != config.sub_seed("orders")


def test_sub_seed_is_int():
    assert isinstance(config.sub_seed("users"), int)
