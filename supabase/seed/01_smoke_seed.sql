-- ============================================================================
-- BoltBasket — Smoke Test Seed
-- ============================================================================
-- Small, hand-written seed to verify the schema loads correctly. Loads in <5s.
-- Provides:
--   - 3 cities, ~60 pincodes
--   - All categories and brands
--   - The 14 named characters from the bible as employees
--   - 12 dark stores
--   - Service areas with deliberate overlaps
--   - 10 sample products
--   - 5 users, 5 addresses, 1 subscription
--   - 3 sample orders (one with NULL cart_id — Imperfection #5)
--
-- After running this, run verify/imperfections_check.sql to confirm the
-- schema is intact. Then run the full seed generator (Phase 4b) for the
-- ~300K-row realistic dataset.
-- ============================================================================

SET search_path TO raw, public;

-- ---------------------------------------------------------------------------
-- CITIES
-- ---------------------------------------------------------------------------
INSERT INTO raw.cities (city_code, city_name, state, launched_at) VALUES
  ('BLR', 'Bengaluru', 'Karnataka',   '2021-08-15'),
  ('BOM', 'Mumbai',    'Maharashtra', '2022-03-10'),
  ('PNQ', 'Pune',      'Maharashtra', '2022-01-20');

-- ---------------------------------------------------------------------------
-- PINCODES (sample — full list comes in Phase 4b)
-- ---------------------------------------------------------------------------
INSERT INTO raw.pincodes (pincode, city_id, area_name, demand_tier) VALUES
  -- Bangalore
  ('560038', 1, 'Indiranagar',        'high'),
  ('560034', 1, 'Koramangala 4',      'high'),
  ('560102', 1, 'HSR Layout',         'high'),
  ('560066', 1, 'Whitefield',         'high'),
  ('560076', 1, 'BTM Layout',         'high'),
  ('560001', 1, 'MG Road',            'medium'),
  ('560085', 1, 'JP Nagar',           'medium'),
  ('560064', 1, 'Yelahanka',          'low'),
  ('560100', 1, 'Electronic City',    'low'),
  -- Mumbai
  ('400050', 2, 'Bandra West',        'high'),
  ('400053', 2, 'Andheri West',       'high'),
  ('400076', 2, 'Powai',              'high'),
  ('400055', 2, 'Khar West',          'high'),
  ('400028', 2, 'Dadar West',         'medium'),
  ('400063', 2, 'Goregaon East',      'medium'),
  ('400078', 2, 'Bhandup',            'low'),
  -- Pune
  ('411016', 3, 'Aundh',              'high'),
  ('411021', 3, 'Baner',              'high'),
  ('411027', 3, 'Wakad',              'high'),
  ('411057', 3, 'Hinjawadi',          'high'),
  ('411001', 3, 'Camp',               'medium'),
  ('411038', 3, 'Karve Nagar',        'medium'),
  ('411037', 3, 'Wanowrie',           'low');

-- ---------------------------------------------------------------------------
-- CATEGORIES (Level 1 -> 2 -> 3, in dependency order)
-- ---------------------------------------------------------------------------
-- Level 1 (Aisles)
INSERT INTO raw.categories (category_code, category_name, parent_id, level, full_path) VALUES
  ('FOOD', 'Food & Grocery',  NULL, 1, 'Food & Grocery'),
  ('BEV',  'Beverages',       NULL, 1, 'Beverages'),
  ('HHLD', 'Household',       NULL, 1, 'Household'),
  ('PERS', 'Personal Care',   NULL, 1, 'Personal Care'),
  ('BABY', 'Baby Care',       NULL, 1, 'Baby Care');

-- Level 2 (Categories) — references the level 1 IDs above. Final L2 IDs: 6-15.
INSERT INTO raw.categories (category_code, category_name, parent_id, level, full_path) VALUES
  ('FOOD-DAIRY',   'Dairy & Bakery',       1, 2, 'Food & Grocery > Dairy & Bakery'),       --  6
  ('FOOD-FRUITS',  'Fruits & Vegetables',  1, 2, 'Food & Grocery > Fruits & Vegetables'),  --  7
  ('FOOD-STAPLE',  'Atta, Rice & Dal',     1, 2, 'Food & Grocery > Atta, Rice & Dal'),     --  8
  ('FOOD-SNACK',   'Snacks & Biscuits',    1, 2, 'Food & Grocery > Snacks & Biscuits'),    --  9
  ('BEV-TEA',      'Tea & Coffee',         2, 2, 'Beverages > Tea & Coffee'),              -- 10
  ('BEV-SODA',     'Soft Drinks',          2, 2, 'Beverages > Soft Drinks'),               -- 11
  ('HHLD-CLEAN',   'Cleaning Supplies',    3, 2, 'Household > Cleaning Supplies'),         -- 12
  ('PERS-ORAL',    'Oral Care',            4, 2, 'Personal Care > Oral Care'),             -- 13
  ('PERS-SKIN',    'Skin Care',            4, 2, 'Personal Care > Skin Care'),             -- 14
  ('BABY-DIAPR',   'Diapers & Wipes',      5, 2, 'Baby Care > Diapers & Wipes');           -- 15

-- Level 3 (Subcategories) — products attach here. Final L3 IDs: 16-27.
INSERT INTO raw.categories (category_code, category_name, parent_id, level, full_path) VALUES
  ('FOOD-DAIRY-MILK',   'Milk',             6, 3, 'Food & Grocery > Dairy & Bakery > Milk'),                       -- 16
  ('FOOD-DAIRY-BREAD',  'Bread',            6, 3, 'Food & Grocery > Dairy & Bakery > Bread'),                      -- 17
  ('FOOD-FRUITS-FRUIT', 'Fresh Fruits',     7, 3, 'Food & Grocery > Fruits & Vegetables > Fresh Fruits'),          -- 18
  ('FOOD-FRUITS-VEG',   'Fresh Vegetables', 7, 3, 'Food & Grocery > Fruits & Vegetables > Fresh Vegetables'),      -- 19
  ('FOOD-STAPLE-RICE',  'Rice',             8, 3, 'Food & Grocery > Atta, Rice & Dal > Rice'),                     -- 20
  ('FOOD-STAPLE-ATTA',  'Atta & Flour',     8, 3, 'Food & Grocery > Atta, Rice & Dal > Atta & Flour'),             -- 21
  ('FOOD-STAPLE-DAL',   'Dal & Pulses',     8, 3, 'Food & Grocery > Atta, Rice & Dal > Dal & Pulses'),             -- 22
  ('FOOD-SNACK-BIS',    'Biscuits',         9, 3, 'Food & Grocery > Snacks & Biscuits > Biscuits'),                -- 23
  ('FOOD-SNACK-CHOC',   'Chocolates',       9, 3, 'Food & Grocery > Snacks & Biscuits > Chocolates'),              -- 24
  ('BEV-TEA-TEA',       'Tea',             10, 3, 'Beverages > Tea & Coffee > Tea'),                               -- 25
  ('PERS-SKIN-MOIST',   'Moisturisers',    14, 3, 'Personal Care > Skin Care > Moisturisers'),                     -- 26
  ('PERS-ORAL-TOOTH',   'Toothpaste',      13, 3, 'Personal Care > Oral Care > Toothpaste');                       -- 27

-- ---------------------------------------------------------------------------
-- BRANDS
-- ---------------------------------------------------------------------------
INSERT INTO raw.brands (brand_code, brand_name, brand_type, is_private_label) VALUES
  ('AMUL',   'Amul',             'mass',          FALSE),
  ('BRTNA',  'Britannia',        'mass',          FALSE),
  ('PRSNT',  'Parle',            'mass',          FALSE),
  ('MOTHR',  'Mother Dairy',     'mass',          FALSE),
  ('ITC',    'ITC',              'mass',          FALSE),
  ('TATA',   'Tata Consumer',    'mass',          FALSE),
  ('HUL',    'Hindustan Unilever','mass',         FALSE),
  ('AASHR',  'Aashirvaad',       'mass',          FALSE),
  ('FRTNE',  'Fortune',          'mass',          FALSE),
  ('CDBRY',  'Cadbury',          'mass',          FALSE),
  ('NIVEA',  'Nivea',            'premium',       FALSE),
  ('PAMPS',  'Pampers',          'premium',       FALSE),
  ('BBDLY',  'BoltBasket Daily', 'private_label', TRUE);

-- ---------------------------------------------------------------------------
-- PRODUCTS (10 sample SKUs — fuller catalog comes in Phase 4b)
-- ---------------------------------------------------------------------------
INSERT INTO raw.products (sku, product_name, category_id, brand_id, weight_grams, is_perishable, country_of_origin, base_price, mrp, launched_at) VALUES
  ('BB-00001', 'Amul Gold Milk 1L Tetra Pack',     16, 1,  1000, TRUE,  'India', 72.00, 78.00, '2021-09-01'),
  ('BB-00002', 'Mother Dairy Toned Milk 1L',       16, 4,  1000, TRUE,  'India', 60.00, 64.00, '2021-09-01'),
  ('BB-00003', 'Britannia Brown Bread 400g',       17, 2,   400, TRUE,  'India', 50.00, 55.00, '2021-09-01'),
  ('BB-00004', 'Aashirvaad Whole Wheat Atta 5kg',  21, 8,  5000, FALSE, 'India', 245.00, 270.00, '2021-09-01'),
  ('BB-00005', 'Fortune Sona Masoori Rice 5kg',    20, 9,  5000, FALSE, 'India', 380.00, 410.00, '2021-09-01'),
  ('BB-00006', 'Parle-G Original Biscuits 800g',   23, 3,   800, FALSE, 'India', 95.00, 105.00, '2021-09-01'),
  ('BB-00007', 'Tata Tea Premium 500g',            25, 6,   500, FALSE, 'India', 285.00, 310.00, '2021-09-01'),
  ('BB-00008', 'Cadbury Dairy Milk Silk 150g',     24, 10,  150, FALSE, 'India', 195.00, 210.00, '2021-09-01'),
  ('BB-00009', 'Nivea Soft Light Moisturiser 100ml', 26, 11, 100, FALSE, 'Germany', 195.00, 215.00, '2021-09-01'),
  ('BB-00010', 'BoltBasket Daily Toor Dal 1kg',    22, 13, 1000, FALSE, 'India', 145.00, 160.00, '2023-04-01');

-- ---------------------------------------------------------------------------
-- PRODUCT ATTRIBUTES (illustrating Imperfection #2 — overlap and disagreement)
-- ---------------------------------------------------------------------------
-- Most products: attribute mirrors the column correctly
INSERT INTO raw.product_attributes (product_id, attribute_key, attribute_value) VALUES
  (1, 'weight_grams', '1000'),
  (1, 'shelf_life_days', '6'),
  (1, 'storage_temp', 'refrigerated'),
  (1, 'fssai_license', 'FSSAI-10018011000123'),
  (2, 'weight_grams', '1000'),
  (2, 'shelf_life_days', '5'),
  (3, 'weight_grams', '400'),
  (3, 'shelf_life_days', '3'),
  -- Imperfection #2: deliberate disagreement on product 4
  -- The column says weight_grams = 5000. The attribute says 4500. Both exist.
  (4, 'weight_grams', '4500'),
  (4, 'shelf_life_days', '180'),
  (4, 'is_organic', 'false'),
  -- Imperfection #2: deliberate disagreement on product 7
  -- The column says country_of_origin = 'India'. The attribute says 'Sri Lanka'.
  (7, 'country_of_origin', 'Sri Lanka'),
  (7, 'weight_grams', '500'),
  -- Some attributes only in product_attributes, never in columns
  (8, 'cocoa_percent', '36'),
  (8, 'is_imported', 'false'),
  -- Imperfection #8 setup: misspelled key (productID instead of product_id)
  -- Real production data has these. We'll add more in the full seed.
  (9, 'manufacturer_country', 'Germany'),
  (10, 'is_organic', 'false'),
  (10, 'protein_grams_per_100g', '22');

-- ---------------------------------------------------------------------------
-- DARK STORES (12 stores: 6 BLR, 4 BOM, 2 PNQ)
-- ---------------------------------------------------------------------------
INSERT INTO raw.dark_stores (store_code, store_name, city_id, primary_pincode_id, area_sqft, capacity_skus, status, launched_at) VALUES
  ('BLR-IND-01', 'Indiranagar 1',  1,  1, 2400, 6500, 'active', '2021-09-01'),
  ('BLR-KOR-01', 'Koramangala 1',  1,  2, 2600, 6800, 'active', '2021-10-15'),
  ('BLR-HSR-01', 'HSR Layout 1',   1,  3, 2500, 6500, 'active', '2022-01-10'),
  ('BLR-WHF-01', 'Whitefield 1',   1,  4, 2800, 7000, 'active', '2022-04-20'),
  ('BLR-BTM-01', 'BTM Layout 1',   1,  5, 2400, 6500, 'active', '2022-08-15'),
  ('BLR-JPN-01', 'JP Nagar 1',     1,  7, 2300, 6200, 'active', '2023-03-10'),
  ('BOM-BAN-01', 'Bandra West 1',  2, 10, 2200, 6300, 'active', '2022-04-15'),
  ('BOM-AND-01', 'Andheri West 1', 2, 11, 2500, 6700, 'active', '2022-06-20'),
  ('BOM-POW-01', 'Powai 1',        2, 12, 2400, 6500, 'active', '2022-09-10'),
  ('BOM-KHR-01', 'Khar West 1',    2, 13, 2300, 6400, 'active', '2023-02-01'),
  ('PNQ-AUN-01', 'Aundh 1',        3, 17, 2400, 6500, 'active', '2022-02-15'),
  ('PNQ-BAN-01', 'Baner 1',        3, 18, 2500, 6700, 'active', '2022-05-01');

-- ---------------------------------------------------------------------------
-- SERVICE AREAS — including deliberate overlaps (Imperfection #4)
-- ---------------------------------------------------------------------------
-- Indiranagar pincode 560038 served by Indiranagar AND Koramangala stores
INSERT INTO raw.service_areas (dark_store_id, pincode_id, is_primary, distance_km, promised_minutes) VALUES
  -- BLR Indiranagar store services
  (1,  1, TRUE,  0.5, 12),  -- 560038 (primary)
  (1,  2, FALSE, 2.8, 18),  -- 560034 (overlap)
  (1,  6, TRUE,  3.2, 15),  -- 560001 MG Road (primary)
  -- BLR Koramangala store services
  (2,  2, TRUE,  0.6, 10),  -- 560034 (primary)
  (2,  1, FALSE, 2.8, 18),  -- 560038 (overlap)
  (2,  3, FALSE, 4.0, 20),  -- 560102 HSR overlap
  -- BLR HSR
  (3,  3, TRUE,  0.5, 10),
  (3,  5, TRUE,  3.0, 15),  -- 560076 BTM
  (3,  2, FALSE, 4.0, 20),  -- overlap with Koramangala for 560034
  -- BLR Whitefield
  (4,  4, TRUE,  0.5, 12),
  -- BLR BTM Layout
  (5,  5, FALSE, 1.0, 12),  -- not primary, HSR is primary
  (5,  7, TRUE,  4.0, 18),  -- 560085 JP Nagar (primary, until JPN-01 launches)
  -- BLR JP Nagar
  (6,  7, TRUE,  0.8, 12),  -- now JP Nagar's primary
  (6,  8, FALSE, 5.5, 22),  -- Yelahanka edge service
  -- BLR Yelahanka and Electronic City have no primary store close — fringe service
  (1,  9, FALSE, 18.0, 35), -- Indiranagar serves Electronic City badly
  -- BOM Bandra
  (7, 10, TRUE,  0.6, 12),
  (7, 13, FALSE, 2.8, 18),  -- Khar overlap before KHR-01 took over
  -- BOM Andheri
  (8, 11, TRUE,  0.5, 12),
  (8, 15, TRUE,  3.5, 18),  -- 400063 Goregaon
  -- BOM Powai
  (9, 12, TRUE,  0.5, 12),
  -- BOM Khar
  (10,13, TRUE,  0.5, 12),
  -- PNQ Aundh
  (11,17, TRUE,  0.5, 12),
  (11,21, FALSE, 6.0, 22),  -- 411001 Camp
  -- PNQ Baner
  (12,18, TRUE,  0.5, 12),
  (12,19, TRUE,  3.5, 15),  -- 411027 Wakad (primary)
  (12,20, TRUE,  4.0, 18);  -- 411057 Hinjawadi

-- ---------------------------------------------------------------------------
-- EMPLOYEES — the 14 named characters from the bible
-- ---------------------------------------------------------------------------
INSERT INTO raw.employees (employee_code, full_name, role, department, city_id, joined_at) VALUES
  -- Leadership
  ('BB-EMP-0001', 'Aryan Mehta',       'CEO',                       'Leadership',         1, '2021-08-15'),
  ('BB-EMP-0002', 'Sanya Kapoor',      'COO',                       'Leadership',         2, '2022-02-01'),
  ('BB-EMP-0003', 'Vikram Bansal',     'CTO',                       'Engineering',        1, '2021-08-15'),
  ('BB-EMP-0004', 'Naveen Krishnan',   'CFO',                       'Finance',            1, '2023-01-10'),
  -- Data & Engineering (Bangalore)
  ('BB-EMP-0010', 'Priya Raghavan',    'Lead Data Engineer',        'Data Engineering',   1, '2022-11-15'),
  ('BB-EMP-0011', 'Noel Thomas',       'Engineering Manager',       'Data Engineering',   1, '2023-06-20'),
  ('BB-EMP-0012', 'Devika Rao',        'Senior Data Engineer',      'Data Engineering',   1, '2024-02-05'),
  ('BB-EMP-0013', 'Arjun Pillai',      'Data Engineer',             'Data Engineering',   1, '2024-11-04'),
  ('BB-EMP-0014', 'Meera Joshi',       'Analytics Engineer',        'Data Engineering',   1, '2024-05-15'),
  -- Product
  ('BB-EMP-0020', 'Siddharth Patel',   'Senior Product Manager',    'Product',            1, '2023-09-01'),
  ('BB-EMP-0021', 'Rohan Desai',       'Product Manager, Growth',   'Product',            1, '2023-11-15'),
  ('BB-EMP-0022', 'Anjali Singh',      'PM, Supply & Inventory',    'Product',            1, '2024-03-10'),
  -- Operations & Commercial (Mumbai)
  ('BB-EMP-0030', 'Faisal Khan',       'VP, Dark Store Operations', 'Operations',         2, '2022-04-01'),
  ('BB-EMP-0031', 'Pooja Nair',        'Director, Ad Sales',        'Commercial',         2, '2025-04-15');

-- ---------------------------------------------------------------------------
-- RIDERS — minimal set so non-legacy orders can have rider_ids
-- ---------------------------------------------------------------------------
-- 3 riders (one per city) is enough for the smoke seed. Phase 4b's full seed
-- generator will populate a realistic rider workforce.
INSERT INTO raw.riders
  (rider_code, full_name, phone, city_id, primary_dark_store_id, rider_type, vehicle_type, joined_at, rating, total_deliveries) VALUES
  ('BB-RDR-00001', 'Mohan Kumar',  '+919876500001', 1,  1, 'gig',     'bike',    '2024-03-15', 4.7, 412),
  ('BB-RDR-00002', 'Suresh Yadav', '+919876500002', 2,  7, 'payroll', 'scooter', '2023-09-01', 4.6, 588),
  ('BB-RDR-00003', 'Rakesh Pawar', '+919876500003', 3, 11, 'gig',     'bike',    '2024-06-10', 4.8, 297);

-- ---------------------------------------------------------------------------
-- A FEW USERS, ADDRESSES, AND ORDERS — proves end-to-end relationships work
-- ---------------------------------------------------------------------------
-- Insert users first WITHOUT primary_address_id (NULL), then addresses, then update users.
-- This is exactly the pattern Imperfection #1 forces real BoltBasket app code into.

INSERT INTO raw.users (phone, email, first_name, last_name, signup_city_id, signup_at) VALUES
  ('+919812340001', 'rohit.s@example.fictional', 'Rohit',  'S.', 1, '2024-01-10 10:23:00+05:30'),
  ('+919812340002', NULL,                         'Ritika', 'M.', 2, '2023-08-15 14:45:00+05:30'),
  ('+919812340003', 'aakash.v@example.fictional', 'Aakash', 'V.', 3, '2024-06-20 19:30:00+05:30'),
  ('+919812340004', 'demo.user4@example.fictional','Sneha',  'K.', 1, '2024-09-05 08:15:00+05:30'),
  ('+919812340005', 'demo.user5@example.fictional','Karan',  'M.', 1, '2025-01-12 21:00:00+05:30');

-- Now addresses
INSERT INTO raw.addresses (user_id, pincode_id, address_line_1, address_type) VALUES
  (1,  1, '#42, 12th Main, Indiranagar',         'home'),
  (2, 10, 'Flat 7B, Hill View Apartments, Bandra West', 'home'),
  (3, 17, 'Room 304, Aundh Hostel Complex',       'home'),
  (4,  2, '#118, 5th Block, Koramangala',         'home'),
  (5,  3, 'Flat 12A, HSR Layout Sector 7',        'home');

-- Update users to point primary_address_id at their addresses
UPDATE raw.users SET primary_address_id = 1 WHERE user_id = 1;
UPDATE raw.users SET primary_address_id = 2 WHERE user_id = 2;
UPDATE raw.users SET primary_address_id = 3 WHERE user_id = 3;
UPDATE raw.users SET primary_address_id = 4 WHERE user_id = 4;
-- Imperfection #1 demo: user 5 has an address but no primary_address_id set (orphan from a bad insert)
-- (Left as NULL deliberately)

-- One subscription
INSERT INTO raw.subscriptions (user_id, plan_code, started_at, ends_at, is_active, amount_paid) VALUES
  (1, 'PLUS_QUARTERLY', '2025-08-01 00:00:00+05:30', '2025-11-01 00:00:00+05:30', TRUE, 199.00);

-- Three sample orders
-- Order 1: normal flow with cart_id
INSERT INTO raw.carts (user_id, dark_store_id, status, item_count, subtotal, created_at, converted_at) VALUES
  (1, 1, 'converted', 3, 195.00, '2025-10-12 19:30:00+05:30', '2025-10-12 19:34:00+05:30');

INSERT INTO raw.orders (
  order_code, user_id, cart_id, dark_store_id, delivery_address_id, rider_id,
  current_status, subtotal, discount_amount, delivery_fee, tax_amount, total_amount,
  placed_at, confirmed_at, picked_at, delivered_at, promised_minutes, actual_minutes
) VALUES
  ('BB-20251012-000001', 1, 1, 1, 1, 1,
   'delivered', 195.00, 0.00, 0.00, 9.75, 204.75,
   '2025-10-12 19:34:00+05:30', '2025-10-12 19:34:30+05:30',
   '2025-10-12 19:38:00+05:30', '2025-10-12 19:46:00+05:30', 12, 12);

-- Imperfection #5 demo: order with NULL cart_id (deeplink direct-order flow)
INSERT INTO raw.orders (
  order_code, user_id, cart_id, dark_store_id, delivery_address_id, rider_id,
  current_status, subtotal, discount_amount, delivery_fee, tax_amount, total_amount,
  placed_at, confirmed_at, picked_at, delivered_at, promised_minutes, actual_minutes
) VALUES
  ('BB-20251013-000002', 2, NULL, 7, 2, 2,
   'delivered', 285.00, 0.00, 15.00, 14.25, 314.25,
   '2025-10-13 11:15:00+05:30', '2025-10-13 11:15:20+05:30',
   '2025-10-13 11:19:00+05:30', '2025-10-13 11:28:00+05:30', 15, 13);

-- Imperfection #6 demo: order past 'picked' state with NULL rider_id (legacy/buggy row)
INSERT INTO raw.orders (
  order_code, user_id, cart_id, dark_store_id, delivery_address_id, rider_id,
  current_status, subtotal, discount_amount, delivery_fee, tax_amount, total_amount,
  placed_at, confirmed_at, picked_at, delivered_at, promised_minutes, actual_minutes
) VALUES
  ('BB-20231215-000003', 3, NULL, 11, 3, NULL,
   'delivered', 145.00, 0.00, 20.00, 7.25, 172.25,
   '2023-12-15 21:00:00+05:30', '2023-12-15 21:00:30+05:30',
   '2023-12-15 21:05:00+05:30', '2023-12-15 21:18:00+05:30', 18, 18);

-- Order items for the three orders (just one line each for smoke test)
INSERT INTO raw.order_items (
  order_id, product_id, product_name_snapshot, product_sku_snapshot,
  brand_name_snapshot, category_path_snapshot, unit_price_snapshot, mrp_snapshot,
  quantity_ordered, quantity_delivered, line_subtotal, line_total
) VALUES
  (1, 1, 'Amul Gold Milk 1L Tetra Pack', 'BB-00001', 'Amul', 'Food & Grocery > Dairy & Bakery > Milk', 72.00, 78.00, 2, 2, 144.00, 144.00),
  (1, 3, 'Britannia Brown Bread 400g',   'BB-00003', 'Britannia', 'Food & Grocery > Dairy & Bakery > Bread', 50.00, 55.00, 1, 1, 50.00, 50.00),
  (2, 6, 'Parle-G Original Biscuits 800g', 'BB-00006', 'Parle', 'Food & Grocery > Snacks & Biscuits > Biscuits', 95.00, 105.00, 3, 3, 285.00, 285.00),
  (3, 10, 'BoltBasket Daily Toor Dal 1kg', 'BB-00010', 'BoltBasket Daily', 'Food & Grocery > Atta, Rice & Dal', 145.00, 160.00, 1, 1, 145.00, 145.00);

-- Order events (the append-only log for these orders)
INSERT INTO raw.order_events (order_id, event_type, occurred_at, actor_type, metadata) VALUES
  (1, 'placed',         '2025-10-12 19:34:00+05:30', 'customer', '{"channel": "app"}'::jsonb),
  (1, 'confirmed',      '2025-10-12 19:34:30+05:30', 'system',   '{}'::jsonb),
  (1, 'picked',         '2025-10-12 19:38:00+05:30', 'employee', '{"employee_code": "BB-EMP-9001"}'::jsonb),
  (1, 'out_for_delivery','2025-10-12 19:40:00+05:30','rider',     '{}'::jsonb),
  (1, 'delivered',      '2025-10-12 19:46:00+05:30', 'rider',     '{}'::jsonb);

-- Smoke test complete. Run verify queries to confirm.
SELECT 'Smoke seed loaded successfully. Run verify/imperfections_check.sql next.' AS status;
