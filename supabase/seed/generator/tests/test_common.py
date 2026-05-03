"""Tests for common helpers."""
from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import numpy as np
import pytest

from generator import common, config


def test_sql_value_none_returns_NULL():
    assert common.sql_value(None) == "NULL"


def test_sql_value_int_returns_int_literal():
    assert common.sql_value(42) == "42"


def test_sql_value_float_returns_decimal_str():
    assert common.sql_value(12.5) == "12.50"


def test_sql_value_bool_returns_postgres_bool():
    assert common.sql_value(True) == "TRUE"
    assert common.sql_value(False) == "FALSE"


def test_sql_value_string_quotes_and_escapes_single_quotes():
    assert common.sql_value("Mohan's Bike") == "'Mohan''s Bike'"


def test_sql_value_date_returns_iso_date_literal():
    assert common.sql_value(date(2025, 10, 15)) == "'2025-10-15'"


def test_sql_value_datetime_returns_timestamptz_literal():
    dt = datetime(2025, 10, 15, 12, 30, 0, tzinfo=ZoneInfo("Asia/Kolkata"))
    assert common.sql_value(dt) == "'2025-10-15 12:30:00+05:30'"


def test_sql_value_dict_returns_jsonb_literal():
    assert common.sql_value({"a": 1, "b": "two"}) == """'{"a": 1, "b": "two"}'::jsonb"""


def test_sql_value_list_returns_jsonb_literal():
    assert common.sql_value([1, 2, "three"]) == """'[1, 2, "three"]'::jsonb"""


def test_sql_value_dict_with_apostrophe_escapes_single_quote():
    """JSONB values containing ' must be SQL-escaped or the literal terminates early."""
    rendered = common.sql_value({"name": "Mohan's Market"})
    assert rendered == """'{"name": "Mohan''s Market"}'::jsonb"""


def test_sql_value_handles_numpy_integer_scalars():
    """rng.integers() returns np.int64 by default; sql_value must accept it."""
    assert common.sql_value(np.int64(42)) == "42"
    assert common.sql_value(np.int32(7)) == "7"
    assert common.sql_value(np.int8(-5)) == "-5"


def test_sql_value_handles_numpy_floating_scalars():
    assert common.sql_value(np.float64(12.5)) == "12.50"
    assert common.sql_value(np.float32(3.14)) == "3.14"


def test_sql_value_decimal_preserves_precision():
    """Decimal renders as-is; Postgres applies column-level scale, not us."""
    assert common.sql_value(Decimal("99.50")) == "99.50"
    assert common.sql_value(Decimal("99.999")) == "99.999"


def test_sql_value_naive_datetime_raises():
    """A naive datetime in a TIMESTAMPTZ column would be silently mis-tz'd."""
    naive = datetime(2025, 10, 15, 12, 30, 0)
    with pytest.raises(ValueError, match="tz-aware"):
        common.sql_value(naive)


def test_get_rng_is_seeded_deterministically():
    rng1 = common.get_rng("users")
    rng2 = common.get_rng("users")
    assert rng1.integers(0, 1_000_000) == rng2.integers(0, 1_000_000)


def test_get_rng_isolates_modules():
    rng1 = common.get_rng("users")
    rng2 = common.get_rng("orders")
    assert rng1.integers(0, 1_000_000) != rng2.integers(0, 1_000_000)


def test_get_faker_is_seeded():
    f1 = common.get_faker("users")
    f2 = common.get_faker("users")
    # Two seeded fakers produce identical output
    assert f1.name() == f2.name()


def test_random_ist_datetime_in_window():
    rng = common.get_rng("test")
    dt = common.random_ist_datetime(rng, date(2025, 10, 9), date(2025, 10, 15))
    assert config.ACTIVITY_START <= dt.date() <= config.ACTIVITY_END
    assert dt.tzinfo == ZoneInfo("Asia/Kolkata")


def test_write_sql_file_writes_header_and_inserts(tmp_path):
    target = tmp_path / "test.sql"
    common.write_sql_file(
        path=str(target),
        title="TEST FILE",
        owns_imperfection="None",
        sections=[
            (
                "test_table",
                ["a", "b"],
                [(1, "x"), (2, "y")],
            ),
        ],
    )
    text = target.read_text()
    assert "TEST FILE" in text
    assert "INSERT INTO raw.test_table (a, b) VALUES" in text
    assert "(1, 'x')" in text
    assert "(2, 'y')" in text


def test_pick_weighted_returns_keys_per_weights():
    rng = common.get_rng("test_pick")
    counts = {"a": 0, "b": 0, "c": 0}
    for _ in range(10_000):
        k = common.pick_weighted(rng, {"a": 0.7, "b": 0.2, "c": 0.1})
        counts[k] += 1
    # Loose ranges (allow ±2% per choice)
    assert 6_700 <= counts["a"] <= 7_300
    assert 1_700 <= counts["b"] <= 2_300
    assert 700 <= counts["c"] <= 1_300


def test_zipf_indices_returns_skewed_sample():
    rng = common.get_rng("test_zipf")
    n = 10  # population size
    sample = common.zipf_indices(rng, n=n, size=10_000, alpha=1.5)
    assert all(0 <= i < n for i in sample)
    # Index 0 should appear most often
    counts = [0] * n
    for i in sample:
        counts[i] += 1
    assert counts[0] == max(counts)
