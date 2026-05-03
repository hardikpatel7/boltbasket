# BoltBasket — Tech Stack

The current canonical stack (Era 2, late 2025). Deliberately messy because real Series C companies are messy. Each component has a "why it's here" and where relevant a "why it's painful" — both are content gold.

**The defining architectural fact about BoltBasket: it runs across two clouds.** App and transactional infrastructure on AWS (Vikram's 2021 choice). Data and ML infrastructure on GCP (the analytics team's 2024 migration that's still in progress). The bridge between them is one of the most painful and most content-rich parts of the entire stack.

---

## The cloud split

**AWS (Mumbai region)** — owns the application and transactional layer.
- Postgres on RDS (the source of truth for orders, users, inventory snapshots)
- Kafka (Confluent Cloud, AWS-deployed)
- Redis (Elasticache)
- Application services on EKS
- Object storage on S3 for app assets
- DataDog for APM, CloudWatch for AWS-native observability

**GCP (Mumbai region)** — owns the analytics, data warehouse, and ML layer.
- BigQuery as the primary warehouse
- Cloud Storage (GCS) for the data lake
- Vertex AI for ML model training and serving
- Looker (GCP-native after Google's acquisition) for BI
- Pub/Sub for some internal data team event streaming
- Cloud Composer (managed Airflow) for orchestration

**The bridge between them:**
- Kafka topics on AWS → Confluent's BigQuery sink connector → BigQuery raw layer
- Postgres CDC via Debezium → Kafka → BigQuery (Devika's pet project; runs but is fragile)
- Some legacy Python jobs that pull Postgres → S3 → manual GCS transfer → BigQuery (yes, really; nobody has had time to retire them)
- Cross-cloud egress costs are a recurring CFO conversation

Why two clouds: Vikram chose AWS in 2021 because that's what he knew. The data team in 2024 was hitting Snowflake bill issues and wanted to evaluate alternatives; they piloted BigQuery and found it ~40% cheaper for their query patterns. Migration started in Q3 2024, still ongoing. Application team has no plans to leave AWS. Result: the architectural reality of the company is the bridge between these two worlds.

---

## Transactional / OLTP layer (AWS)

### Postgres (AWS RDS, multi-AZ)
- **What it holds:** orders, order_items, payments, users, addresses, riders, dark_stores, store_inventory (current snapshot), promotions, subscriptions.
- **Why it's here:** Vikram's original choice in 2021. Has scaled (vertically, mostly) ever since. Battle-tested, well-understood.
- **Why it's painful:** The `orders` table is 2.4 TB. Some queries that worked fine in 2023 now time out. Read replicas exist but their lag is unpredictable during peak. Indexing strategy is "we'll fix it after this launch" since 2022.

### MongoDB (Atlas, AWS-deployed)
- **What it holds:** Product catalog (the original schema), product images metadata, some customer profile attributes that never got migrated.
- **Why it's here:** Vikram's choice in 2021 because catalogs are nested and Mongo felt right. He'd choose differently today.
- **Why it's painful:** It's the *partial* source of truth for products. Some product attributes live in Postgres, some in Mongo, some in both with subtle differences. The sync between them is a fragile nightly job. Compounding this: Mongo lives on AWS but the analytics warehouse is on GCP — getting Mongo data into BigQuery requires a custom Python pipeline that breaks every other month.

### Redis (AWS Elasticache)
- **What it holds:** Session data, cart state, real-time inventory cache, dark store availability cache, geo-routing cache.
- **Why it's here:** Standard. Works fine.
- **Why it's painful:** The cache invalidation strategy for inventory is the most frequent source of bugs in the entire stack.

---

## Streaming / event layer

### Kafka (Confluent Cloud, on AWS)
- **What it carries:** Order lifecycle events, app activity events, inventory change events, rider location pings (sampled), dark store ops events.
- **Topics that matter:** `orders.events`, `inventory.changes`, `app.activity`, `rider.locations`, `darkstore.ops`.
- **Why it's here:** Added in 2023 when batch ETL stopped meeting needs.
- **Why it's painful:** Schema evolution is informal. The `orders.events` topic has had 4 schema versions; consumers have to handle all of them. Schema registry was set up but inconsistently used. Plus: the BigQuery sink connector occasionally drops events under load — the data team finds out when daily totals don't match.

### GCP Pub/Sub
- **What it carries:** Some internal data-team-owned event flows that didn't make sense to route through the AWS Kafka cluster (e.g., dbt run notifications, ML model deploy events, BigQuery cost alerts).
- **Why it's here:** When the data team needed something cloud-native on GCP, this was easier than adding more Kafka topics.
- **Why it's painful:** Now there are two event systems. Engineers have to know which events live where.

---

## Warehouse / OLAP layer (GCP)

### BigQuery
- **What it holds:** The canonical analytical store. ~3.2 TB of physical storage (BigQuery counts logical bytes too — much higher). 4 main datasets: `raw`, `staging`, `marts`, `sandbox`.
- **Why it's here:** Migrated from Snowflake (well, partially — see "Why it's painful") in 2024. The data team got tired of Snowflake bills growing 30% quarter-over-quarter. BigQuery's serverless model and per-query pricing made forecasting easier.
- **Why it's painful:** The migration isn't done. Some marts still live in a Snowflake instance the team is trying to retire. Some dashboards in Looker still query Snowflake; some query BigQuery. The plan was "migrate everything in 6 months"; that was 14 months ago.
- **Cost shape:** Most queries are flat-rate slot reservations (200 slots committed). Ad-hoc analysis and ML features run on on-demand pricing. The split between the two is itself a recurring optimization debate.

### Snowflake (deprecated but not gone)
- **Status:** ~30% of analytical workloads still run here. Officially "in retirement." The warehouse is small now (1 X-Small, scaled down dramatically), kept alive for ~12 dashboards no one has migrated.
- **Why it's painful:** Two warehouses with overlapping data. The same metric can be queried in either, and they sometimes disagree because the BigQuery version uses the new dbt models and the Snowflake version uses the old ones.

### ClickHouse (self-managed on AWS EC2)
- **What it holds:** Real-time ops dashboards. Order flow, dark store fulfillment, rider performance.
- **Why it's here:** Added in 2024 because BigQuery's streaming ingestion latency was too slow for ops use cases (the team needs sub-30-second freshness for the Mumbai ops dashboards).
- **Why it's painful:** Lives on AWS while the rest of analytics is on GCP. Self-managed = team toil. Replication setup is fragile. There's an active debate about migrating to Apache Pinot, going managed (Tinybird, Aiven), or just consolidating onto BigQuery if Google ever ships streaming reads with the right latency.

---

## Transformation / orchestration layer

### dbt (Cloud)
- **Project size:** ~60 active models. ~25 sources defined. Mart layer (`marts/`) split by domain: `marts/orders`, `marts/inventory`, `marts/users`, `marts/finance`.
- **Targets:** Most models target BigQuery. ~12 legacy models still target Snowflake. The team is *trying* to migrate the rest. Some models exist in both targets with diverging logic.
- **Why it's here:** Devika introduced it in late 2023; standard now.
- **Why it's painful:** Inconsistent quality. Some models have great tests and docs; some are write-once, never-touched. The metric layer is half-built (Arc 2 driving the rest).

### Cloud Composer (managed Airflow on GCP)
- **DAGs:** ~40 active. Mix of data ingestion, dbt orchestration, ML training, ops jobs.
- **Why it's here:** Standard. Migrated from MWAA (AWS Airflow) when the data team moved to GCP.
- **Why it's painful:** A few critical DAGs are "do not touch" — written by people who left, hold the company together. There's a `legacy_critical/` folder everyone is afraid of. A handful of ops-side DAGs still run on AWS MWAA because they orchestrate AWS-native services and migrating them is on someone's backlog.

### Fivetran
- **What it syncs:** Stripe (payments), Salesforce (B2B brand partnerships), HubSpot (marketing CRM), some Google Ads / Meta data.
- **Destination:** BigQuery (was Snowflake, switched in early 2025).
- **Why it's here:** Buy vs. build, leadership chose buy.
- **Why it's painful:** Cost is becoming a quarterly conversation.

### Custom Python ingestion
- **What it covers:** Anything Fivetran doesn't, plus the Postgres → BigQuery CDC pipeline (built before Fivetran existed for this team).
- **Why it's painful:** Multiple ingestion patterns coexist. Some use Debezium → Kafka → BigQuery via the Confluent connector. Some use direct BigQuery streaming inserts via a Python service. Some are ancient cron-based dumps to GCS. Cataloging which is which is on someone's quarterly OKR every quarter.

---

## BI / consumption layer

### Looker
- **Status:** Primary BI tool. ~80 dashboards across business teams.
- **Why it's here:** Selected in late 2023 over Tableau and Mode. The Google acquisition makes Looker + BigQuery integration a default-good choice for BoltBasket post-migration.
- **Why it's painful:** LookML modeling is concentrated in 3 people's heads. "Who can edit this?" is a frequent question. About 8 dashboards still query Snowflake while 70+ query BigQuery — depending on which underlying source, the same metric can show different numbers.

### Metabase
- **Status:** Self-hosted, semi-deprecated, still used by ~30 power users who refuse to migrate. Connects to both BigQuery and the legacy Snowflake.
- **Why it's painful:** Two parallel BI ecosystems. Dashboards in Metabase aren't visible in Looker; the same metric can be defined differently in each (Arc 2 again).

### Excel (Mumbai office)
- **Status:** Canonical for ops decisions despite official policy saying otherwise (Arc 3).
- **Why it's here:** Trust, speed, agility.
- **Why it's painful:** Not version controlled. Definitions drift.

---

## Data science / ML layer (GCP)

### Vertex AI
- **What runs on it:** Demand forecasting (per-store, per-SKU), delivery time estimation, fraud detection, search ranking (early days), Plus subscription propensity scoring.
- **Why it's here:** GCP-native, sits next to BigQuery, training jobs can read directly from the warehouse without egress costs.
- **Why it's painful:** No real ML platform abstraction. Each project is bespoke. Model monitoring is "check the dashboard sometimes." Some legacy models still run on SageMaker on AWS — the migration isn't complete here either.

### Notebooks (managed by Hex)
- **Status:** Hex was adopted in 2024 for analytics notebooks. Used heavily by DS and analytics engineering. Connects to BigQuery primarily.

---

## Governance / catalog layer

### Atlan
- **Status:** Adopted in late 2024 as the data catalog. Adoption is ~40% — many tables are catalogued, many aren't.
- **Why it's painful:** Metadata is only as good as the people maintaining it. Lineage is partial — covers BigQuery + dbt well, doesn't fully cover the AWS-side data sources or the cross-cloud bridges.

### No formal data quality tool yet
- Soda Core is being piloted on critical pipelines.
- Otherwise: dbt tests, manual spot checks, Slack alerts when something goes wrong.

### No formal MDM
- Master data is "wherever it ended up." This is acknowledged tech debt.

---

## Infrastructure / DevOps

- **AWS Mumbai (ap-south-1)** — application, transactional, streaming.
- **GCP asia-south1 (Mumbai)** — analytics, ML, BI.
- DR: AWS Singapore (ap-southeast-1) for critical app services. No formal DR for the GCP analytics side — accepted risk.
- Kubernetes (EKS) for application services on AWS.
- Terraform for infrastructure-as-code (~70% covered; legacy pieces still ClickOps; cross-cloud Terraform setup is its own headache).
- DataDog for APM. Grafana for ops metrics. Cloud Monitoring for GCP-native services.

---

## The deliberate messiness summary

For content purposes, the canonical "this is what's painful" list:

1. **Two clouds (AWS + GCP)** with the bridge between them being the single largest source of data engineering toil
2. **Two warehouses (BigQuery + lingering Snowflake) with overlapping metric definitions**
3. **Two transactional stores (Postgres + MongoDB) with overlapping product data**
4. **Two BI tools (Looker + Metabase) with conflicting metric definitions**
5. **Two ops realities (Looker dashboards + Mumbai Excels)**
6. **Two streaming systems (Kafka on AWS + Pub/Sub on GCP)**
7. **Two ML platforms (Vertex AI on GCP + lingering SageMaker on AWS)**
8. **Multiple ingestion patterns (Fivetran + Debezium/Kafka + custom Python + ancient cron dumps)**
9. **One incomplete migration that's been "Q3" for 3 years**
10. **One under-adopted catalog**
11. **Zero formal MDM**

Each of these is a rich vein of content. Mine them. The cross-cloud bridge especially — almost no one writes about this honestly, and it's the actual reality of most Indian Series C companies.
