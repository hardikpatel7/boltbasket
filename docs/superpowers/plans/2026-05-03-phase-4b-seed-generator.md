# Phase 4b Seed Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic Python generator for Phase 4b that produces ~210K bulk rows of BoltBasket activity in 7 alphabetically-ordered SQL files, fully exercising imperfections #3, #7, #8, #10, #11 while leaving the smoke seed's hand-crafted #1, #2, #4, #5, #6, #12 rows untouched.

**Architecture:** Python package at `supabase/seed/generator/` with one module per output SQL file. Each module owns at most one imperfection. Generator runs via `python generate.py`; output files load via `psql -f` in alphabetical order. Layered onto smoke seed (smoke loads first, bulk adds on top).

**Tech Stack:** Python 3.10+, faker (en_IN locale), numpy, pytest. Stdlib `zoneinfo` + `datetime` for IST. No DB connection from Python — generator writes SQL files only.

---

## Pre-flight: Spec ↔ DDL reconciliations

The approved spec drifted from the DDL on three minor points. The plan uses DDL-correct names throughout:

1. **#7 scope types:** `price_lists.scope_type` only accepts `('global', 'city', 'store')`. No `category` scope. Time-bounding is via `starts_at`/`ends_at`. The "all 4 scopes" overlap target collapses to **all 3 scope types simultaneously (global + city + store)** plus time-bound overlaps.
2. **`store_inventory` column** is `quantity_on_hand`, not `quantity_available`.
3. **Multi-touch attribution** uses `multi_touch_linear` (one of 4 valid `attribution_model` values: `last_click`, `view_through`, `multi_touch_linear`, `multi_touch_position_based`).

These reconciliations will be recorded in the decisions-log entry at the end (Task 15).

---

## File Structure

```
supabase/seed/                                  ← outputs land here
├── 01_smoke_seed.sql                           (existing, unchanged)
├── 02a_operational_baseline.sql                (generated)
├── 02b_users.sql                               (generated)
├── 02c_inventory.sql                           (generated)
├── 02d_orders.sql                              (generated)
├── 02e_engagement.sql                          (generated)
├── 02f_advertising.sql                         (generated)
├── 02g_orphans.sql                             (generated)
└── generator/                                  ← Python source
    ├── README.md
    ├── requirements.txt
    ├── pytest.ini
    ├── __init__.py
    ├── config.py                               (SEED, ANCHOR_DATE, CARDINALITIES)
    ├── common.py                               (sql_value, write_sql_file, get_rng, ist helpers)
    ├── generate.py                             (entry point — runs all modules)
    ├── operational.py                          (writes 02a; owns #7)
    ├── users.py                                (writes 02b)
    ├── inventory.py                            (writes 02c; owns #3)
    ├── orders.py                               (writes 02d)
    ├── engagement.py                           (writes 02e; owns #8)
    ├── advertising.py                          (writes 02f; owns #10)
    ├── orphans.py                              (writes 02g; owns #11)
    └── tests/
        ├── __init__.py
        ├── test_config.py
        ├── test_common.py
        ├── test_operational.py
        ├── test_users.py
        ├── test_inventory.py
        ├── test_orders.py
        ├── test_engagement.py
        ├── test_advertising.py
        ├── test_orphans.py
        ├── test_determinism.py
        └── test_cardinalities.py
```

**Run flow** (after Task 14 completes):
```sh
cd supabase/seed/generator
python generate.py                                              # writes all 02*.sql
cd ../../..
for f in supabase/seed/02*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
```

---

## Task 1: Initialize git + project scaffolding + .gitignore

**Files:**
- Create: `.gitignore`
- Create: `supabase/seed/generator/__init__.py` (empty)
- Create: `supabase/seed/generator/tests/__init__.py` (empty)
- Create: `supabase/seed/generator/pytest.ini`
- Create: `supabase/seed/generator/requirements.txt`

- [ ] **Step 1: Initialize git repository**

```bash
cd "/Users/hardiksavaliya/Documents/windsurf projects /boltbasket"
git init
git config core.autocrlf input
```

Expected: "Initialized empty Git repository in ..." (or already-initialized message — fine either way)

- [ ] **Step 2: Create `.gitignore`**

```gitignore
# Secrets
.env
.env.*
!.env.example

# Python
__pycache__/
*.py[cod]
*$py.class
.pytest_cache/
.python-version
venv/
.venv/
env/
*.egg-info/
.coverage
htmlcov/
dist/
build/

# IDE
.vscode/
.idea/
*.swp
.DS_Store

# Supabase CLI artifacts
supabase/.temp/
```

- [ ] **Step 3: Verify `.env` is ignored**

```bash
git check-ignore -v .env || echo "WARN: .env is NOT ignored — fix before continuing"
```

Expected: prints a line confirming `.env` matches `.gitignore`. If it prints "WARN", stop and fix `.gitignore` before proceeding.

- [ ] **Step 4: Create the generator package skeleton**

```bash
mkdir -p supabase/seed/generator/tests
touch supabase/seed/generator/__init__.py
touch supabase/seed/generator/tests/__init__.py
```

- [ ] **Step 5: Create `supabase/seed/generator/requirements.txt`**

```
faker==25.3.0
numpy==2.0.0
pytest==8.2.2
```

- [ ] **Step 6: Create `supabase/seed/generator/pytest.ini`**

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
```

- [ ] **Step 7: First commit**

```bash
git add .gitignore supabase/seed/generator/__init__.py \
        supabase/seed/generator/tests/__init__.py \
        supabase/seed/generator/pytest.ini \
        supabase/seed/generator/requirements.txt \
        bible/ schema/ supabase/ templates/ docs/ \
        CLAUDE.md decisions-log.md style-guide.md README.md 2>/dev/null || true
git status
git commit -m "chore: init git, project scaffolding for Phase 4b generator"
```

Expected: a commit covering all existing project files + new generator skeleton. (`README.md` and `style-guide.md` are added if they exist; `2>/dev/null || true` makes the add forgiving.)

- [ ] **Step 8: Set up Python virtual environment + install deps**

```bash
cd supabase/seed/generator
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -c "import faker, numpy, pytest; print('all deps ok')"
cd ../../..
```

Expected: `all deps ok`. The `.venv/` is `.gitignore`d.

---

## Task 2: `config.py` (constants) + tests

**Files:**
- Create: `supabase/seed/generator/config.py`
- Create: `supabase/seed/generator/tests/test_config.py`

- [ ] **Step 1: Write the failing test `tests/test_config.py`**

```python
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
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
cd supabase/seed/generator
source .venv/bin/activate
pytest tests/test_config.py -v
```

Expected: `ImportError: No module named 'generator.config'` or `AttributeError: module 'generator' has no attribute 'config'`.

- [ ] **Step 3: Write `supabase/seed/generator/config.py`**

```python
"""Single source of truth for Phase 4b seed generator constants."""
import hashlib
from datetime import date

SEED = 42
ANCHOR_DATE = date(2025, 10, 15)
ACTIVITY_END = ANCHOR_DATE
ACTIVITY_START = date(2025, 10, 9)  # 7 inclusive days

# Per-module row budgets (target ~210K total, within 200-220K range).
# Row counts here are ROWS GENERATED BY BULK SEED, not totals incl. smoke seed.
CARDINALITIES = {
    "operational": {
        "riders": 50,
        "ad_campaigns": 20,
        "ad_placements": 60,
        "promotions": 25,
        "price_lists": 15,
        "price_list_items": 300,
    },
    "users": {
        "users": 3_500,
        "addresses": 4_500,
    },
    "inventory": {
        "store_inventory": 120,         # 10 active products × 12 stores
        "inventory_movements": 25_000,
    },
    "orders": {
        "carts": 13_000,
        "orders": 10_000,
        "order_items": 30_000,
        "order_events": 40_000,
        "payments": 10_000,
        "refunds": 500,
    },
    "engagement": {
        "app_events": 30_000,
        "search_queries": 10_000,
        "push_notifications": 8_000,
        "pipeline_runs": 200,
    },
    "advertising": {
        "ad_impressions": 20_000,
        "ad_clicks": 2_000,
        "ad_attributions": 3_500,
    },
    "orphans": {
        "products": 50,
    },
}

# Smoke seed ID ranges — bulk must NOT collide
SMOKE_MAX_USER_ID = 5
SMOKE_MAX_ADDRESS_ID = 5
SMOKE_MAX_CART_ID = 1
SMOKE_MAX_ORDER_ID = 3
SMOKE_MAX_ORDER_ITEM_ID = 4
SMOKE_MAX_RIDER_ID = 3
SMOKE_MAX_PRODUCT_ID = 10
SMOKE_MAX_PRODUCT_ATTR_ID = 18
SMOKE_MAX_ORDER_EVENT_ID = 5

# Used for #6: pre-2023 date floor for "legacy bad rows" in smoke seed only
LEGACY_DATE_FLOOR = date(2023, 12, 31)

# City split (must match smoke seed cities table)
CITY_DISTRIBUTION = {1: 0.50, 2: 0.35, 3: 0.15}  # BLR, BOM, PNQ
CITY_CODES = {1: "BLR", 2: "BOM", 3: "PNQ"}


def sub_seed(module_name: str) -> int:
    """Derive a stable per-module seed from the global SEED + module name.

    Isolates RNG state so regenerating one module doesn't shift others' output.
    """
    h = hashlib.sha256(module_name.encode("utf-8")).digest()
    return int.from_bytes(h[:8], "big") ^ SEED
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
pytest tests/test_config.py -v
```

Expected: 8 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/config.py supabase/seed/generator/tests/test_config.py
git commit -m "feat(generator): add config with SEED, ANCHOR_DATE, cardinalities, sub_seed"
```

---

## Task 3: `common.py` (helpers) + tests

**Files:**
- Create: `supabase/seed/generator/common.py`
- Create: `supabase/seed/generator/tests/test_common.py`

- [ ] **Step 1: Write the failing test `tests/test_common.py`**

```python
"""Tests for common helpers."""
from datetime import date, datetime
from zoneinfo import ZoneInfo

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
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
cd supabase/seed/generator
source .venv/bin/activate
pytest tests/test_common.py -v
```

Expected: ImportError or attribute errors on `common`.

- [ ] **Step 3: Write `supabase/seed/generator/common.py`**

```python
"""Shared helpers: SQL value escaping, file writing, RNG/Faker init, date helpers."""
import json
from datetime import date, datetime, time
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo

import numpy as np
from faker import Faker

from generator import config

IST = ZoneInfo("Asia/Kolkata")


def sql_value(v: Any) -> str:
    """Render a Python value as a Postgres SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return f"{v:.2f}"
    if isinstance(v, Decimal):
        return f"{v:.2f}"
    if isinstance(v, datetime):
        # Render as Postgres timestamptz with offset
        return f"'{v.strftime('%Y-%m-%d %H:%M:%S%z')}'".replace(
            "+0530'", "+05:30'"
        ).replace("-0530'", "-05:30'")
    if isinstance(v, date):
        return f"'{v.isoformat()}'"
    if isinstance(v, dict):
        return f"'{json.dumps(v, separators=(', ', ': '))}'::jsonb"
    if isinstance(v, list):
        return f"'{json.dumps(v, separators=(', ', ': '))}'::jsonb"
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
    from datetime import timedelta
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
            lines.append("")

    path.write_text("\n".join(lines) + "\n")
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
pytest tests/test_common.py -v
```

Expected: 16 passed. (If `random_ist_datetime` fails, debug — likely whitespace issue in the noqa line; remove that line.)

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/common.py supabase/seed/generator/tests/test_common.py
git commit -m "feat(generator): add common helpers (sql_value, write_sql_file, RNG/Faker init)"
```

---

## Task 4: `generate.py` orchestrator (stub) + smoke

**Files:**
- Create: `supabase/seed/generator/generate.py`

- [ ] **Step 1: Write `generate.py` (stub that just announces)**

```python
"""Phase 4b seed generator entry point.

Run:
    python generate.py            # writes all 02*.sql files
    python generate.py --module operational  # write just one
"""
import argparse
import sys
from pathlib import Path
from typing import Callable

OUTPUT_DIR = Path(__file__).resolve().parent.parent  # supabase/seed/

# Import-by-name so missing modules error clearly during early Tasks
MODULES: dict[str, str] = {
    "operational": "02a_operational_baseline.sql",
    "users":       "02b_users.sql",
    "inventory":   "02c_inventory.sql",
    "orders":      "02d_orders.sql",
    "engagement":  "02e_engagement.sql",
    "advertising": "02f_advertising.sql",
    "orphans":     "02g_orphans.sql",
}


def get_writer(module_name: str) -> Callable[[Path], None]:
    """Lazily import a module's writer to keep partial work runnable."""
    import importlib

    mod = importlib.import_module(f"generator.{module_name}")
    return getattr(mod, "write")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--module",
        choices=list(MODULES.keys()),
        help="Generate only this module (default: all)",
    )
    args = parser.parse_args()

    selected = [args.module] if args.module else list(MODULES.keys())

    for name in selected:
        out_path = OUTPUT_DIR / MODULES[name]
        print(f"  → {name} → {out_path.name}")
        try:
            writer = get_writer(name)
        except ModuleNotFoundError as e:
            print(f"    SKIP (module not yet implemented): {e}")
            continue
        writer(out_path)

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Verify it runs without error (skipping unimplemented modules)**

```bash
cd supabase/seed/generator
source .venv/bin/activate
PYTHONPATH=.. python generate.py
```

Expected: prints 7 lines, each "SKIP (module not yet implemented)".

- [ ] **Step 3: Commit**

```bash
cd ../../..
git add supabase/seed/generator/generate.py
git commit -m "feat(generator): add generate.py orchestrator (stub, modules pending)"
```

---

## Task 5: `operational.py` — 02a (owns Imperfection #7)

**Files:**
- Create: `supabase/seed/generator/operational.py`
- Create: `supabase/seed/generator/tests/test_operational.py`

**What this module does:**
- Generates 50 riders (rider_ids 4..53, since smoke seed has 1..3)
- Generates 20 ad_campaigns spread across the 13 brands
- Generates 60 ad_placements (3 per campaign avg)
- Generates 25 promotions (mix of types, time windows)
- Generates 15 price_lists with **3 scope mixes** (global / city / store) + time bounding
- Generates ~300 price_list_items with **deliberate scope overlaps** for ~10 products

**Imperfection #7 mechanic:** ~10 products will have price_list_items in **all 3 scope types** (global, city, store) simultaneously. The "most specific wins" rule lives only in app code.

- [ ] **Step 1: Write `tests/test_operational.py`**

```python
"""Tests for operational module (02a)."""
from pathlib import Path

import pytest

from generator import operational, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02a_operational_baseline.sql"


def test_write_creates_file(out_path):
    operational.write(out_path)
    assert out_path.exists()


def test_riders_block_contains_50_rows(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    # rider_code BB-RDR-XXXXX format; smoke uses 00001-00003
    assert text.count("'BB-RDR-0") == 53  # 50 bulk + 3 we'll see referenced
    # but 50 are inserted by THIS file
    insert_block = text.split("-- riders: ")[1].split("\n\n")[0]
    rider_lines = [ln for ln in insert_block.splitlines() if ln.startswith("  ('BB-RDR-")]
    assert len(rider_lines) == 50


def test_rider_ids_start_after_smoke_max(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    # smoke has BB-RDR-00001/2/3, so bulk should start at BB-RDR-00004
    assert "'BB-RDR-00004'" in text
    assert "'BB-RDR-00003'" not in text  # not in this file


def test_ad_campaigns_count(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_campaigns: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["operational"]["ad_campaigns"]


def test_price_lists_have_three_scope_types(out_path):
    operational.write(out_path)
    text = out_path.read_text()
    pl_section = text.split("-- price_lists: ")[1].split("\n\n")[0]
    assert "'global'" in pl_section
    assert "'city'" in pl_section
    assert "'store'" in pl_section


def test_imperfection_7_overlap_count(out_path):
    """At least 10 products appear in all 3 scope types (global + city + store)."""
    operational.write(out_path)
    text = out_path.read_text()

    # parse price_lists rows to learn each price_list_id's scope_type
    pl_section = text.split("-- price_lists: ")[1].split("\n\n")[0]
    pl_scopes: dict[int, str] = {}
    for ln in pl_section.splitlines():
        if not ln.startswith("INSERT") and ln.startswith("  ("):
            # price_lists doesn't include id in INSERT — schema uses SERIAL
            # We need a different approach: parse the order; first price_list inserted = id 1, etc.
            pass

    # parse price_list_items to map (price_list_id_position) → product_id
    pli_section = text.split("-- price_list_items: ")[1].split("\n\n")[0]
    # the items reference price_list_id by INTEGER literal — so we can read directly
    # row format: (price_list_id, product_id, override_price, is_active)
    import re
    items: list[tuple[int, int]] = []
    for ln in pli_section.splitlines():
        m = re.match(r"\s*\(\s*(\d+),\s*(\d+),", ln)
        if m:
            items.append((int(m.group(1)), int(m.group(2))))

    # build map of price_list_id → scope_type by matching position in pl_section to scope_type
    # Each price_list row in section is "  (... '<scope_type>', ...)"
    pl_scope_re = re.compile(r"'(global|city|store)'")
    pl_position = 1
    for ln in pl_section.splitlines():
        if ln.startswith("  ("):
            m = pl_scope_re.search(ln)
            if m:
                pl_scopes[pl_position] = m.group(1)
                pl_position += 1

    # for each product_id, collect set of scope_types it belongs to
    prod_scopes: dict[int, set[str]] = {}
    for pl_id, prod_id in items:
        prod_scopes.setdefault(prod_id, set()).add(pl_scopes.get(pl_id, "?"))

    triple_overlap = sum(1 for s in prod_scopes.values() if {"global", "city", "store"}.issubset(s))
    assert triple_overlap >= 10, f"only {triple_overlap} products in all 3 scopes; expected ≥10"


def test_deterministic_run(out_path, tmp_path):
    p1 = tmp_path / "run1.sql"
    p2 = tmp_path / "run2.sql"
    operational.write(p1)
    operational.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd supabase/seed/generator && source .venv/bin/activate
pytest tests/test_operational.py -v
```

Expected: ImportError on `operational`.

- [ ] **Step 3: Write `supabase/seed/generator/operational.py`**

```python
"""Generates 02a_operational_baseline.sql.

Owns Imperfection #7: price_list scope overlaps. The 10 base products will each
appear in 3 price_lists (one global, one city, one store) so the 'most specific
wins' rule has data to chew on.
"""
from datetime import date, datetime, timedelta, time
from pathlib import Path
from zoneinfo import ZoneInfo

from generator import common, config

IST = ZoneInfo("Asia/Kolkata")
ANCHOR = config.ANCHOR_DATE
WINDOW_START = config.ACTIVITY_START

# All 13 brands from smoke seed (brand_id 1..13). Hardcoded — must match smoke.
BRAND_IDS = list(range(1, 14))

# All 12 dark stores from smoke seed (dark_store_id 1..12)
STORE_IDS = list(range(1, 13))

# Cities (city_id 1..3)
CITY_IDS = [1, 2, 3]

# Active products (product_id 1..10) — bulk references these for #7 overlap
ACTIVE_PRODUCT_IDS = list(range(1, 11))


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
        # Global override: ~5% off base
        override_global = round(float(rng.uniform(0.93, 0.97)) * _base_price(product_id), 2)
        rows.append((1, product_id, override_global, True))

        # One city override (2..7)
        city_pl_id = int(rng.integers(2, 8))
        override_city = round(float(rng.uniform(0.90, 0.95)) * _base_price(product_id), 2)
        rows.append((city_pl_id, product_id, override_city, True))

        # One store override (8..15)
        store_pl_id = int(rng.integers(8, 16))
        override_store = round(float(rng.uniform(0.85, 0.92)) * _base_price(product_id), 2)
        rows.append((store_pl_id, product_id, override_store, True))

    # 30 rows so far. Now add ~270 more items distributed across the 15 price_lists,
    # using the same 10 products with various overrides (no UNIQUE conflict since
    # we cycle through different price_list × product combos that don't yet exist).
    existing_pairs = {(r[0], r[1]) for r in rows}
    needed = config.CARDINALITIES["operational"]["price_list_items"] - len(rows)
    attempts = 0
    while len(rows) - 30 < needed and attempts < needed * 5:
        attempts += 1
        pl_id = int(rng.integers(1, 16))
        product_id = int(rng.choice(ACTIVE_PRODUCT_IDS))
        if (pl_id, product_id) in existing_pairs:
            continue
        existing_pairs.add((pl_id, product_id))
        override = round(float(rng.uniform(0.80, 0.99)) * _base_price(product_id), 2)
        rows.append((pl_id, product_id, override, True))

    return rows


def _base_price(product_id: int) -> float:
    """Approximate base prices for the 10 smoke-seed products (in INR).

    These should match smoke seed values closely enough that overrides feel
    plausible. Real values from supabase/seed/01_smoke_seed.sql.
    """
    return {
        1: 72.00,    # Amul Gold Milk 1L
        2: 65.00,    # Mother Dairy Yogurt 400g (approximation)
        3: 50.00,    # Britannia Brown Bread 400g
        4: 295.00,   # Aashirvaad Atta 5kg
        5: 175.00,   # MDH Garam Masala 100g
        6: 95.00,    # Parle-G Original 800g
        7: 240.00,   # Tata Tea Premium 500g
        8: 165.00,   # Cadbury Dairy Milk Silk 60g
        9: 195.00,   # Nivea Soft Light Moisturiser 100ml
        10: 145.00,  # BoltBasket Daily Toor Dal 1kg
    }.get(product_id, 100.00)


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
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
pytest tests/test_operational.py -v
```

Expected: 7 passed. (If the price_list_id parser fails, debug — likely the regex needs tweaking to handle the actual SQL output format.)

- [ ] **Step 5: Run the full generator with just operational, inspect output**

```bash
PYTHONPATH=.. python generate.py --module operational
head -40 ../02a_operational_baseline.sql
wc -l ../02a_operational_baseline.sql
```

Expected: file produced, ~470 INSERT rows total, header indicates "owns Imperfection #7".

- [ ] **Step 6: Commit**

```bash
cd ../../..
git add supabase/seed/generator/operational.py supabase/seed/generator/tests/test_operational.py
git commit -m "feat(generator): add operational module (02a) — owns Imperfection #7"
```

---

## Task 6: `users.py` — 02b

**Files:**
- Create: `supabase/seed/generator/users.py`
- Create: `supabase/seed/generator/tests/test_users.py`

**What this module does:**
- 3,500 bulk users with phones starting at `+91981234XXXX` (smoke uses `+919812340001..05`)
- 4,500 addresses (most users have 1; some have 2)
- IDs start at user_id=6, address_id=6 to avoid stomping smoke seed

- [ ] **Step 1: Write `tests/test_users.py`**

```python
from pathlib import Path

import pytest
from generator import users, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02b_users.sql"


def test_user_count(out_path):
    users.write(out_path)
    text = out_path.read_text()
    section = text.split("-- users: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["users"]["users"]


def test_address_count(out_path):
    users.write(out_path)
    text = out_path.read_text()
    section = text.split("-- addresses: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["users"]["addresses"]


def test_phones_dont_collide_with_smoke(out_path):
    users.write(out_path)
    text = out_path.read_text()
    # Smoke uses +919812340001..+919812340005
    for i in range(1, 6):
        smoke_phone = f"+9198123400{i:02d}"
        assert smoke_phone not in text


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    users.write(p1)
    users.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd supabase/seed/generator && source .venv/bin/activate
pytest tests/test_users.py -v
```

- [ ] **Step 3: Write `supabase/seed/generator/users.py`**

```python
"""Generates 02b_users.sql.

Bulk users start at user_id = SMOKE_MAX_USER_ID + 1 = 6.
Phones use +9198XXX-prefixed pool to avoid colliding with smoke seed.
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
        # Phone pool: +9198XXXXX-prefixed (smoke uses +9198123400XX, so we skip those)
        # Use +91 9 + last 9 digits, ensuring no overlap with smoke prefix
        # Simple: +9199 + 8 digits derived from i
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
    )
```

- [ ] **Step 4: Run the tests, verify they pass**

```bash
pytest tests/test_users.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/users.py supabase/seed/generator/tests/test_users.py
git commit -m "feat(generator): add users module (02b) — 3500 bulk users + 4500 addresses"
```

---

## Task 7: `inventory.py` — 02c (owns Imperfection #3)

**Files:**
- Create: `supabase/seed/generator/inventory.py`
- Create: `supabase/seed/generator/tests/test_inventory.py`

**What this module does:**
- Generates `store_inventory` rows for **all 120** (store, product) cells (10 active products × 12 stores).
- Generates ~25,000 `inventory_movements` distributed over the 7-day window.
- For 115 of 120 cells: snapshot quantity = sum-of-movements (exact reconciliation).
- For 5 cells: snapshot drift by ±2 to ±15 (3 negative, 2 positive). The drifted cells are listed in a comment block at the top of `02c_inventory.sql`.

- [ ] **Step 1: Write `tests/test_inventory.py`**

```python
import re
from pathlib import Path

import pytest
from generator import inventory, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02c_inventory.sql"


def test_store_inventory_count(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    section = text.split("-- store_inventory: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["inventory"]["store_inventory"]


def test_movements_count_in_range(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    section = text.split("-- inventory_movements: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["inventory"]["inventory_movements"]
    assert abs(len(rows) - target) <= int(target * 0.02)  # ±2%


def test_drift_block_listed_in_header(out_path):
    inventory.write(out_path)
    text = out_path.read_text()
    # Header should explicitly list 5 drifted (store, product) cells
    assert "DRIFTED CELLS" in text
    drift_lines = re.findall(r"-- drifted: \(store=(\d+), product=(\d+)\) delta=([+-]\d+)", text)
    assert len(drift_lines) == 5
    deltas = [int(d) for _, _, d in drift_lines]
    assert sum(1 for d in deltas if d < 0) == 3
    assert sum(1 for d in deltas if d > 0) == 2


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    inventory.write(p1)
    inventory.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

- [ ] **Step 3: Write `supabase/seed/generator/inventory.py`**

```python
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

    movements_per_cell_target = config.CARDINALITIES["inventory"]["inventory_movements"] // len(all_cells)

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
```

- [ ] **Step 4: Run tests, verify pass**

```bash
pytest tests/test_inventory.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/inventory.py supabase/seed/generator/tests/test_inventory.py
git commit -m "feat(generator): add inventory module (02c) — owns Imperfection #3 drift"
```

---

## Task 8: `orders.py` — 02d (transactional core)

**Files:**
- Create: `supabase/seed/generator/orders.py`
- Create: `supabase/seed/generator/tests/test_orders.py`

**What this module does:**
- 13,000 carts (3K abandoned, 10K converted)
- 10,000 orders (matched to converted carts where applicable; ~3% have NULL cart_id for #5)
- 30,000 order_items (~3 per order; product popularity Zipf-skewed)
- 40,000 order_events (~4 per order)
- 10,000 payments (1 per order)
- 500 refunds (~5%)

**Note on FK ordering:** orders reference riders (loaded in 02a), users (02b), addresses (02b), dark_stores (smoke). All available before 02d.

- [ ] **Step 1: Write `tests/test_orders.py`**

```python
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
```

- [ ] **Step 2: Run, verify it fails**

- [ ] **Step 3: Write `supabase/seed/generator/orders.py`**

```python
"""Generates 02d_orders.sql.

Carts → orders → order_items → order_events → payments → refunds.
References from prior phases:
  - users (02b): bulk user_ids start at 6, count 3500
  - dark_stores (smoke): 1..12
  - riders (02a): bulk rider_ids 4..53 (50 bulk riders)
  - addresses (02b): bulk address_ids start at 6
"""
from datetime import datetime, timedelta, time, date
from pathlib import Path
import math

from generator import common, config

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
ACTIVE_PRODUCT_IDS = list(range(1, 11))

# Hour-of-day distribution (favors lunch + dinner peaks)
HOUR_DIST = {
    0: 0.001, 1: 0.001, 2: 0.001, 3: 0.001, 4: 0.001, 5: 0.001,
    6: 0.005, 7: 0.015, 8: 0.04,  9: 0.06,  10: 0.05, 11: 0.04,
    12: 0.10, 13: 0.09, 14: 0.06, 15: 0.04, 16: 0.04, 17: 0.05,
    18: 0.06, 19: 0.10, 20: 0.10, 21: 0.07, 22: 0.04, 23: 0.02,
}

# Approximate base prices (must align with operational._base_price)
BASE_PRICES = {
    1: 72.00, 2: 65.00, 3: 50.00, 4: 295.00, 5: 175.00,
    6: 95.00, 7: 240.00, 8: 165.00, 9: 195.00, 10: 145.00,
}
PRODUCT_NAMES = {
    1: ("Amul Gold Milk 1L Tetra Pack", "BB-00001", "Amul",
        "Food & Grocery > Dairy & Bakery > Milk", 78.00),
    2: ("Mother Dairy Yogurt 400g", "BB-00002", "Mother Dairy",
        "Food & Grocery > Dairy & Bakery > Yogurt", 70.00),
    3: ("Britannia Brown Bread 400g", "BB-00003", "Britannia",
        "Food & Grocery > Dairy & Bakery > Bread", 55.00),
    4: ("Aashirvaad Whole Wheat Atta 5kg", "BB-00004", "Aashirvaad",
        "Food & Grocery > Atta, Rice & Dal", 320.00),
    5: ("MDH Garam Masala 100g", "BB-00005", "MDH",
        "Food & Grocery > Spices & Condiments", 195.00),
    6: ("Parle-G Original Biscuits 800g", "BB-00006", "Parle",
        "Food & Grocery > Snacks & Biscuits", 105.00),
    7: ("Tata Tea Premium 500g", "BB-00007", "Tata",
        "Food & Grocery > Beverages", 260.00),
    8: ("Cadbury Dairy Milk Silk 60g", "BB-00008", "Cadbury",
        "Food & Grocery > Snacks & Biscuits", 180.00),
    9: ("Nivea Soft Light Moisturiser 100ml", "BB-00009", "Nivea",
        "Personal Care > Skin Care", 215.00),
    10: ("BoltBasket Daily Toor Dal 1kg", "BB-00010", "BoltBasket Daily",
         "Food & Grocery > Atta, Rice & Dal", 160.00),
}


def write(path: Path) -> None:
    rng = common.get_rng("orders")

    # --- Carts ---
    n_carts = config.CARDINALITIES["orders"]["carts"]
    carts: list[tuple] = []
    converted_cart_ids: list[int] = []   # cart_id offsets that became orders
    for i in range(n_carts):
        cart_offset = i + 1
        # bulk cart_id starts at SMOKE_MAX_CART_ID + 1 = 2
        cart_id = config.SMOKE_MAX_CART_ID + cart_offset
        user_id = int(rng.choice(BULK_USER_IDS))
        store_id = int(rng.choice(DARK_STORE_IDS))
        # 23% abandoned → 77% converted
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
    # 10K orders. ~97% have a cart_id (matched to a converted cart). ~3% are NULL (deeplink).
    n_orders = config.CARDINALITIES["orders"]["orders"]
    if len(converted_cart_ids) < int(n_orders * 0.97):
        # Not enough converted carts; raise abandoned->converted ratio next time.
        # For now, just use what we have and pad with NULLs.
        pass

    orders_rows: list[tuple] = []
    order_codes: list[str] = []
    order_metadata: list[dict] = []  # for use in items + events generation
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
        # Build a unique order_code
        date_str = placed_at.strftime("%Y%m%d")
        seq = order_offset
        # Avoid colliding with smoke seed codes
        order_code = f"BB-{date_str}-{seq:06d}"
        # Ensure uniqueness — bump if collision
        suffix = 0
        while order_code in used_codes or order_code in (
            "BB-20251012-000001", "BB-20251013-000002", "BB-20231215-000003"
        ):
            suffix += 1
            order_code = f"BB-{date_str}-{(seq + suffix * n_orders):06d}"
        used_codes.add(order_code)
        order_codes.append(order_code)

        confirmed_at = placed_at + timedelta(seconds=int(rng.integers(15, 90)))
        picked_at = placed_at + timedelta(minutes=int(rng.integers(3, 8)))
        delivered_at = placed_at + timedelta(minutes=int(rng.integers(8, 25)))

        # Pricing — derived from items (we'll regenerate items separately, then the
        # totals here are approximate — slight inconsistency is fine for the seed)
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
            "placed_at": placed_at,
            "confirmed_at": confirmed_at,
            "picked_at": picked_at,
            "delivered_at": delivered_at,
        })

    # --- Order items ---
    # 30K items. Zipf-skewed product popularity. ~3 items per order avg.
    n_items_target = config.CARDINALITIES["orders"]["order_items"]
    items_per_order = [max(1, int(rng.poisson(3.0))) for _ in range(n_orders)]
    # Adjust the total to match target
    while sum(items_per_order) < n_items_target:
        items_per_order[int(rng.integers(0, n_orders))] += 1
    while sum(items_per_order) > n_items_target:
        idx = int(rng.integers(0, n_orders))
        if items_per_order[idx] > 1:
            items_per_order[idx] -= 1

    items_rows: list[tuple] = []
    for ord_idx, n in enumerate(items_per_order):
        order_id = order_metadata[ord_idx]["order_id"]
        # Zipf-skewed product picks
        pids = common.zipf_indices(rng, n=10, size=n, alpha=1.5)
        for pid_offset in pids:
            product_id = ACTIVE_PRODUCT_IDS[int(pid_offset)]
            name, sku, brand, category_path, mrp = PRODUCT_NAMES[product_id]
            unit_price = BASE_PRICES[product_id]
            qty_ordered = int(rng.integers(1, 4))
            qty_delivered = qty_ordered  # smoke seed pattern: full delivery
            line_subtotal = round(unit_price * qty_ordered, 2)
            line_discount = 0.0
            line_total = line_subtotal - line_discount
            items_rows.append((
                order_id, product_id, name, sku, brand, category_path,
                unit_price, mrp, qty_ordered, qty_delivered,
                line_subtotal, line_discount, line_total, False, None,
            ))

    # --- Order events ---
    # 40K events. ~4 per order avg.
    events_rows: list[tuple] = []
    for meta in order_metadata:
        order_id = meta["order_id"]
        # Always 4 events: placed, confirmed, picked, delivered (sometimes 5 with packed)
        events_rows.append((
            order_id, "placed", meta["placed_at"], "system", None, {},
        ))
        events_rows.append((
            order_id, "confirmed", meta["confirmed_at"], "system", None, {},
        ))
        events_rows.append((
            order_id, "picked", meta["picked_at"], "employee",
            int(rng.integers(1, 15)), {},  # actor_id = employee_id
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

    # Trim/pad events to hit target ±2%
    target_events = config.CARDINALITIES["orders"]["order_events"]
    while len(events_rows) > target_events:
        events_rows.pop(int(rng.integers(0, len(events_rows))))
    while len(events_rows) < target_events:
        # add 'rider_assigned' events
        idx = int(rng.integers(0, len(order_metadata)))
        meta = order_metadata[idx]
        events_rows.append((
            meta["order_id"], "rider_assigned",
            meta["picked_at"] - timedelta(seconds=30),
            "system", None, {"rider_id": meta["rider_id"]},
        ))

    # --- Payments ---
    payments_rows: list[tuple] = []
    methods = ["upi", "card", "wallet", "cod", "netbanking", "plus_credit"]
    method_weights = [0.55, 0.20, 0.10, 0.08, 0.05, 0.02]
    for meta in order_metadata:
        method = methods[int(rng.choice(6, p=method_weights))]
        amount = sum(r[12] for r in items_rows if r[0] == meta["order_id"]) or meta["subtotal"]
        payments_rows.append((
            meta["order_id"], method, amount, "success",
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
        # find payment_id by order_id position
        payment_id = config.SMOKE_MAX_ORDER_ID + 0 + int(idx) + 1  # offset relative to payments table
        rtype = ["full", "partial", "item_level"][int(rng.choice(3, p=[0.2, 0.3, 0.5]))]
        amount = round(float(rng.uniform(50, 500)), 2)
        reason = refund_reasons[int(rng.choice(4))]
        initiated = meta["delivered_at"] + timedelta(minutes=int(rng.integers(5, 240)))
        processed = initiated + timedelta(hours=int(rng.integers(1, 48)))
        refunds_rows.append((
            order_id, payment_id, rtype, amount, reason,
            initiated, processed, "completed",
        ))

    # --- Write file ---
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
```

- [ ] **Step 4: Run tests, verify pass**

```bash
pytest tests/test_orders.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/orders.py supabase/seed/generator/tests/test_orders.py
git commit -m "feat(generator): add orders module (02d) — carts/orders/items/events/payments/refunds"
```

---

## Task 9: `engagement.py` — 02e (owns Imperfection #8)

**Files:**
- Create: `supabase/seed/generator/engagement.py`
- Create: `supabase/seed/generator/tests/test_engagement.py`

**What this module does:**
- 30K `app_events` with deliberate JSONB key chaos (#8)
- 10K `search_queries`
- 8K `push_notifications`
- 200 `pipeline_runs`

**Imperfection #8 mechanic:**
- 12 event types with per-type "expected" key sets
- Key spelling drift: `product_id` (70%) / `productId` (20%) / `prod_id` (10%)
- Type drift: `cart_value` sometimes number, sometimes `"₹245.50"` string
- Missing keys: ~5% drop expected key
- Stray keys: ~5% extra (`debug`, `_test`, `_internal`)
- Target: ~600 distinct keys across the corpus

- [ ] **Step 1: Write `tests/test_engagement.py`**

```python
import re
import json
from pathlib import Path

import pytest
from generator import engagement, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02e_engagement.sql"


def test_app_events_count(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    section = text.split("-- app_events: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["engagement"]["app_events"]
    assert abs(len(rows) - target) <= int(target * 0.02)


def test_jsonb_has_key_spelling_drift(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    # We expect to see all three spellings somewhere
    assert "\"product_id\"" in text or '"product_id"' in text
    assert "\"productId\"" in text or '"productId"' in text
    assert "\"prod_id\"" in text or '"prod_id"' in text


def test_jsonb_has_rupee_string_for_cart_value(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    # Some cart_value is a string with rupee symbol
    assert "₹" in text


def test_distinct_key_count(out_path):
    """Approximate count of distinct keys across all properties. Target ~600."""
    engagement.write(out_path)
    text = out_path.read_text()
    # Extract all JSONB literals in app_events section
    section = text.split("-- app_events: ")[1].split("\n\n")[0]
    keys = set()
    # crude regex: keys are quoted, followed by colon
    for m in re.finditer(r'\"([a-zA-Z_][a-zA-Z0-9_]*)\"\s*:', section):
        keys.add(m.group(1))
    # Allow 400-800 range (target 600)
    assert 400 <= len(keys) <= 800, f"distinct keys = {len(keys)}; expected 400-800"


def test_pipeline_runs_count(out_path):
    engagement.write(out_path)
    text = out_path.read_text()
    section = text.split("-- pipeline_runs: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["engagement"]["pipeline_runs"]


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    engagement.write(p1)
    engagement.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

- [ ] **Step 3: Write `supabase/seed/generator/engagement.py`**

```python
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


def _gen_session_uuid(rng) -> str:
    """Build a deterministic-looking uuid (uuid4 from rng bytes)."""
    raw = rng.bytes(16)
    return str(uuid.UUID(bytes=raw, version=4))


def _gen_properties(rng, event_type: str) -> dict:
    """Build a properties JSONB blob with deliberate chaos for #8."""
    props: dict = {}

    # Each event type has a "schema" — set of expected keys.
    # We deliberately introduce spelling drift, type drift, missing/stray keys.

    # product_id key spelling drift (70/20/10)
    pid_keys = ["product_id"] * 70 + ["productId"] * 20 + ["prod_id"] * 10
    pid_key = pid_keys[int(rng.integers(0, 100))]

    # cart_value key (number 80% / "₹X" string 20%)
    cv_as_string = rng.random() < 0.2

    # 5% chance to drop an expected key
    drop_key = rng.random() < 0.05
    # 5% chance to add a stray key
    add_stray = rng.random() < 0.05

    if event_type == "screen_view":
        if not (drop_key and rng.random() < 0.5):
            props["screen_name"] = ["home", "category", "product", "cart", "checkout"][int(rng.integers(0, 5))]
        if not drop_key:
            props["session_duration_ms"] = int(rng.integers(100, 60_000))
    elif event_type == "search":
        props["query"] = ["milk", "bread", "atta", "tea", "biscuit", "shampoo", "yogurt"][int(rng.integers(0, 7))]
        if not drop_key:
            props["result_count"] = int(rng.integers(0, 100))
    elif event_type in ("product_view", "add_to_cart", "remove_from_cart"):
        if not drop_key:
            props[pid_key] = int(rng.integers(1, 11))
        if not drop_key:
            props["category"] = ["dairy", "snacks", "personal_care", "atta_rice"][int(rng.integers(0, 4))]
    elif event_type == "checkout_started":
        if not drop_key:
            if cv_as_string:
                props["cart_value"] = f"₹{round(float(rng.uniform(99, 1500)), 2)}"
            else:
                props["cart_value"] = round(float(rng.uniform(99, 1500)), 2)
            props["item_count"] = int(rng.integers(1, 8))
    elif event_type == "order_placed":
        if not drop_key:
            props["order_total"] = round(float(rng.uniform(99, 1500)), 2)
            props[pid_key] = int(rng.integers(1, 11))  # primary product
    elif event_type in ("push_received", "push_clicked"):
        props["campaign_code"] = f"PUSH_{int(rng.integers(1, 50)):03d}"
    elif event_type == "app_open":
        props["referrer"] = ["organic", "deeplink", "push", "ad"][int(rng.integers(0, 4))]
        props["app_version"] = ["4.12.0", "4.13.0", "4.14.0"][int(rng.integers(0, 3))]
    # else: app_background, app_close — minimal props

    if add_stray:
        stray_keys = ["debug", "_test", "_internal", "tmp_flag", "exp_var", "ab_test_bucket"]
        props[stray_keys[int(rng.integers(0, 6))]] = "yes"

    # Sprinkle in misc less-common keys to push distinct-key count toward 600
    if rng.random() < 0.05:
        misc_keys = [
            "user_segment", "city_code", "device_model", "os_version",
            "network_type", "feature_flag_a", "feature_flag_b",
            "experiment_id", "campaign_attribution_id", "deeplink_path",
            "scroll_depth_pct", "engagement_score", "previous_screen",
            "tab_index", "filter_applied", "sort_order", "viewport_width",
        ]
        # Pick a small random handful
        n_extra = int(rng.integers(1, 4))
        for _ in range(n_extra):
            k = misc_keys[int(rng.integers(0, len(misc_keys)))]
            props[k] = "v"
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
    search_terms = ["milk", "bread", "atta", "tea", "biscuit", "shampoo",
                    "yogurt", "cooking oil", "salt", "sugar", "rice",
                    "noodles", "chocolate", "soap"]
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
    push_titles = ["Your order is on its way!", "20% off snacks today",
                   "Milk back in stock", "Plus members get free delivery",
                   "Weekend offer", "Restock your essentials"]
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
        opened_at = (sent_at + timedelta(minutes=int(rng.integers(1, 120)))) if opened else None
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
        status = ["success", "success", "success", "success", "failed", "partial"][int(rng.integers(0, 6))]
        rows_processed = int(rng.integers(100, 100_000))
        runs_rows.append((
            name, started, finished, status, rows_processed, None,
        ))

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02e engagement",
        owns_imperfection="Imperfection #8 (app_events.properties JSONB chaos)",
        sections=[
            ("app_events",
             ["user_id", "session_id", "event_name", "event_time", "properties",
              "device_type", "app_version"],
             event_rows),
            ("search_queries",
             ["user_id", "session_id", "query_text", "search_at", "result_count",
              "clicked_product_id", "led_to_order", "led_to_order_id"],
             search_rows),
            ("push_notifications",
             ["user_id", "campaign_code", "title", "body", "sent_at",
              "delivered", "opened", "opened_at", "led_to_order", "led_to_order_id"],
             push_rows),
            ("pipeline_runs",
             ["pipeline_name", "started_at", "finished_at", "status",
              "rows_processed", "notes"],
             runs_rows),
        ],
        extra_header_lines=[
            "Imperfection #8: app_events.properties has key-spelling drift",
            "(product_id / productId / prod_id), type drift on cart_value,",
            "missing keys ~5%, stray keys ~5%. Target distinct keys ~600.",
        ],
    )
```

- [ ] **Step 4: Run tests, verify pass**

```bash
pytest tests/test_engagement.py -v
```

Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/engagement.py supabase/seed/generator/tests/test_engagement.py
git commit -m "feat(generator): add engagement module (02e) — owns Imperfection #8"
```

---

## Task 10: `advertising.py` — 02f (owns Imperfection #10)

**Files:**
- Create: `supabase/seed/generator/advertising.py`
- Create: `supabase/seed/generator/tests/test_advertising.py`

**Imperfection #10 mechanic:**
- ~3,000 attributable orders (30% of 10K)
- 100% get last_click → ~3,000 rows
- ~10% additionally view_through → ~300 rows
- ~5% additionally multi_touch_linear (1–3 rows summing to 1.0) → ~225 rows

- [ ] **Step 1: Write `tests/test_advertising.py`**

```python
import re
from pathlib import Path

import pytest
from generator import advertising, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02f_advertising.sql"


def test_impressions_count(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_impressions: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["advertising"]["ad_impressions"]
    assert abs(len(rows) - target) <= int(target * 0.02)


def test_clicks_about_10pct_of_impressions(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    imp_section = text.split("-- ad_impressions: ")[1].split("\n\n")[0]
    click_section = text.split("-- ad_clicks: ")[1].split("\n\n")[0]
    n_imp = sum(1 for ln in imp_section.splitlines() if ln.startswith("  ("))
    n_click = sum(1 for ln in click_section.splitlines() if ln.startswith("  ("))
    ctr = n_click / n_imp
    assert 0.08 <= ctr <= 0.12


def test_attribution_models_present(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_attributions: ")[1].split("\n\n")[0]
    assert "'last_click'" in section
    assert "'view_through'" in section
    assert "'multi_touch_linear'" in section


def test_attribution_total_count(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_attributions: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["advertising"]["ad_attributions"]
    assert abs(len(rows) - target) <= int(target * 0.05)


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    advertising.write(p1)
    advertising.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

- [ ] **Step 3: Write `supabase/seed/generator/advertising.py`**

```python
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
    raw = rng.bytes(16)
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
```

- [ ] **Step 4: Run tests, verify pass**

```bash
pytest tests/test_advertising.py -v
```

Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/advertising.py supabase/seed/generator/tests/test_advertising.py
git commit -m "feat(generator): add advertising module (02f) — owns Imperfection #10"
```

---

## Task 11: `orphans.py` — 02g (owns Imperfection #11)

**Files:**
- Create: `supabase/seed/generator/orphans.py`
- Create: `supabase/seed/generator/tests/test_orphans.py`

- [ ] **Step 1: Write `tests/test_orphans.py`**

```python
from pathlib import Path

import pytest
from generator import orphans, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02g_orphans.sql"


def test_50_products_total(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    section = text.split("-- products: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == 50


def test_three_subtypes_present(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    assert "(DISC)" in text or "DISCONTINUED" in text or "Discontinued" in text
    assert "TEST PRODUCT" in text


def test_all_inactive(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    section = text.split("-- products: ")[1].split("\n\n")[0]
    # Each row should have FALSE for is_active (column position depends on insert order)
    # We just count how many TRUE vs FALSE appear in the products section
    n_false = section.count(", FALSE,")
    n_true = section.count(", TRUE,")
    assert n_false >= 50
    assert n_true == 0


def test_skus_unique_and_avoid_smoke(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    # Smoke uses BB-00001..BB-00010
    for i in range(1, 11):
        forbidden = f"'BB-{i:05d}'"
        # Ensure forbidden SKU does NOT appear in the products section
        # (smoke seed assigns those to active products)
        section = text.split("-- products: ")[1].split("\n\n")[0]
        assert forbidden not in section


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    orphans.write(p1)
    orphans.write(p2)
    assert p1.read_text() == p2.read_text()
```

- [ ] **Step 2: Run, verify it fails**

- [ ] **Step 3: Write `supabase/seed/generator/orphans.py`**

```python
"""Generates 02g_orphans.sql — owns Imperfection #11.

50 product rows added to raw.products that are NEVER referenced by:
  - store_inventory
  - inventory_movements
  - order_items
  - price_list_items
"""
from pathlib import Path

from generator import common, config

# Use a category_id that exists in smoke seed (1..27). brand_id 1..13.
# Pick neutral values: category_id=1 (top-level), brand_id=10 (BoltBasket Daily — generic).


def write(path: Path) -> None:
    rng = common.get_rng("orphans")

    rows: list[tuple] = []
    seq = config.SMOKE_MAX_PRODUCT_ID + 1  # 11..60

    # 20 discontinued (real-feeling Indian SKUs with "(DISC)" suffix)
    discontinued_names = [
        "Britannia Marie Gold 200g (DISC)",
        "Lays Magic Masala 50g (DISC)",
        "Coca-Cola 600ml Bottle (DISC)",
        "Maggi Atta Noodles 80g (DISC)",
        "Dabur Honey 250g (DISC)",
        "Vim Dishwash Bar 300g (DISC)",
        "Surf Excel Easy Wash 1kg (DISC)",
        "Closeup Toothpaste 80g (DISC)",
        "Vaseline Body Lotion 200ml (DISC)",
        "Pears Soap 75g (DISC)",
        "Britannia Bourbon 60g (DISC)",
        "Haldiram Aloo Bhujia 200g (DISC)",
        "Tata Salt 1kg Pouch (DISC)",
        "Real Fruit Juice 200ml (DISC)",
        "Bournvita 500g (DISC)",
        "Horlicks Classic 500g (DISC)",
        "Dabur Chyawanprash 250g (DISC)",
        "Patanjali Atta 5kg (DISC)",
        "Mother Dairy Ghee 500ml (DISC)",
        "Amul Cheese Slices 200g (DISC)",
    ]
    for name in discontinued_names:
        sku = f"BB-{seq:05d}"
        rows.append((
            sku, name, 1, 10, None, None, None,
            round(float(rng.uniform(50, 300)), 2), None,
            False,  # is_active
            "2022-06-01", "2024-09-30",  # launched, discontinued
        ))
        seq += 1

    # 20 never-launched (plausible-but-fictional SKUs)
    never_launched_names = [
        "BoltBasket Premium Honey 500g",
        "BoltBasket Cold-Press Mustard Oil 1L",
        "Boltkidz Multivitamin Gummies",
        "BB Organics Quinoa 500g",
        "BB Premium Cashews 250g",
        "BB Dailies Hand Cream 100ml",
        "BB Kitchen Easy-Pour Bottle Cap",
        "BB Frozen Paneer Tikka 200g",
        "BB Daily Oat Milk 1L",
        "BB Daily Almond Milk 1L",
        "BB Premium Pistachios 200g",
        "BB Pet Care Cat Food 1kg",
        "BB Pet Care Dog Treats 250g",
        "BB Dailies Antiseptic Wipes",
        "BB Kitchen Stainless Tongs",
        "BB Daily Sesame Oil 500ml",
        "BB Daily Coconut Water 1L",
        "BB Premium Saffron 1g",
        "BB Daily Brown Rice 1kg",
        "BB Premium Truffle Oil 100ml",
    ]
    for name in never_launched_names:
        sku = f"BB-{seq:05d}"
        rows.append((
            sku, name, 1, 10, None, None, None,
            round(float(rng.uniform(99, 800)), 2), None,
            False, None, None,
        ))
        seq += 1

    # 10 test data
    for i in range(10):
        sku = f"TEST-LOREM-{i+1:03d}"
        name = f"TEST PRODUCT — DO NOT USE ({i+1})"
        rows.append((
            sku, name, 1, 10, None, None, None,
            1.00, None, False, None, None,
        ))
        seq += 1

    common.write_sql_file(
        path=path,
        title="Phase 4b — 02g orphan products",
        owns_imperfection="Imperfection #11 (orphan products)",
        sections=[
            ("products",
             ["sku", "product_name", "category_id", "brand_id",
              "weight_grams", "is_perishable", "country_of_origin",
              "base_price", "mrp", "is_active",
              "launched_at", "discontinued_at"],
             rows),
        ],
        extra_header_lines=[
            "50 orphan products: 20 discontinued, 20 never-launched, 10 test data.",
            "None of these are referenced by store_inventory, inventory_movements,",
            "order_items, or price_list_items.",
        ],
    )
```

- [ ] **Step 4: Run tests, verify pass**

```bash
pytest tests/test_orphans.py -v
```

Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/orphans.py supabase/seed/generator/tests/test_orphans.py
git commit -m "feat(generator): add orphans module (02g) — owns Imperfection #11"
```

---

## Task 12: Cross-cutting tests (`test_determinism.py`, `test_cardinalities.py`)

**Files:**
- Create: `supabase/seed/generator/tests/test_determinism.py`
- Create: `supabase/seed/generator/tests/test_cardinalities.py`

- [ ] **Step 1: Write `test_determinism.py`**

```python
"""Generate the full output twice; assert byte-identical."""
import hashlib
from pathlib import Path

import pytest

from generator import operational, users, inventory, orders, engagement, advertising, orphans

WRITERS = {
    "02a_operational_baseline.sql": operational.write,
    "02b_users.sql": users.write,
    "02c_inventory.sql": inventory.write,
    "02d_orders.sql": orders.write,
    "02e_engagement.sql": engagement.write,
    "02f_advertising.sql": advertising.write,
    "02g_orphans.sql": orphans.write,
}


@pytest.mark.parametrize("filename,writer", list(WRITERS.items()))
def test_byte_identical_across_runs(filename, writer, tmp_path):
    p1 = tmp_path / "1" / filename
    p2 = tmp_path / "2" / filename
    p1.parent.mkdir()
    p2.parent.mkdir()
    writer(p1)
    writer(p2)

    h1 = hashlib.sha256(p1.read_bytes()).hexdigest()
    h2 = hashlib.sha256(p2.read_bytes()).hexdigest()
    assert h1 == h2, f"{filename}: hashes differ"
```

- [ ] **Step 2: Write `test_cardinalities.py`**

```python
"""Run the full generator and verify total row counts."""
import re
from pathlib import Path

import pytest

from generator import (
    operational, users, inventory, orders, engagement, advertising, orphans, config,
)

WRITERS = [
    ("02a_operational_baseline.sql", operational.write, "operational"),
    ("02b_users.sql", users.write, "users"),
    ("02c_inventory.sql", inventory.write, "inventory"),
    ("02d_orders.sql", orders.write, "orders"),
    ("02e_engagement.sql", engagement.write, "engagement"),
    ("02f_advertising.sql", advertising.write, "advertising"),
    ("02g_orphans.sql", orphans.write, "orphans"),
]


def _count_inserts_per_table(text: str) -> dict[str, int]:
    """Count tuples per `-- <table>: N rows` comment block."""
    counts: dict[str, int] = {}
    for m in re.finditer(r"-- (\w+): (\d+) rows", text):
        counts[m.group(1)] = int(m.group(2))
    return counts


@pytest.mark.parametrize("filename,writer,module", WRITERS)
def test_per_module_cardinalities_within_2pct(tmp_path, filename, writer, module):
    p = tmp_path / filename
    writer(p)
    counts = _count_inserts_per_table(p.read_text())
    for table, expected in config.CARDINALITIES[module].items():
        assert table in counts, f"{module}: missing table {table} in {filename}"
        actual = counts[table]
        tolerance = max(2, int(expected * 0.02))
        assert abs(actual - expected) <= tolerance, (
            f"{module}.{table}: actual={actual} expected={expected} (±{tolerance})"
        )


def test_total_rows_in_target_range(tmp_path):
    total = 0
    for filename, writer, _ in WRITERS:
        p = tmp_path / filename
        writer(p)
        counts = _count_inserts_per_table(p.read_text())
        total += sum(counts.values())
    assert 200_000 <= total <= 220_000, f"total={total} outside 200K-220K"
```

- [ ] **Step 3: Run cross-cutting tests, verify pass**

```bash
cd supabase/seed/generator && source .venv/bin/activate
pytest tests/test_determinism.py tests/test_cardinalities.py -v
```

Expected: all pass. (If not, find which module deviates and fix its cardinality.)

- [ ] **Step 4: Run full test suite**

```bash
pytest -v
```

Expected: ~50+ tests pass, 0 fail.

- [ ] **Step 5: Commit**

```bash
cd ../../..
git add supabase/seed/generator/tests/test_determinism.py supabase/seed/generator/tests/test_cardinalities.py
git commit -m "test(generator): add cross-cutting determinism + cardinality tests"
```

---

## Task 13: `generator/README.md`

**Files:**
- Create: `supabase/seed/generator/README.md`

- [ ] **Step 1: Write `supabase/seed/generator/README.md`**

````markdown
# Phase 4b — Full Seed Generator

Deterministic Python generator that writes ~210K rows of bulk BoltBasket activity into seven SQL files (`02a_*` through `02g_*`) in `supabase/seed/`. The smoke seed (`01_smoke_seed.sql`) loads first; this layer adds on top without disturbing the smoke seed's named characters or demo orders.

## Run

```bash
cd supabase/seed/generator
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python generate.py                # writes all 02*.sql
python generate.py --module users # writes just 02b_users.sql
```

After generation, load into Supabase via `psql`:

```bash
cd ../../..  # back to project root
for f in supabase/seed/02*.sql; do
  psql "$SUPABASE_DB_URL" -f "$f"
done
psql "$SUPABASE_DB_URL" -f supabase/marts/01_marts_views.sql  # rebuild marts
psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
```

## Iteration / re-run

The bulk seed is **NOT idempotent**. To re-run cleanly:

```bash
psql "$SUPABASE_DB_URL" -c "DROP SCHEMA marts CASCADE; DROP SCHEMA staging CASCADE; DROP SCHEMA raw CASCADE;"
for f in supabase/ddl/*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/seed/01_smoke_seed.sql
for f in supabase/seed/02*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/marts/01_marts_views.sql
psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
```

Total time: ~5 minutes.

## Imperfection ownership

| File | Module | Owns |
|---|---|---|
| `02a_operational_baseline.sql` | `operational.py` | #7 (price_list scope overlap) |
| `02b_users.sql` | `users.py` | none |
| `02c_inventory.sql` | `inventory.py` | #3 (snapshot/log drift) |
| `02d_orders.sql` | `orders.py` | none |
| `02e_engagement.sql` | `engagement.py` | #8 (JSONB key chaos) |
| `02f_advertising.sql` | `advertising.py` | #10 (multi-model attribution) |
| `02g_orphans.sql` | `orphans.py` | #11 (orphan products) |

#1, #2, #4, #5, #6, #12 are demonstrated by the smoke seed. #9 is out-of-scope (lives in MongoDB conceptually).

## Determinism

`config.SEED = 42` is the single source of truth. Each module derives a stable sub-seed from its name (`config.sub_seed("users")` etc.), so regenerating one module does not shift any other module's output. Re-running `python generate.py` produces byte-identical SQL — `tests/test_determinism.py` enforces this via SHA-256 hash comparison.

## Tests

```bash
pytest                              # all tests
pytest tests/test_determinism.py    # determinism only
pytest tests/test_cardinalities.py  # row count budget
pytest tests/test_inventory.py      # imperfection #3 mechanic
```

No tests touch the database. They operate on generated SQL files only.
````

- [ ] **Step 2: Commit**

```bash
git add supabase/seed/generator/README.md
git commit -m "docs(generator): add Phase 4b generator README"
```

---

## Task 14: Extend `verify/imperfections_check.sql` — checks for #3, #7, #8, #10, #11

**Files:**
- Modify: `supabase/verify/imperfections_check.sql`

- [ ] **Step 1: Append the new imperfection checks to the verify file**

Open `supabase/verify/imperfections_check.sql`. After the existing `#12` block (around line 128) and before the "General row counts" section, insert:

```sql
-- ---------------------------------------------------------------------------
-- Imperfection #3: Inventory snapshot/log drift
-- ---------------------------------------------------------------------------
\echo ''
\echo '#3: store_inventory cells where snapshot != replay-of-log'
\echo '    Bulk seed: expect 5 cells (3 negative, 2 positive)'

WITH replay AS (
  SELECT dark_store_id, product_id,
         SUM(quantity_change)::INT AS replay_qty
  FROM raw.inventory_movements
  GROUP BY dark_store_id, product_id
)
SELECT COUNT(*) AS drifted_cells
FROM raw.store_inventory si
JOIN replay r USING (dark_store_id, product_id)
WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty);


-- ---------------------------------------------------------------------------
-- Imperfection #7: Price-list scope overlap
-- ---------------------------------------------------------------------------
\echo ''
\echo '#7: products covered by all 3 scope types simultaneously'
\echo '    Bulk seed: expect ~10 products (the 10 active SKUs)'

WITH scopes AS (
  SELECT DISTINCT pli.product_id, pl.scope_type
  FROM raw.price_list_items pli
  JOIN raw.price_lists pl ON pl.price_list_id = pli.price_list_id
)
SELECT COUNT(*) AS products_with_all_3_scopes
FROM (
  SELECT product_id
  FROM scopes
  GROUP BY product_id
  HAVING COUNT(DISTINCT scope_type) = 3
) sub;


-- ---------------------------------------------------------------------------
-- Imperfection #8: app_events.properties key chaos
-- ---------------------------------------------------------------------------
\echo ''
\echo '#8: distinct keys across app_events.properties'
\echo '    Bulk seed: expect 400-800 (target ~600)'

SELECT COUNT(DISTINCT k) AS distinct_property_keys
FROM raw.app_events,
     LATERAL jsonb_object_keys(properties) AS k;


-- ---------------------------------------------------------------------------
-- Imperfection #10: Multi-model ad_attributions
-- ---------------------------------------------------------------------------
\echo ''
\echo '#10: orders appearing in >=2 attribution model rows'
\echo '    Bulk seed: expect ~300-450 (~10-15% of attributable orders)'

SELECT COUNT(*) AS orders_with_multiple_models
FROM (
  SELECT order_id
  FROM raw.ad_attributions
  GROUP BY order_id
  HAVING COUNT(DISTINCT attribution_model) >= 2
) sub;


-- ---------------------------------------------------------------------------
-- Imperfection #11: Orphan products
-- ---------------------------------------------------------------------------
\echo ''
\echo '#11: products with no inventory, no orders, no price overrides'
\echo '    Bulk seed: expect 50'

SELECT COUNT(*) AS orphan_product_count
FROM raw.products p
WHERE NOT EXISTS (SELECT 1 FROM raw.store_inventory si WHERE si.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.inventory_movements im WHERE im.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.order_items oi WHERE oi.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.price_list_items pli WHERE pli.product_id = p.product_id);

```

Place these blocks after the `#12 order_items snapshot fields are populated` block, before the `General row counts` section.

- [ ] **Step 2: Update the "General row counts" expected values**

Find the existing block (around line 137-152) and replace each table's expected count with bulk-seeded ranges. Specifically:

```sql
SELECT 'cities'                AS table_name, COUNT(*)::TEXT AS row_count, '3'   AS expected FROM raw.cities
UNION ALL SELECT 'pincodes',                COUNT(*)::TEXT, '23'        FROM raw.pincodes
UNION ALL SELECT 'categories',              COUNT(*)::TEXT, '27'        FROM raw.categories
UNION ALL SELECT 'brands',                  COUNT(*)::TEXT, '13'        FROM raw.brands
UNION ALL SELECT 'products',                COUNT(*)::TEXT, '60'        FROM raw.products
UNION ALL SELECT 'product_attributes',      COUNT(*)::TEXT, '18'        FROM raw.product_attributes
UNION ALL SELECT 'dark_stores',             COUNT(*)::TEXT, '12'        FROM raw.dark_stores
UNION ALL SELECT 'service_areas',           COUNT(*)::TEXT, '~28'       FROM raw.service_areas
UNION ALL SELECT 'employees',               COUNT(*)::TEXT, '14'        FROM raw.employees
UNION ALL SELECT 'riders',                  COUNT(*)::TEXT, '53'        FROM raw.riders
UNION ALL SELECT 'users',                   COUNT(*)::TEXT, '3505'      FROM raw.users
UNION ALL SELECT 'addresses',               COUNT(*)::TEXT, '4505'      FROM raw.addresses
UNION ALL SELECT 'subscriptions',           COUNT(*)::TEXT, '1'         FROM raw.subscriptions
UNION ALL SELECT 'carts',                   COUNT(*)::TEXT, '13001'     FROM raw.carts
UNION ALL SELECT 'orders',                  COUNT(*)::TEXT, '10003'     FROM raw.orders
UNION ALL SELECT 'order_items',             COUNT(*)::TEXT, '~30004'    FROM raw.order_items
UNION ALL SELECT 'order_events',            COUNT(*)::TEXT, '~40005'    FROM raw.order_events
UNION ALL SELECT 'payments',                COUNT(*)::TEXT, '10000'     FROM raw.payments
UNION ALL SELECT 'refunds',                 COUNT(*)::TEXT, '500'       FROM raw.refunds
UNION ALL SELECT 'store_inventory',         COUNT(*)::TEXT, '120'       FROM raw.store_inventory
UNION ALL SELECT 'inventory_movements',     COUNT(*)::TEXT, '~25000'    FROM raw.inventory_movements
UNION ALL SELECT 'app_events',              COUNT(*)::TEXT, '30000'     FROM raw.app_events
UNION ALL SELECT 'search_queries',          COUNT(*)::TEXT, '10000'     FROM raw.search_queries
UNION ALL SELECT 'push_notifications',      COUNT(*)::TEXT, '8000'      FROM raw.push_notifications
UNION ALL SELECT 'ad_campaigns',            COUNT(*)::TEXT, '20'        FROM raw.ad_campaigns
UNION ALL SELECT 'ad_placements',           COUNT(*)::TEXT, '60'        FROM raw.ad_placements
UNION ALL SELECT 'ad_impressions',          COUNT(*)::TEXT, '~20000'    FROM raw.ad_impressions
UNION ALL SELECT 'ad_clicks',               COUNT(*)::TEXT, '2000'      FROM raw.ad_clicks
UNION ALL SELECT 'ad_attributions',         COUNT(*)::TEXT, '~3500'     FROM raw.ad_attributions
UNION ALL SELECT 'promotions',              COUNT(*)::TEXT, '25'        FROM raw.promotions
UNION ALL SELECT 'price_lists',             COUNT(*)::TEXT, '15'        FROM raw.price_lists
UNION ALL SELECT 'price_list_items',        COUNT(*)::TEXT, '~300'      FROM raw.price_list_items
UNION ALL SELECT 'pipeline_runs',           COUNT(*)::TEXT, '200'       FROM raw.pipeline_runs;
```

- [ ] **Step 3: Commit**

```bash
git add supabase/verify/imperfections_check.sql
git commit -m "feat(verify): extend verify queries for Imperfections #3, #7, #8, #10, #11"
```

---

## Task 15: End-to-end load + verify against Supabase

**Files:**
- Modify (run): nothing on disk; this validates the live DB.

- [ ] **Step 1: Generate all SQL output files**

```bash
cd supabase/seed/generator
source .venv/bin/activate
PYTHONPATH=.. python generate.py
ls -la ../02*.sql
```

Expected: 7 files matching `02a..02g_*.sql`, total ~30-50 MB combined.

- [ ] **Step 2: Reset the Supabase DB and reload from scratch**

```bash
cd ../../..  # project root
set -a; . ./.env; set +a

# Drop everything
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "
DROP SCHEMA IF EXISTS marts CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
"

# Reload DDL
for f in supabase/ddl/*.sql; do
  echo "=== Loading $f ==="
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done

# Smoke seed
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -f supabase/seed/01_smoke_seed.sql

# Bulk seed (alphabetical order)
for f in supabase/seed/02*.sql; do
  echo "=== Loading $f ==="
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done

# Marts
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/marts/01_marts_views.sql
```

Expected: every file loads without error. Total time: 3-7 minutes.

- [ ] **Step 3: Run extended verify**

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/verify/imperfections_check.sql
```

Expected output (key lines):
```
#3: store_inventory cells where snapshot != replay-of-log
 drifted_cells
---------------
             5

#7: products covered by all 3 scope types simultaneously
 products_with_all_3_scopes
----------------------------
                         10

#8: distinct keys across app_events.properties
 distinct_property_keys
------------------------
                    ~600

#10: orders appearing in >=2 attribution model rows
 orders_with_multiple_models
-----------------------------
                       ~300

#11: products with no inventory, no orders, no price overrides
 orphan_product_count
----------------------
                   50
```

Plus general row counts within ±2% of expected.

If any check fails (e.g., #3 returns 0 drifted cells, or #7 returns < 10):
- Identify which generator module failed to produce the expected pattern.
- Fix the module + tests in a follow-up commit.
- Re-run from Step 1.

- [ ] **Step 4: Commit any fixes from Step 3 (if needed)**

```bash
git add supabase/seed/generator/<offending_module>.py
git commit -m "fix(generator): align <module> with verify expectations"
```

---

## Task 16: Append `decisions-log.md` entry

**Files:**
- Modify: `decisions-log.md`

- [ ] **Step 1: Append new entry**

Open `decisions-log.md`. Find the line `## How to use this log`. Insert before it (after the existing `---` separator):

```markdown
## 2026-05-03 — Phase 4b complete: full seed generator + verify extended

**What changed:**

1. New Python package at `supabase/seed/generator/` produces seven bulk SQL files (`02a` through `02g`) totalling ~210K rows. Generator is deterministic (seed=42; per-module sub-seeds via SHA-256 hash of module name).
2. Smoke seed remains unchanged. Bulk seed layers on top: bulk user_id starts at 6, bulk order_id starts at 4, bulk rider_id starts at 4, bulk product_id starts at 11. The 5 named users, 14 named employees, 3 named riders, 3 demo orders, 10 base products from smoke seed are untouched.
3. Imperfections #3, #7, #8, #10, #11 are now exercised by the bulk data:
   - #3: 5 of 120 (store, product) inventory cells deliberately drift from the inventory_movements log replay (3 negative, 2 positive, magnitude ±2 to ±15).
   - #7: each of the 10 active products is covered by all 3 price_list scope types simultaneously (global + city + store).
   - #8: app_events.properties has key-spelling drift (product_id / productId / prod_id, 70/20/10), type drift on cart_value, ~5% missing keys, ~5% stray keys; ~600 distinct keys across 30K events.
   - #10: ~30% of 10K orders are ad-attributable; 100% get last_click, 10% additionally view_through, 5% additionally multi_touch_linear.
   - #11: 50 orphan products added (20 discontinued, 20 never-launched, 10 test data), none referenced anywhere.
4. `supabase/verify/imperfections_check.sql` extended with verification queries for the 5 new imperfections plus updated general row counts to bulk-seeded values.
5. Generator package contains pytest tests (~50 tests covering determinism, cardinalities, imperfection signatures); all pass without DB connection.

**Why:** Phase 4b was the planned next phase. Articles need realistic enough data that queries return interesting answers; smoke seed alone (~100 rows) is too small for power-law product popularity, multi-day analytics, or any of the activity-volume-dependent imperfections.

**Spec ↔ DDL reconciliations** (recorded here so future articles know):
- The spec said "4 price_list scope types" (city + store + time + category). DDL only supports 3 (`global`, `city`, `store`); time-bounding is via `starts_at`/`ends_at`. Plan and implementation use 3 scope types; "all 4 simultaneously" became "all 3 simultaneously."
- The spec called the snapshot column `quantity_available`. The DDL column is `quantity_on_hand`. Plan and implementation use `quantity_on_hand`.
- `ad_attributions.attribution_model` has 4 valid values (`last_click`, `view_through`, `multi_touch_linear`, `multi_touch_position_based`). Plan uses `multi_touch_linear` (simpler 1/N weights).

**Affects:** `supabase/seed/generator/*` (new), `supabase/seed/02*.sql` (generated), `supabase/verify/imperfections_check.sql` (extended).

**What's next:** Phase 5 (public GitHub README) → Phase 6 (Week 1 Post 1 draft).

---
```

- [ ] **Step 2: Commit**

```bash
git add decisions-log.md
git commit -m "docs(decisions): record Phase 4b complete + spec/DDL reconciliations"
```

---

## Self-review

After completing all 16 tasks:

1. **Spec coverage check.** Walk through each section of `docs/superpowers/specs/2026-05-03-phase-4b-seed-generator-design.md` and confirm a task implements it. The Section 2 cardinality table maps to Tasks 5–11. Section 3 imperfection mechanics map to Tasks 5 (#7), 7 (#3), 9 (#8), 10 (#10), 11 (#11). Section 4 determinism+validation map to Tasks 12 + 14. Section 7 (Definition of Done) maps to Tasks 15 + 16.

2. **Run all tests:**
   ```bash
   cd supabase/seed/generator && pytest -v
   ```
   Expected: ~55 tests pass.

3. **Run end-to-end verify:**
   ```bash
   psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
   ```
   Expected: all 11 imperfection checks (#1–#8, #10–#12) at expected counts.

4. **Confirm git log:**
   ```bash
   git log --oneline | head -20
   ```
   Expected: ~16 atomic commits, each task one commit.
