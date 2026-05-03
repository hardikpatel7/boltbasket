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
