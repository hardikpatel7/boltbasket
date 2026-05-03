# BoltBasket — Entities (Conceptual Schema)

This is the **conceptual data model** for BoltBasket. No SQL yet — that comes in Phase 4 when we build the Supabase DDL. This file defines *what entities exist and what they mean.*

The model is deliberately reflective of the company's real-world structure: relational core with deliberate imperfections. NoSQL extensions can come later for content needs (e.g., when we want to write about MongoDB-style problems).

The OLTP layer here is what would live in Postgres at BoltBasket. The analytical layer (`marts.*` style) lives conceptually in Snowflake but we'll build it as views/tables in Supabase too.

---

## Core entity groups

### 1. Identity & customer

- **users** — registered customers
- **addresses** — delivery addresses (a user has many)
- **subscriptions** — BoltBasket Plus subscriptions

### 2. Catalog

- **products** — the master SKU catalog
- **categories** — hierarchical: aisle → category → subcategory
- **brands** — product brands
- **product_attributes** — flexible key-value attributes (deliberately messy: some attributes live here, some in `products` columns directly)

### 3. Operations

- **dark_stores** — physical fulfillment locations
- **service_areas** — pincode-level coverage (one store services many pincodes; one pincode is sometimes serviced by more than one store, hence the imperfection)
- **store_inventory** — current stock levels per (store, product) snapshot
- **inventory_movements** — append-only log of stock changes
- **riders** — delivery personnel (mix of payroll and gig)

### 4. Order lifecycle

- **carts** — pre-checkout state
- **orders** — placed orders
- **order_items** — line items per order
- **order_events** — append-only state-change log per order
- **payments** — payment attempts and outcomes
- **refunds** — refund records

### 5. Pricing & promotions

- **price_lists** — store-specific pricing (a product can have different prices in different cities)
- **promotions** — discount campaigns
- **promotion_redemptions** — which promotion was applied to which order

### 6. Advertising (newer, less mature)

- **ad_campaigns** — brand campaigns
- **ad_placements** — where ads appeared (search, banner, push)
- **ad_impressions** — append-only impression log
- **ad_clicks** — append-only click log
- **ad_attributions** — orders attributed to ad exposures (the data team's nightmare)

### 7. Engagement & analytics

- **app_events** — generic event log (search, view, add-to-cart, etc.)
- **search_queries** — search-specific events with the actual query text
- **push_notifications** — notifications sent to users

### 8. Internal / org

- **employees** — for stories where org structure matters
- **dark_store_assignments** — which employee runs which store

### 9. Master data / reference

- **cities**
- **pincodes**

---

## Why these entities and not others

A few deliberate omissions you might wonder about:

- **No `payments_method_tokens`** at the schema-on-paper stage. We'll never write articles requiring payment vault internals; out of scope.
- **No `kyc_documents`** — sensitive, no content value, omit.
- **No deep rider tracking** (e.g., per-second GPS history). We'll add a *summarized* `rider_trips` if needed, but we're not modeling raw location streams in the relational layer. Those would belong in ClickHouse anyway.
- **No HR data beyond `employees`** — out of scope.

If a future article needs an entity not listed here, propose adding it before drafting.

---

## Cardinality cheatsheet

For quick mental reference (canonical scale, late 2025):

| Entity | Approximate row count |
|---|---|
| users | ~15 million (lifetime) / ~4.2M MAU |
| addresses | ~22 million |
| products | ~47,000 |
| categories | ~340 |
| brands | ~3,800 |
| dark_stores | ~280 |
| service_areas | ~1,700 (store × pincode) |
| store_inventory | ~1.8 million current rows (store × stocked SKU) |
| inventory_movements | ~12 million/day, ~3.5 billion lifetime |
| orders | ~1.1 million/day, ~600 million lifetime |
| order_items | ~5 million/day (avg ~4.5 items/order) |
| order_events | ~9 million/day (~8 events per order avg) |
| ad_impressions | ~80 million/day |
| app_events | ~250 million/day |

When seeding the Supabase DB, we'll generate a representative sample of activity at small-BoltBasket scale — targeting ~300K rows total across all tables. Enough to write meaningful queries against (real GROUP BYs, JOINs, indexing matters), small enough to fit Supabase's free tier comfortably and clone with the repo. Specifically: ~3 cities (Bangalore, Mumbai, Pune), ~10K users, ~3 days of order activity at small scale. See Phase 4 build for exact distributions.

---

## Key observations for content mining

- **`order_events` is append-only and everything-is-a-state-change.** Great for articles about event sourcing, lineage, time-travel queries.
- **`store_inventory` (snapshot) vs. `inventory_movements` (log) is the classic batch-vs-stream tension.** The snapshot can drift from the log under high write load — this is the Diwali outage's root cause.
- **`product_attributes` flexible key-value is deliberately ugly.** Half the product data is here, half in `products` columns. The migration that never finished. Great content material.
- **`ad_attributions` is a fresh, contested entity.** Different definitions of "attribution" (last-click, view-through, multi-touch) give different numbers. Pooja and the data team are still arguing about this.
- **`service_areas` having "one pincode → multiple stores" is a deliberate imperfection.** Real life is messy. Articles about routing and assignment can mine this.
- **`carts` are abandoned at scale.** ~70% of carts never become orders. Useful for articles about funnel analysis, real-time pipelines, cohort analytics.
