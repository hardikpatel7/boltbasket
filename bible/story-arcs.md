# BoltBasket — Story Arcs

These are the recurring narratives you can reference across articles. They give readers the feeling of following a continuing story — like a TV show with running plotlines, not a series of disconnected episodes.

When drafting an article, see if it can hook into an existing arc. Cross-references between articles ("remember the Diwali outage I wrote about last month? this is what came of it…") are gold for retention.

---

## Arc 1: The Diwali Outage (Q4 2024)

**The setup:** During Diwali week 2024, BoltBasket's biggest revenue moment of the year, the inventory service started returning stale stock counts. Customers ordered items that weren't actually in dark stores. Cancellation rate hit 11% (normal: 1.8%) for ~6 hours on Day 2 of Diwali week. Estimated revenue loss: ₹4.2 crore. Estimated customer trust loss: harder to quantify but real.

**The root cause:** A materialized view in the inventory pipeline was supposed to refresh every 90 seconds. Under Diwali load, the underlying source query slowed from 12s to 80s, and the refresh started missing its window. The dashboard showed "everything green" because the freshness check was based on *job ran successfully*, not *job completed before next scheduled run*.

**Who's involved:** Priya was on-call. Noel was on a flight to Mumbai. Aryan found out from a customer tweet before the team's own monitoring caught it. Vikram joined the war room remotely from Goa.

**Why it matters for content:** This is BoltBasket's defining "we got humbled" moment. Reference it when writing about: monitoring philosophy, freshness vs. liveness checks, materialized views, the gap between "system is up" and "system is correct," post-incident processes, tech debt prioritization.

**Status:** Resolved. A series of fixes shipped through Q1 2025, kicking off the broader semantic layer / data quality push. Referenced in [Week 1 article](../articles/diwali-outage-freshness-vs-liveness.md): *The Diwali Outage That Taught Us the Difference Between "Healthy" and "Right"*.

---

## Arc 2: The Two Revenues (ongoing)

**The setup:** For most of 2024, the data team's "daily revenue" number and the finance team's daily revenue number disagreed. Sometimes by 2%. Sometimes by 8%. CFO Naveen kept his own Excel. The data team kept improving their dashboard. Aryan, in a board meeting, quoted the data team number; the board's investor compared it to the audited finance number; chaos.

**Why it happened:** Different definitions. Data team: order-placed-time, gross. Finance: order-fulfilled-time (or refund-issued-time, for refunds), net of discounts and refund timing differences. Plus a quietly broken refund flag in the orders pipeline that no one had noticed.

**Who's involved:** Meera (analytics engineer) is now driving the resolution. CFO Naveen, CEO Aryan, Anjali on the product side. The "metrics council" was formed in response.

**Why it matters for content:** Foundational arc for any article about semantic layers, metric definitions, data governance, single source of truth, dbt metric layer, BI tool sprawl, the social vs. technical sides of data quality.

**Status:** Active. Resolution in progress. Meera is building a metrics layer in dbt; the metrics council reviews definitions monthly.

---

## Arc 3: The Mumbai Excel Resistance (ongoing)

**The setup:** The Mumbai operations office runs parallel data systems to the Bangalore tech team's official ones. Faisal's dark store ops team has a network of ~40 Excel sheets that pull from various manual feeds and represent the "ground truth" Mumbai uses to make decisions. The Bangalore team's beautiful Looker dashboards are largely ignored by the people they're built for.

**Why it persists:** Trust. The Looker dashboards have been wrong (or differently right) too many times. The Excels were built incrementally by people who deeply understand the operational reality. They're also faster to modify on the fly during an operational issue.

**Who's involved:** Faisal (Mumbai ops VP) — defender of the Excels. Noel and Priya — the increasingly desperate champions of "please, just use the dashboard." Anjali (PM Supply & Inventory) — the bridge trying to migrate things gradually.

**Why it matters for content:** The richest arc for stories about data adoption, the social side of data products, why "build it and they will come" doesn't work, semantic layers (Mumbai's Excels are an organic semantic layer), and the political economy of data teams.

**Status:** Ongoing. Quarterly "Excel migration sprints" make incremental progress.

---

## Arc 4: The Bangalore Hyperdense Expansion (Q2 2025 — present)

**The setup:** In May 2025, BoltBasket made a strategic bet: rather than expand to new cities, double down in Bangalore by going from 28 dark stores to 52, targeting <8min delivery in core areas. This created an explosion of new data problems — store cannibalization analysis, demand redistribution forecasting, store-level CM1 attribution, last-mile rider rebalancing.

**Why it matters for content:** The freshest arc, with active problems being solved right now. Good for articles about: forecasting, attribution, geo-data, why unit economics get harder before they get easier, data infrastructure scaling.

**Status:** Active. ~40 stores live, 12 more planned by end of year.

---

## Arc 5: The Ad Business Ramp (2025 — present)

**The setup:** BoltBasket's ad revenue went from ~₹40L/month in Q1 2024 to ~₹4Cr/month by Q3 2025. Pooja Nair was hired specifically to build this. The data team is scrambling to support it: brand attribution, audience segmentation, sponsored search ranking, brand reporting dashboards. None of this existed 18 months ago.

**Why it matters for content:** Articles about new data domains being built, real-time vs batch tradeoffs, ML for ranking, attribution windows, the shift from internal-facing to external-facing data products (brands now consume BoltBasket dashboards).

**Status:** Active and growing. Increasingly the data team's biggest priority.

---

## Arc 6: The Migration That Won't Die (background, slow-burn)

**The setup:** Since mid-2023, the team has been "migrating" from a legacy MongoDB+Postgres setup (Vikram's original 9-week build) to a Snowflake-based modern data stack. The migration is now in its third year. Some pipelines run on both. Some live in only one. Nobody is fully sure which is canonical for what.

**Who's involved:** Everyone. Especially Devika, who's been quietly mapping which pipelines belong to which world.

**Why it matters for content:** The eternal arc. Stories about technical debt, the gap between greenfield design and lived reality, the cost of incomplete migrations, why "one source of truth" is harder than it sounds.

**Status:** Ongoing. Vikram half-jokes that it'll be done "in Q3" (year unspecified).

---

## Arc 7: The Plus Subscriber Mystery (Q3 2025)

**The setup:** BoltBasket Plus subscribers retain dramatically better than non-subscribers — but the data team isn't sure how much of that is *causal* vs. *selection bias* (the kind of customer who subscribes was already going to retain). A small in-house data science team is trying to do causal analysis. Sid wants to ship an aggressive Plus upsell flow; Noel is asking him to wait for the analysis. The debate is heated.

**Why it matters for content:** Stories about causal inference, A/B testing limits, propensity scoring, the social dynamics of data teams pushing back on product, and "what does this number actually mean."

**Status:** Active.

---

## Cross-arc principles

- **Arcs should evolve.** When a new article ships, update the relevant arc's status here.
- **Don't over-reference.** One or two callbacks per article is plenty. More feels like you're winking at the camera.
- **New arcs are welcome.** As you write, new threads will emerge. Add them here when they do.
- **Some articles don't need an arc.** Field notes especially can be standalone. That's fine.
