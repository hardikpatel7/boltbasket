# BoltBasket — Timeline

The three-era evolution of BoltBasket. Useful for "how did we get here" and "where are we going" articles, and to keep the universe internally consistent when referring to the past or future.

---

## Era 1: Year 1 (Aug 2021 – Aug 2022)

**The Scrappy Era**

- 1 city: Bangalore. 4 dark stores: Indiranagar, HSR, Koramangala, Whitefield.
- ~25 employees total. Vikram + 2 engineers building the entire stack.
- ~2,000 orders/day at peak, ~12,000 SKUs.

**The data stack:**
- Single Postgres database for everything: products, orders, inventory, users.
- No data warehouse. Analytics happen via read replica + ad-hoc Metabase.
- Vikram personally writes most ad-hoc SQL for Aryan's investor decks.
- Inventory updates via cron jobs running every 5 minutes.

**The defining problem:** Speed of iteration matters more than data quality. Things break, get fixed in 30 minutes, and shipping continues.

**Useful for content:** "How a startup *should* think about data when it's small" — the answer is "less than you think." Push back on the modern data stack maximalism.

---

## Era 2: Year 3 (current canonical "now," late 2025)

**The Series C Era — where most articles are set**

- 15 cities, ~280 dark stores, ~1,500 employees, ~1.1M orders/day.
- ~25-person data team across data engineering, analytics engineering, data science, BI.
- ~47K SKUs in master catalog.

**The data stack (current — see `stack.md` for detail):**
- Snowflake was primary warehouse mid-2023 → mid-2024. BigQuery (on GCP) became primary in Q3 2024 after the data team's cost-driven migration. Snowflake still hangs on for ~30% of analytical workloads, officially "in retirement" but never quite gone.
- Postgres for transactional (orders, inventory, users) — still the source of truth for many things.
- MongoDB for the legacy product catalog (still partially canonical).
- Kafka for event streaming (orders, app events, inventory changes).
- Airflow for orchestration. dbt for transformations. Looker as primary BI. Some Metabase still hanging around. Sanya's team uses Excel.
- Real-time pipelines on ClickHouse (added 2024) for ops dashboards.
- A nascent ML platform built on SageMaker for forecasting and ranking.
- ~60 active dbt models. ~40 Airflow DAGs. ~12 Kafka topics that matter.

**The defining problems:**
- Multiple sources of truth, conflicting metrics
- Migration from legacy stack incomplete (Arc 6)
- Ops adoption gap (Arc 3)
- New data demands from advertising business (Arc 5)
- Hyperdense expansion straining geo-data systems (Arc 4)

**This is the era where 95% of articles are set.** When in doubt, write here.

---

## Era 3: Year 5 (projected — late 2027)

**The Pre-IPO Era — useful for "where are we going" articles**

Speculative but internally consistent projection. Use when writing forward-looking articles or when you want to show how today's decisions play out.

- ~20–25 cities, ~500 dark stores, ~3,000 employees, ~3M orders/day.
- ~60-person data org (data eng + analytics eng + DS + ML eng + BI).
- IPO preparation underway. Compliance, audit, financial reporting requirements skyrocket.

**The expected data stack:**
- BigQuery remains primary, but with significant data lakehouse footprint (Iceberg-on-GCS) for cost reasons. Snowflake fully retired by ~2027. The AWS-side analytical pieces (ClickHouse for ops, lingering SageMaker) consolidated or migrated.
- Real-time everywhere. ClickHouse → Apache Pinot migration debated.
- MLOps as a first-class function. Production models for forecasting, ranking, fraud, attribution.
- A semantic layer (likely dbt's metric layer or a Cube.dev-style standalone layer) is the canonical metric source.
- Data fabric / mesh architecture: domain teams own their data, platform team provides infrastructure.
- LLM-powered internal tools: text-to-SQL for exec dashboards, automated incident summaries, the rest of the obvious applications.
- Privacy and compliance tooling becomes serious — DPDP Act compliance, audit trails on PII access, data retention enforcement.

**The defining problems (projected):**
- Coordinating data work across many domain teams (the data mesh tax)
- Cost optimization (BigQuery slot reservations and cross-cloud egress become recurring board topics)
- Real-time/batch unification
- AI/ML governance: what's the model that decided to surge price this delivery?

**Useful for content:** "Where is the modern data stack heading" — speculative articles that BoltBasket Year 5 grounds in something concrete.

---

## City expansion timeline (canonical)

For when articles need to reference "we launched in X in year Y":

- **2021:** Bangalore (founding)
- **2022:** Pune, Hyderabad, Mumbai
- **2023:** Delhi NCR, Chennai, Ahmedabad, Kolkata
- **2024:** Jaipur, Chandigarh, Coimbatore, Kochi
- **2025:** Indore, Nagpur, Lucknow

(Total: 15 cities by current canonical "now.")

---

## Funding timeline (canonical)

- **Sep 2021:** Seed, $4M, led by a Bangalore-based seed fund + angels
- **Mar 2022:** Series A, $18M, led by a global VC's India fund
- **Nov 2022:** Series B, $48M, led by a Singapore-based growth fund
- **May 2024:** Series B extension, $35M (down round mood, but not technically down — flat valuation)
- **Mar 2025:** Series C, $90M, same Singapore fund leading + new participation

Total raised: ~$195M. Round it to "~$200M" in articles.

---

## Useful "in-universe time" anchors

When writing, you can reference these without explanation — they're canon:

- "Right after the Series A" → mid-2022, ~6 cities, scrappy stack
- "When we hired Noel" → mid-2023, peak migration chaos
- "Before the Diwali outage" → before Q4 2024
- "After the Diwali outage" → Q1 2025 onward, semantic layer push begins
- "The Bangalore hyperdense bet" → May 2025 onward
- "When Pooja joined" → Q2 2025, ad business ramps
