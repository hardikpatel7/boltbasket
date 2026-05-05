# The Diwali Outage That Taught Us the Difference Between "Healthy" and "Right"

*A story from BoltBasket — a fictional Indian quick-commerce company I use as a teaching device. The data is real (you can run the queries against the [reference Supabase](https://github.com/hardikpatel7/boltbasket)); the company isn't.*

---

## The 4 PM Saturday moment

The dashboard was green. All five inventory pipelines had succeeded in the last ninety seconds. [Priya Raghavan](../bible/characters.md#priya-raghavan), BoltBasket's Lead Data Engineer, was looking at it on a Saturday afternoon — Day 2 of Diwali week 2024, around 4 PM IST, the part of the day where ghee and sweets and dry fruits move faster than anything else BoltBasket sells.

Then her phone buzzed. [Aryan Mehta](../bible/characters.md#aryan-mehta), the CEO, had DM'd her a screenshot of a Twitter thread.

> *"Ordered ghee from BoltBasket, app showed it in stock, got cancelled 8 minutes later. Sweets ruined."*
>
> *"Same. Three orders cancelled in a row. What is happening."*
>
> *"BoltBasket app is showing things they don't have. Why."*

The dashboard said everything was fine. The customers said it wasn't. Both screens were telling the truth.

The next six hours cost BoltBasket about ₹4.2 crore in revenue. Cancellation rate hit 11% — normal is 1.8%. Aryan found out about it from Twitter before the team's own monitoring caught it. That detail still hurts the most.

How can both screens be telling the truth?

---

## Why "the dashboard is green" wasn't a lie

The inventory pipeline at BoltBasket was simple in the way real production systems are simple. Every ninety seconds, a job ran a source query against `raw.inventory_movements` (the append-only log of every stock change), refreshed a materialized view, and upserted the result into `raw.store_inventory` (the current snapshot). A Looker dashboard read from the snapshot. Customers' apps read from a service that read from the snapshot. The freshness budget was ninety seconds.

The monitoring on this pipeline was what most teams have. It checked: did the refresh job complete? Yes. Did it return without error? Yes. Therefore, green. The dashboard wasn't lying — the job *was* running. Every ninety seconds, like clockwork, the job exited cleanly.

What it wasn't checking was whether the source query at the start of that pipeline was actually finishing within the ninety-second window. Under Diwali load — three times the normal traffic, stretched concurrency on the warehouse, hot product rows on a few SKUs — that source query slowed from twelve seconds to eighty. Each refresh now started against an input that was already a minute and a half stale. Then two minutes. Then three.

The job kept succeeding. The dashboard kept showing green. The data quietly aged out from under everyone.

"Succeeded" doesn't mean "right."

---

## Liveness vs freshness, explained plainly

Two words I want to put on the table, because the difference between them is the whole article.

**Liveness** is "did the system do the thing it was supposed to do?" Did the job exit cleanly? Did the API return 200? Did the cron tick fire on time? Liveness is about whether the *process* is alive.

**Freshness** is "is the output a faithful representation of reality *now*?" Does what's in the snapshot match what actually happened upstream? Is the dashboard reading from data younger than its purported staleness budget? Freshness is about whether the *answer* is current.

Most monitoring systems implement liveness. They were designed in an era when the failure mode was "the job died" — not "the job kept running but the answer it produced is wrong." Liveness and freshness are the same when the system is healthy. They diverge under load.

Here's the BoltBasket pipeline as a picture:

```
   raw.inventory_movements          (append-only log)
            │
            │  source query (intended 60s budget)
            ▼
   ┌──────────────────────┐
   │   MV refresh job     │  ── ✅ liveness check sat HERE
   └──────────────────────┘     ("the job exited 0")
            │
            │  intended: sub-second snapshot upsert
            ▼
   raw.store_inventory              (snapshot)
            │
            ▼
   Looker dashboard                 ("everything green")

   ─────────────────────────────────────────────────
   Where the freshness check should have been: ❓

   freshness_drift_cells = COUNT(*)
   FROM store_inventory si
   JOIN (SELECT dark_store_id, product_id,
                SUM(quantity_change) AS replay_qty
         FROM inventory_movements
         GROUP BY 1, 2) r USING (dark_store_id, product_id)
   WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty)
```

The green check mark is where BoltBasket's monitoring sat during Diwali. The red question mark is where the freshness check should have been — between the snapshot and the dashboard, comparing the snapshot to a replay of the log it was supposed to derive from.

### What liveness checks actually catch

Liveness catches process failures. The Postgres connection died. The Airflow worker crashed. The Kubernetes pod got OOM-killed. The cron didn't fire. These are real failure modes and you absolutely need liveness checks for them.

Liveness misses correctness failures. A job that completed against stale input. A query that returned successfully but with the wrong answer. A snapshot that got upserted but the upstream that fed it hadn't actually advanced. A pipeline that takes thirty times longer than designed but still exits zero. The monitor doesn't care.

Look at what the liveness check on BoltBasket's inventory pipeline returns *today*, against the post-fix reference database — same monitoring pattern, same kind of result table:

```
       pipeline_name        | status  |     started_ist     |    finished_ist     | duration_seconds
----------------------------+---------+---------------------+---------------------+------------------
 inventory_snapshot_refresh | success | 2025-10-14 11:23:42 | 2025-10-14 11:36:20 |              758
 inventory_snapshot_refresh | success | 2025-10-14 10:30:17 | 2025-10-14 10:39:11 |              534
 inventory_snapshot_refresh | success | 2025-10-14 03:59:47 | 2025-10-14 04:28:39 |             1732
 inventory_snapshot_refresh | success | 2025-10-14 03:36:43 | 2025-10-14 03:50:12 |              809
 inventory_snapshot_refresh | success | 2025-10-14 03:35:17 | 2025-10-14 04:02:45 |             1648
```

Five rows. Status: success, success, success, success, success. The shortest run took nine minutes; the longest, twenty-nine. Whatever budget this pipeline was originally designed to fit inside, it isn't fitting anymore. The monitor doesn't notice. It only checks "did the job exit cleanly," and yes, it did. Five times.

### How to write a freshness check

A freshness check compares the system's output to an independent source of truth. For the append-only-log + snapshot pattern that BoltBasket uses (and that half the data systems you've ever worked with use), the log itself *is* the independent source of truth. Replay it. Compare the result to the snapshot. If they disagree, the snapshot is stale.

Here is the freshness check BoltBasket should have had on Day 2 of Diwali — the full file is at [`queries/diwali-outage-freshness-vs-liveness.sql`](../queries/diwali-outage-freshness-vs-liveness.sql) — running against the same reference database:

```
 store_code |          product_name           | snapshot_says | replay_says | drift
------------+---------------------------------+---------------+-------------+-------
 BLR-KOR-01 | Parle-G Original Biscuits 800g  |          1085 |        1071 |    14
 BLR-WHF-01 | Amul Gold Milk 1L Tetra Pack    |          1076 |        1084 |    -8
 PNQ-AUN-01 | Britannia Brown Bread 400g      |          1050 |        1054 |    -4
 BOM-AND-01 | Aashirvaad Whole Wheat Atta 5kg |          1380 |        1378 |     2
 BOM-POW-01 | Britannia Brown Bread 400g      |          1122 |        1124 |    -2
```

Five cells where the snapshot disagrees with the log. The Koramangala store thinks it has fourteen more packs of Parle-G than the movement log says it actually does. Whitefield thinks it's eight cartons of Amul Gold short of what the log says it has. Each of those cells is a cell where a customer might walk into the BoltBasket app, see "in stock," tap order — and find out eight minutes later that there was no Parle-G to pick.

This is the article. The first query says everything is fine. The second query says five things are wrong. Both are true.

---

## How BoltBasket actually fixed it

The fix shipped through Q1 2025, after the post-incident review. [Vikram Bansal](../bible/characters.md#vikram-bansal), BoltBasket's CTO, joined the war room remotely from Goa during the original outage; he stayed on the post-mortem committee through the rebuild. [Noel Thomas](../bible/characters.md#noel-thomas), the Engineering Manager for the Data Platform, was on a Mumbai-bound flight when the incident started — by the time he landed, half of what he wrote on the next four flights was the design doc.

The shape of the fix is a parallel reconciliation job. Every thirty minutes, a small Python service computes the replay sum from `inventory_movements` and compares it to `store_inventory.quantity_on_hand` for every (store, product) cell. The output is a single Datadog metric, `inventory.snapshot_replay_drift_cells`. Anomaly detection on the metric pages on-call if more than three cells stay drifted for more than fifteen minutes.

The original pipeline still runs on Airflow, exactly the way it did before. The reconciliation runs alongside it as an independent process with its own logs, its own metric, its own alerting. The point of doing it as a separate service was that *the original pipeline's monitoring couldn't be the thing that caught the original pipeline's failure mode*. You need a second pair of eyes that doesn't share assumptions with the first pair.

Cost: two engineers for three weeks, plus around ₹7L per year in additional Datadog metric volume. Scope honest: this fix is for inventory only. The pattern — parallel reconciliation, drift metric, anomaly detection — is now a checklist item for every new pipeline the data team builds. Around twelve of the thirty older pipelines have been retrofitted. The rest sit on a backlog under the line "we'll get to it" — which is engineer for "we won't, until something breaks."

---

## What you'd watch for / what we got wrong

This fix has at least three things worth knowing about before you copy it.

**The reconciliation job itself can fail.** We monitor two things' liveness now — the original pipeline's liveness and the reconciliation's liveness — and neither of them ensures freshness. We've added one more layer of "did the job run." If both fail at the same time (which happens during deploys, during region-wide DR drills, during rare but real Datadog outages), we're back where we started. Two layers of "did the job run" is still asking the wrong question.

**False positives during scheduled slow-windows.** Our Sunday-night ETL backfills make the replay diverge from the snapshot for a couple of hours every week, on purpose. We added an exception list — "ignore drift between Sunday 23:00 and Monday 02:00 IST" — and that exception list is now config that will drift from operational reality the next time someone changes the backfill schedule and forgets to update the alerting.

**Freshness is semantically harder than liveness.** "Did the job run" is one boolean. "Is the answer correct" requires you to know what 'correct' means. At BoltBasket, what 'correct' means is itself contested between the data team and the finance team — they've been disagreeing about a single revenue number for the better part of a year. *That's a future post.*

---

## TL;DR + what's next

Most monitoring asks "did the job run?". Few teams remember to ask "is the answer right?". Diwali 2024 taught us the gap between those two questions can cost crores. The fix is a parallel reconciliation step with its own metric and its own alert — and even that fix has its own failure modes, because freshness is harder to define than liveness in the first place.

**Next post:** when finance and the data team disagree on a single number — and what a semantic layer fixes (and doesn't).

Schema, queries, and seed data for this post: [github.com/hardikpatel7/boltbasket](https://github.com/hardikpatel7/boltbasket).

I write about data, AI, and the gap between what dashboards say and what's actually true. If you build or use them, we'll get along.
