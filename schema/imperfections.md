# BoltBasket — Schema Imperfections Catalog

This is the canonical list of *deliberate* legacy mistakes baked into BoltBasket's data model. Each one is a story waiting to be told.

When writing an article, scan this list — there's a high chance one of these imperfections is the natural protagonist of the piece you're writing.

When the schema is built in Supabase (Phase 4), these imperfections **must be preserved**, not cleaned up. A clean schema teaches nothing.

---

## 1. The circular FK between `users` and `addresses`

- **What:** `users.primary_address_id` references `addresses.id`. `addresses.user_id` references `users.id`.
- **Why it exists:** Originally, `users.primary_address_id` was a quick way to avoid a JOIN on the home page. Years later it's still there.
- **The pain:** Inserting a new user with their primary address requires a 2-step transaction (insert user with NULL primary_address_id, insert address, update user). The application code gets this wrong sometimes; orphan rows result.
- **Article potential:** Schema design tradeoffs, denormalization for performance, why "obvious" optimizations decay.

## 2. Overlapping `products.columns` vs `product_attributes.rows`

- **What:** Some attributes (e.g. `weight_grams`, `is_perishable`, `country_of_origin`) live as columns on `products`. The same attributes, plus more, also live in `product_attributes` as key-value rows. They occasionally disagree.
- **Why it exists:** `product_attributes` was the original Mongo-style flexible schema. Hot attributes were promoted to columns for query speed. Nobody removed them from `product_attributes`. The sync isn't enforced.
- **The pain:** Which one is canonical? Different teams use different ones. Reports built on the column version disagree with reports built on the attribute version.
- **Article potential:** Flexible vs. rigid schemas, MDM, the "pick a source of truth" problem, semantic layers as a fix.

## 3. The snapshot/log drift in inventory

- **What:** `store_inventory` is a snapshot ("how much do we have right now"). `inventory_movements` is a log ("every change ever"). Replaying the log should reproduce the snapshot. Under load, it sometimes doesn't.
- **Why:** Snapshot updates run in a separate transaction from log inserts. A failure mode lets the log advance while the snapshot doesn't.
- **The pain:** This was the Diwali outage's root cause (Arc 1).
- **Article potential:** Stream/batch reconciliation, idempotency, materialized views, observability beyond "did the job run."

## 4. Multiple stores per pincode

- **What:** `service_areas` has rows where `(pincode_id, dark_store_id)` is many-to-many. One pincode can be served by multiple stores. The "primary" is flagged but isn't always honored.
- **Why:** Realistic. Dense urban areas overlap.
- **The pain:** Routing logic has to pick a store. Inventory aggregation across the eligible stores is expensive. A naive "demand by pincode" query has to choose one store or it double-counts.
- **Article potential:** Geospatial data, demand attribution, the gap between physical reality and clean schemas.

## 5. The `cart_id` NULL edge case

- **What:** `orders.cart_id` is nullable. Most orders have a cart predecessor. ~3% don't (deeplink direct-order, retry flows, programmatic orders).
- **Why:** Originally, all orders came from carts. The deeplink flow was added later without retrofitting.
- **The pain:** Funnel analytics (carts → orders) misses 3%. Cohort analysis based on cart events misses these users entirely. A "conversion rate" depends on which way you count.
- **Article potential:** Funnel definition pitfalls, the difference between "system events" and "business events," edge cases as silent metric pollutants.

## 6. The rider FK that's nullable when it shouldn't be

- **What:** `orders.rider_id` is nullable in the DB but app code says it must be set after `picked` state. Pre-2023 data has rows that violate this.
- **Why:** The constraint was added later but wasn't backfilled. Adding a NOT NULL constraint would break old data.
- **The pain:** Joins to `riders` on old orders sometimes silently drop rows. Lifetime rider stats are skewed for early riders.
- **Article potential:** Schema constraints over time, the cost of "we'll add the constraint later," historical data quality issues.

## 7. The price_lists override hierarchy

- **What:** A product's effective price is determined by checking `products.base_price`, then any `price_lists` overrides that apply (city, time-bound, store-specific). The "most specific override wins" rule is implemented in application code, not the DB.
- **Why:** Started simple, grew organically.
- **The pain:** Two different services compute "effective price" with subtly different logic. Customers occasionally see different prices in app vs. cart.
- **Article potential:** Business logic in the database vs. application, the "calculate it where" debate.

## 8. The `app_events.properties` JSONB chaos

- **What:** `app_events.properties` is a JSONB column. Every event type stores arbitrary keys. Schema is enforced nowhere.
- **Why:** Move-fast eventing. Schema-on-read was a deliberate choice in 2022.
- **The pain:** ~600 distinct keys exist across the corpus. Some keys mean different things across event types. Some keys are misspelled (`product_id` vs. `productId` vs. `prod_id` all coexist).
- **Article potential:** Schema-on-write vs schema-on-read, data contracts, the "events are forever, schemas are forever" lesson.

## 9. The MongoDB blind spot

- **What:** Product copy, image metadata, some review data live in MongoDB. They aren't in the Postgres schema at all. They aren't in Snowflake either (the Mongo → Snowflake pipeline broke in 2024 and was never fixed because "we're going to deprecate Mongo soon").
- **Why:** Vikram's 2021 choice. The migration that won't die (Arc 6).
- **The pain:** Search ranking can use product copy. Recommendation models can't. Brand reporting can't include image metadata. Half the team has forgotten Mongo exists.
- **Article potential:** Polyglot persistence in practice, the cost of unfinished migrations, the "shadow data" problem.

## 10. The `ad_attributions` definition split

- **What:** `ad_attributions` rows can be created by three different attribution models running in parallel: last-click, view-through, multi-touch. The same order can have multiple attribution rows from different models.
- **Why:** Pooja's team wants multi-touch. Brands ask for last-click. Internal reporting uses view-through.
- **The pain:** "How many orders did this campaign drive?" has three correct answers depending on which model you trust. CFO Naveen wants one number for the books.
- **Article potential:** Attribution wars, the impossibility of "the right number," semantic layers for advertising, the social side of metric ownership.

## 11. The orphan products

- **What:** ~1,200 rows in `products` are not referenced by any current `store_inventory`, any recent `order_items`, or any active `price_list`. They're discontinued, never-launched, or test data nobody cleaned up.
- **Why:** No retirement process for products.
- **The pain:** Catalog size metrics are inflated. Search occasionally returns them. They contribute to "product count growth" charts that aren't real growth.
- **Article potential:** The data hygiene tax, why "we have N items" is rarely simple, the case for retirement processes.

## 12. The denormalized snapshot fields on `order_items`

- **What:** `order_items.product_name`, `order_items.product_image_url`, `order_items.price_at_order_time`, etc. snapshot the product state at order time. Good design — orders are immutable history.
- **Why:** Required for accurate historical orders even when products change.
- **The pain not really:** This one is *correct* design. Included in the catalog because it might *look* like an imperfection to someone learning. It's the right way; an article could explain why.
- **Article potential:** When denormalization is good, immutable event design, the "snapshot at the moment of business significance" pattern.

---

## How to use this catalog

When drafting an article:

1. Pick the concept you want to teach.
2. Scan this catalog for an imperfection that *makes the concept matter*.
3. Use that imperfection as the story setup.
4. Walk through the concept as the resolution.

Example: writing about *materialized views*? Imperfection #3 (snapshot/log drift) is your setup — the Diwali outage is the story.

Example: writing about *semantic layers*? Imperfection #10 (attribution split) or #2 (column/attribute disagreement) is your setup.
