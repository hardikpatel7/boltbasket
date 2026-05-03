# BoltBasket — Relationships

How entities connect. Read alongside `entities.md`. Still no SQL — this is the conceptual relationship map.

---

## Identity cluster

```
users (1) ──< addresses (M)
users (1) ──< subscriptions (M)        # users can have past + current
users (1) ──< orders (M)
users (1) ──< app_events (M)
users (1) ──< search_queries (M)
users (1) ──< carts (M)
```

Notes:
- `users.primary_address_id` is a denormalized FK back into `addresses` for the user's default. Yes it creates a circular FK at the schema level. Yes it's a real-world pattern. Yes it's annoying.
- A user has exactly 0 or 1 *active* subscription, but `subscriptions` keeps history.

---

## Catalog cluster

```
categories (1) ──< categories (M)        # self-referential parent_id
categories (1) ──< products (M)          # leaf-node category
brands (1) ──< products (M)
products (1) ──< product_attributes (M)
```

Notes:
- Categories are 3-level: aisle (level 1) → category (level 2) → subcategory (level 3). Products attach to subcategories.
- `product_attributes` is the messy key-value store. Some attributes (e.g. `weight_grams`, `is_perishable`) also exist as columns on `products` directly because someone optimized for query speed circa 2022. They sometimes disagree. Canonical: trust the column over the attribute. This is canon.

---

## Operations cluster

```
cities (1) ──< pincodes (M)
cities (1) ──< dark_stores (M)
dark_stores (1) ──< service_areas (M) >── pincodes (M)    # M:M via service_areas
dark_stores (1) ──< store_inventory (M) >── products (M)   # M:M via store_inventory
dark_stores (1) ──< inventory_movements (M)
products (1) ──< inventory_movements (M)
dark_stores (1) ──< orders (M)
dark_stores (1) ──< dark_store_assignments (M) >── employees (M)
```

Notes:
- `service_areas` lets one pincode be served by multiple stores. The "primary" store for a pincode is the one with `is_primary = true`. Routing logic uses the closest store with stock; the primary is the default fallback.
- `store_inventory` is a *snapshot* table — one row per (store, product) pair currently stocked. Updated on every inventory change.
- `inventory_movements` is the append-only log. Reconstructable history of every stock change. The two should agree; they sometimes don't (Arc 1).

---

## Order lifecycle cluster

```
users (1) ──< carts (M)
carts (1) ──< orders (0..1)              # cart may or may not become an order

orders (1) ──< order_items (M) >── products (M)
orders (1) ──< order_events (M)
orders (1) ──< payments (M)              # retries, refunds → multiple
orders (1) ──< refunds (M)
orders (M) >── promotions (M)            # via promotion_redemptions
orders (M) >── ad_attributions (M)       # via ad_attributions, optional
orders (1) ──< rider_assignment_id        # FK to riders, nullable until picked
orders (1) ──< dark_stores (1)
```

Notes:
- An order has exactly one `dark_store_id` — the store fulfilling it.
- An order has 0..1 rider until pickup, then exactly 1.
- `order_items` references `products` *and* stores a `price_at_order_time` and `name_at_order_time` snapshot. Catalog changes; orders are immutable history.
- `order_events` is the append-only state log: `placed → confirmed → picked → packed → out_for_delivery → delivered` (or branches: `cancelled`, `refunded`).

---

## Pricing & promotions cluster

```
price_lists (M) >── products (M)         # via price_list_items
price_lists (M) >── cities (M)           # a price list applies to a city or set of cities
promotions (1) ──< promotion_redemptions (M)
promotion_redemptions (M) >── orders (M)
```

Notes:
- A product has a "global" price (`products.base_price`) and city/store-level overrides via `price_lists`. The effective price is the most specific override that applies. Yes, this is messy. Yes, this is realistic.
- Promotions have eligibility rules (min order value, applicable categories, etc.) stored as JSON in `promotions.eligibility_rules`.

---

## Advertising cluster

```
brands (1) ──< ad_campaigns (M)
ad_campaigns (1) ──< ad_placements (M)
ad_placements (1) ──< ad_impressions (M)
ad_placements (1) ──< ad_clicks (M)
ad_impressions (M) >── ad_attributions (M)
ad_attributions (M) >── orders (M)
```

Notes:
- Attribution is the messy bit. Multiple attribution models can produce different `ad_attributions` rows for the same order. We canonicalize on last-click for now but the data shows view-through and multi-touch alongside. This is content gold for an article.
- `ad_impressions` and `ad_clicks` are heavy tables. In real BoltBasket they'd be in ClickHouse, not Postgres. In our Supabase we'll seed a manageable sample.

---

## Engagement cluster

```
users (1) ──< app_events (M)
users (1) ──< search_queries (M)
users (1) ──< push_notifications (M)
```

Notes:
- `app_events` has a JSONB `properties` column. This is the eventing table — every screen view, button tap, scroll. In production this is in Snowflake, not Postgres. We'll keep a small sample in Supabase.
- `search_queries` is broken out separately because they have their own analytics needs (zero-result searches, search → conversion, etc.).

---

## The deliberately ugly relationships (canon)

For mining in articles:

1. **`users.primary_address_id` ↔ `addresses.user_id`** — circular. Use `addresses` as primary truth; `primary_address_id` is a convenience cache that occasionally goes stale.

2. **`products` columns vs. `product_attributes` rows** — overlapping data, occasionally disagrees. Trust `products` columns (they're canonical for the columns that exist there).

3. **`store_inventory` snapshot vs. `inventory_movements` log** — should agree, sometimes drifts under load. The Diwali outage's root cause.

4. **One pincode → multiple `service_areas`** — pincode 560038 (Indiranagar, Bangalore) is served by 3 dark stores. Routing complexity.

5. **`carts.id` is referenced by `orders.cart_id`, but `orders` can also exist without a cart** (cart-less direct order via deeplink). Some orders have NULL `cart_id`. ~3% of orders.

6. **`orders.rider_id` is nullable** but cannot be NULL after the order moves past `picked` state. The check is in app code, not the DB. Some old rows violate this — pre-2023 data has NULLs that shouldn't exist.

7. **MongoDB-resident attributes** — some product attributes (especially descriptive copy and image metadata) live only in MongoDB and aren't in the relational schema at all. When we later set up a NoSQL surface, this is where it'll sit. For now, articles can reference "the catalog data we don't have in Postgres" as a known gap.

---

## What's deliberately NOT in this model

So you don't waste time looking for them:

- No HR/employee compensation
- No detailed payment vault
- No raw rider GPS streams
- No real-time inventory cache (that's Redis, not modeled here)
- No B2B/brand portal data (Salesforce, accessed via Fivetran)

Add proposals to `entities.md` if a future article requires modeling any of these.
