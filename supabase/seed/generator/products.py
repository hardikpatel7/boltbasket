"""Shared product constants for the smoke seed's 10 active products.

Used by:
    - operational.py — price_list_items override prices
    - orders.py — order_items snapshot fields + unit_price

Values must match the INSERT INTO raw.products rows in
supabase/seed/01_smoke_seed.sql closely enough that bulk-generated
order_items and price overrides feel plausible. They are not the
canonical source — the smoke seed file is — but they are the
generator's working approximation.
"""

# (product_name, sku, brand_name, category_path, mrp)
PRODUCT_NAMES: dict[int, tuple[str, str, str, str, float]] = {
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

BASE_PRICES: dict[int, float] = {
    1: 72.00,
    2: 65.00,
    3: 50.00,
    4: 295.00,
    5: 175.00,
    6: 95.00,
    7: 240.00,
    8: 165.00,
    9: 195.00,
    10: 145.00,
}

ACTIVE_PRODUCT_IDS: list[int] = list(BASE_PRICES.keys())  # [1..10]
