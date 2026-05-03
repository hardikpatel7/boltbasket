"""Generates 02g_orphans.sql — owns Imperfection #11.

50 product rows added to raw.products that are NEVER referenced by:
  - store_inventory
  - inventory_movements
  - order_items
  - price_list_items
"""
from pathlib import Path

from generator import common, config


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
            "2022-06-01", "2024-09-30",  # launched_at, discontinued_at
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
