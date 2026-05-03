"""Shared helpers: SQL value escaping, file writing, RNG/Faker init, date helpers."""
import json
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo

import numpy as np
from faker import Faker

from generator import config

IST = ZoneInfo("Asia/Kolkata")


def sql_value(v: Any) -> str:
    """Render a Python value as a Postgres SQL literal.

    - numpy scalar types (int8..int64, float32/64, etc.) are handled via the
      np.integer / np.floating abstract bases so callers don't need to coerce
      every rng.integers() result with int(...).
    - datetimes MUST be timezone-aware. Naive datetimes raise ValueError —
      otherwise they'd silently land in TIMESTAMPTZ columns as session-local
      time, producing wrong data.
    - dict/list values that contain apostrophes are SQL-escaped after JSON
      encoding (otherwise an apostrophe inside a JSON string would terminate
      the SQL literal early — common with Faker en_IN names).
    - Decimal values render at full precision; Postgres applies column scale.
    """
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return f"{float(v):.2f}"
    if isinstance(v, Decimal):
        return str(v)
    if isinstance(v, datetime):
        if v.tzinfo is None:
            raise ValueError(
                f"sql_value: datetime must be tz-aware, got naive: {v!r}"
            )
        return f"'{v.isoformat(sep=' ')}'"
    if isinstance(v, date):
        return f"'{v.isoformat()}'"
    if isinstance(v, (dict, list)):
        encoded = json.dumps(v, separators=(', ', ': ')).replace("'", "''")
        return f"'{encoded}'::jsonb"
    if isinstance(v, str):
        escaped = v.replace("'", "''")
        return f"'{escaped}'"
    raise TypeError(f"Unsupported SQL value type: {type(v).__name__}: {v!r}")


def get_rng(module_name: str) -> np.random.Generator:
    """Return a numpy Generator seeded deterministically for the module."""
    return np.random.default_rng(config.sub_seed(module_name))


def get_faker(module_name: str) -> Faker:
    """Return a Faker instance with en_IN locale, seeded deterministically."""
    f = Faker("en_IN")
    Faker.seed(config.sub_seed(module_name))
    f.seed_instance(config.sub_seed(module_name))
    return f


def random_ist_datetime(
    rng: np.random.Generator,
    start: date,
    end: date,
    hour_dist: dict[int, float] | None = None,
) -> datetime:
    """Sample a random datetime within [start, end] inclusive in IST.

    `hour_dist` optionally biases hour-of-day. Default: uniform.
    """
    days_span = (end - start).days
    day_offset = int(rng.integers(0, days_span + 1))
    chosen_date = start + timedelta(days=day_offset)

    if hour_dist:
        hours = list(hour_dist.keys())
        weights = np.array([hour_dist[h] for h in hours], dtype=float)
        weights /= weights.sum()
        hour = int(rng.choice(hours, p=weights))
    else:
        hour = int(rng.integers(0, 24))
    minute = int(rng.integers(0, 60))
    second = int(rng.integers(0, 60))
    return datetime.combine(chosen_date, time(hour, minute, second), tzinfo=IST)


def pick_weighted(rng: np.random.Generator, choices: dict[str, float]) -> str:
    """Sample a key from `choices` with probability proportional to its value."""
    keys = list(choices.keys())
    weights = np.array([choices[k] for k in keys], dtype=float)
    weights /= weights.sum()
    idx = int(rng.choice(len(keys), p=weights))
    return keys[idx]


def zipf_indices(
    rng: np.random.Generator,
    n: int,
    size: int,
    alpha: float = 1.5,
) -> np.ndarray:
    """Return `size` indices in [0, n) sampled with Zipf-like skew.

    Index 0 is most popular. Used for product popularity, etc.
    """
    # P(rank=k) ∝ 1 / (k+1)^alpha
    ranks = np.arange(n)
    weights = 1.0 / np.power(ranks + 1, alpha)
    weights /= weights.sum()
    return rng.choice(n, size=size, p=weights)


def write_sql_file(
    path: str | Path,
    title: str,
    owns_imperfection: str,
    sections: Iterable[tuple[str, list[str], list[tuple]]],
    extra_header_lines: list[str] | None = None,
    chunk_size: int = 500,
) -> None:
    """Write a SQL file with a header + multi-row INSERT sections.

    Args:
        path: target file path.
        title: top header title (e.g., "Phase 4b — 02b users").
        owns_imperfection: free-text note (e.g., "Imperfection #3").
        sections: iterable of (table_name, column_names, list_of_value_tuples).
        extra_header_lines: optional extra comment lines after the title.
        chunk_size: max rows per INSERT statement (multi-row VALUES).
    """
    path = Path(path)
    lines: list[str] = []
    lines.append(
        "-- ============================================================================"
    )
    lines.append(f"-- {title}")
    lines.append(f"-- Owns: {owns_imperfection}")
    lines.append(
        "-- Generated by supabase/seed/generator. Do not edit by hand."
    )
    lines.append(
        "-- ============================================================================"
    )
    if extra_header_lines:
        for ln in extra_header_lines:
            lines.append(f"-- {ln}")
    lines.append("")
    lines.append("SET search_path TO raw, public;")
    lines.append("")

    for table_name, columns, rows in sections:
        if not rows:
            lines.append(f"-- (no rows for {table_name})")
            lines.append("")
            continue
        col_list = ", ".join(columns)
        lines.append(f"-- {table_name}: {len(rows)} rows")
        for chunk_start in range(0, len(rows), chunk_size):
            chunk = rows[chunk_start : chunk_start + chunk_size]
            lines.append(f"INSERT INTO raw.{table_name} ({col_list}) VALUES")
            value_lines = []
            for row in chunk:
                rendered = ", ".join(sql_value(v) for v in row)
                value_lines.append(f"  ({rendered})")
            lines.append(",\n".join(value_lines) + ";")
        # One blank line AFTER the table's last chunk (between tables only).
        # Chunks of the same table are emitted back-to-back so test parsers
        # using split("\n\n") capture the full table section in one piece.
        lines.append("")

    path.write_text("\n".join(lines) + "\n")
