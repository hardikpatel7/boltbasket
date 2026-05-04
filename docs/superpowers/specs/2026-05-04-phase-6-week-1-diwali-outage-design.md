# Phase 6 — Week 1 Post 1 Design: The Diwali Outage

**Date:** 2026-05-04
**Status:** Design approved by author; ready for implementation plan
**Phase reference:** CLAUDE.md → "Phase 6 (Week 1 Post 1 draft) — NOT STARTED"

## Context

Phase 6 ships the project's first published article. Week 1's job is to set the voice, the structural bar, and seed the universe so future articles can callback to a known incident. The article uses Arc 1 (the Diwali outage) and Imperfection #3 (inventory snapshot/log drift) to teach the difference between liveness checks and freshness checks. It's drafted as a long-form Medium piece per `templates/long-form-post.md`'s 6-section skeleton.

**Audience:** Indian PMs, EMs, and early-career data engineers (per `CLAUDE.md`'s standing audience definition). Article is technical enough to respect the data engineer and concrete enough that the PM understands the business stakes.

**Out of scope:** Medium publication itself (manual author action). Article #2 (Week 2) is foreshadowed but not part of this spec.

## 1. Pre-draft anchors

| Anchor | Value |
|---|---|
| Concept | Liveness vs freshness — "the pipeline ran successfully" vs "the data is correct now" |
| Protagonist | Priya Raghavan, Lead Data Engineer |
| Imperfection | #3 (store_inventory snapshot/log drift; 5 drifted cells on the live DB) |
| Arc | Arc 1 (Diwali Outage). Article establishes this as canon. |
| Title | "The Diwali Outage That Taught Us the Difference Between 'Healthy' and 'Right'" |
| Specific numbers | ₹4.2 cr revenue loss; 11% cancellation rate (vs 1.8% normal); ~6 hours; Day 2 of Diwali week 2024; 90s intended refresh budget; 80s actual source-query duration under load; 5 drifted cells |
| Honest tradeoff | The fix introduces its own failure modes — false positives during scheduled slow-windows; the reconciliation job itself can fail; "correct" is semantically harder to define than "ran" |
| POV / time | Priya's POV. Saturday afternoon, ~4pm IST. Day 2 of Diwali week 2024. |
| Cast introduced | Priya (protagonist), Aryan (Slack-with-Twitter-screenshot beat), Noel (Mumbai-bound flight), Vikram (Goa, joins war room remotely). 4 of 14 named characters. |

## 2. Article structure (6 sections, ~1500–2000 words total)

### Article §1 — The 4pm Saturday moment (~150 words)

A specific scene. Priya at her desk during Diwali week, dashboard green, all inventory pipelines "succeeded" in the last 90 seconds. Slack notification: Aryan has DM'd her a screenshot of a Twitter thread. Customers are tweeting about ordering ghee that the app showed in stock and getting cancelled 8 minutes later, sweets ruined.

Two screens, two truths. Closing line poses the question the reader now wants answered: *how can the dashboard be telling the truth while the customers are also telling the truth?*

**Rules followed:** Open mid-action. Name the protagonist (Priya Raghavan, Lead Data Engineer) within first three sentences. Link first mention to `bible/characters.md#priya-raghavan`.

### Article §2 — Why "the dashboard is green" wasn't a lie (~200 words)

Walk through the actual inventory pipeline: source query against `raw.inventory_movements` → materialized view refresh → snapshot in `raw.store_inventory`. Every 90 seconds.

The monitoring in place: did the refresh job complete? Yes (every time). Did it return without error? Yes. So the dashboard was right — the job WAS running.

The thing it WASN'T checking: was the source query actually finishing within the 90-second window? Under Diwali load, the source query slowed from 12s to 80s. Each refresh got progressively staler input. Monitor saw "succeeded" + "succeeded" + "succeeded" while the data quietly aged out.

**Goal of this section:** earn the reader's attention for the actual concept by setting up why a smart team's monitoring still failed.

### Article §3 — Liveness vs freshness, explained plainly (~600–800 words)

The teaching meat. Three components:

1. **Definitions.** Liveness: "did the system do the thing it was supposed to do?" Freshness: "is the output a faithful representation of reality NOW?" Most monitoring systems check liveness; few check freshness; the two diverge under load.

2. **One canonical diagram.** Block diagram of the pipeline with two kinds of monitor positions annotated. (Spec Section 4 below.)

3. **Two runnable SQL queries** against the live BoltBasket Supabase, with screenshots of their actual output:

   - Query 1 (liveness): selects from `raw.pipeline_runs` for `inventory_snapshot_refresh`, returns 5 success rows. *"Looks healthy. Was lying."*
   - Query 2 (freshness): replay-vs-snapshot check, returns 5 cells where `store_inventory.quantity_on_hand` disagrees with `SUM(quantity_change)` from movements. *"5 cells where the dashboard showed the wrong number."*

The contradiction between Query 1 ("all good") and Query 2 ("5 wrong") is the article's punchline.

Sub-headings (max 2 per template): "What liveness checks actually catch" and "How to write a freshness check."

Inline link to `queries/diwali-outage-freshness-vs-liveness.sql` here when introducing the SQL.

### Article §4 — How BoltBasket actually fixed it (~300 words)

The Q1 2025 fixes (concrete to BoltBasket):

- Shipped a parallel **replay reconciliation job**. Every 30 minutes, computes the replay sum from `inventory_movements` and compares to `store_inventory.quantity_on_hand`. Emits a Datadog metric `inventory.snapshot_replay_drift_cells`.
- Anomaly detection: page on-call if `> 3 cells drifted for > 15 minutes`.
- **Tooling:** existing pipeline on Airflow; new reconciliation as a small Python service; Datadog for the metric.
- **Cost:** 2 engineers × 3 weeks; ~₹7L/year additional Datadog cost.
- **Honest scope:** applied to inventory only. The pattern (parallel reconciliation + drift metric) is now a checklist for new pipelines. ~12 of 30 legacy pipelines retrofitted. The rest sit on the backlog under "we'll get to it."

Vikram joins the war room remotely from Goa during the original incident — first mention links to `bible/characters.md#vikram-bansal`.

### Article §5 — What you'd watch for / what we got wrong (~200 words)

The non-negotiable honesty section. Three real downsides:

1. **The reconciliation job itself can fail.** Now we monitor TWO things' liveness, neither of which ensures freshness. Two layers of "did it run" is still asking the wrong question.
2. **False positives during scheduled slow-windows.** Sunday-night ETL backfills make replay diverge temporarily. We added an exception list. Exception lists become config that drifts from reality.
3. **Freshness is semantically harder than liveness.** "Did the job run" is one boolean. "Is the answer correct" requires you to know what 'correct' means — and at BoltBasket, what 'correct' means is itself contested. *(Foreshadow line for the Two Revenues arc → Week 2.)*

### Article §6 — TL;DR + what's next (~100 words)

- **TL;DR:** monitoring asks "did it run?". Most teams forget to ask "is the answer right?". Diwali 2024 taught us the gap can cost crores. Add a parallel reconciliation with its own metric. The fix has its own failure modes.
- **Next post tease:** "Next post: when finance and the data team disagree on a single number — and what a semantic layer fixes (and doesn't)."
- **GitHub link:** "Schema, queries, and seed data for this post: [github.com/hardikpatel7/boltbasket](https://github.com/hardikpatel7/boltbasket)"
- **Connect line:** *"I write about data, AI, and the gap between what dashboards say and what's actually true. If you build or use them, we'll get along."*

No prior-article cross-link (Week 1 — there is no prior article). From Week 2 onward, every article ends with one cross-link to a previous BoltBasket post.

## 3. Voice & tone

Anchored to `style-guide.md`. Key rendering for this article:

- **First person.** "I" or "we" — the author observing/consulting on BoltBasket.
- **Past tense for the incident** ("Priya was paged…"). **Present tense for systems** ("BoltBasket runs Airflow…").
- **Specific over general; plausible over real; honest over polished.**
- **Banned phrases** (verified absent in §4 of this spec): comprehensive, robust, powerful, seamless, leverage, deep dive, "in today's fast", "in the world of data", "this project aims to". Plus anything in `style-guide.md`.
- **Indian context as default.** Bengaluru, Mumbai, Pune, ₹, IST timezones, Diwali as a time-of-year reference (no need to over-explain).

## 4. Diagram

One canonical diagram, placed at the start of Article §3 (right before the liveness/freshness definitions).

**What the diagram shows:** the inventory pipeline as a block diagram with two kinds of monitoring annotated.

```
   raw.inventory_movements          (append-only log)
            │
            │  source query (intended 60s budget)
            ▼
   [ MV refresh job ]                ── ✅ liveness check sat HERE
            │                            ("job exited 0")
            │  intended: sub-second snapshot upsert
            ▼
   raw.store_inventory               (snapshot)
            │
            ▼
   Looker dashboard                  ("everything green")

   ─────────────────────────────────────────────────
   Where the freshness check should have been:

   freshness_drift_cells = COUNT(*)
   FROM store_inventory si
   JOIN (SELECT dark_store_id, product_id,
                SUM(quantity_change) AS replay_qty
         FROM inventory_movements
         GROUP BY 1, 2) r USING (dark_store_id, product_id)
   WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty)
```

**Production format:** Excalidraw recommended (hand-drawn aesthetic matches the storytelling voice). Source `.excalidraw` JSON at `assets/diwali-outage-pipeline.excalidraw`; PNG export at `assets/diwali-outage-pipeline.png` for Medium upload. Both files version-controlled.

**Fallback:** ASCII block diagram (using Unicode box-drawing chars, similar to the sketch above) embedded directly in the Markdown. Acceptable but less polished. Mermaid is **not** acceptable — it doesn't render on Medium and would require a screenshot round-trip.

**No second visual.** Stock photos and decorative AI illustrations are explicitly banned by the template.

## 5. SQL committed to `queries/diwali-outage-freshness-vs-liveness.sql`

One file, two queries. Both runnable against the live BoltBasket Supabase. Both produce results the article quotes verbatim.

```sql
-- The Diwali Outage: companion SQL
-- ============================================================================
-- Demonstrates Imperfection #3: store_inventory snapshot/log drift.
-- Shows the two queries the article walks through.

-- Query 1 — LIVENESS CHECK (what BoltBasket had during Diwali 2024).
-- Asks: "did the inventory_snapshot_refresh job run successfully?"
-- Returns: 5 rows of "success" status. Looks healthy. Was lying.
SELECT
  pipeline_name,
  status,
  started_at AT TIME ZONE 'Asia/Kolkata' AS started_ist,
  finished_at AT TIME ZONE 'Asia/Kolkata' AS finished_ist,
  ROUND(EXTRACT(EPOCH FROM (finished_at - started_at)))::INT AS duration_seconds
FROM raw.pipeline_runs
WHERE pipeline_name = 'inventory_snapshot_refresh'
ORDER BY started_at DESC
LIMIT 5;

-- Query 2 — FRESHNESS CHECK (what BoltBasket SHOULD have had).
-- Asks: "does the snapshot match the replay of inventory_movements?"
-- Returns: 5 rows where store_inventory.quantity_on_hand disagrees with
-- SUM(quantity_change). Each row is a cell where the dashboard would
-- have shown the wrong number to a customer trying to order.
WITH replay AS (
  SELECT dark_store_id,
         product_id,
         SUM(quantity_change)::INT AS replay_qty
  FROM raw.inventory_movements
  GROUP BY dark_store_id, product_id
)
SELECT
  ds.store_code,
  p.product_name,
  si.quantity_on_hand                             AS snapshot_says,
  GREATEST(0, r.replay_qty)                       AS replay_says,
  si.quantity_on_hand - GREATEST(0, r.replay_qty) AS drift
FROM raw.store_inventory si
JOIN replay r USING (dark_store_id, product_id)
JOIN raw.dark_stores ds ON ds.dark_store_id = si.dark_store_id
JOIN raw.products    p  ON p.product_id     = si.product_id
WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty)
ORDER BY ABS(si.quantity_on_hand - GREATEST(0, r.replay_qty)) DESC;
```

**Reproducibility check:** the live Supabase already returns `drifted_cells = 5` (verified end-to-end in Phase 4b Task 15). The deterministic generator (`SEED=42`) ensures the exact 5 cells are stable across regenerations.

## 6. Character intros + cross-links

**Character introductions (4 of 14 named characters appear):**

- **Priya Raghavan** (protagonist, §1). First mention: full name + role. Link to `bible/characters.md#priya-raghavan`. Subsequent mentions: "Priya".
- **Aryan Mehta** (§1, Slack-with-Twitter-screenshot beat). Full name + CEO. Link to `bible/characters.md#aryan-mehta`.
- **Noel Thomas** (§2, "on a Mumbai-bound flight when this started"). Full name + Engineering Manager, Data. Link.
- **Vikram Bansal** (§4, "joined the war room remotely from Goa"). Full name + CTO. Link.

The article does NOT explain who these people are at length — README cast table + `bible/characters.md` carry that load. Article just names them with the link. Pattern locks in for all future articles.

**Inline repo cross-links:**

- **§3:** inline link to `queries/diwali-outage-freshness-vs-liveness.sql` when introducing the SQL.
- **§6:** repository link in the closing paragraph.

**Cross-arc foreshadowing (Two Revenues → Week 2 hook):**

- **§5:** one sentence foreshadow — *"…what 'correct' means is itself contested. That's a future post."*
- **§6:** explicit "next post" tease referencing the finance-vs-data disagreement.

**Filename convention** (locks in for all future articles): `articles/<slug>.md` and `queries/<slug>.sql` use the **same slug**. No date in filename. Slug is lowercase-kebab of distinguishing keywords, ≤6 words, no stopwords. Week 1: `diwali-outage-freshness-vs-liveness`. Future Week 2 (illustrative): `two-revenues-semantic-layer`.

## 7. Files created/modified

| Path | Action | Responsibility |
|---|---|---|
| `articles/diwali-outage-freshness-vs-liveness.md` | create | The article draft, ~1500–2000 words, 6 sections per template |
| `queries/diwali-outage-freshness-vs-liveness.sql` | create | Two queries verbatim from §5 of this spec |
| `assets/diwali-outage-pipeline.excalidraw` | create | Diagram source (Excalidraw JSON) — fallback ASCII if Excalidraw not used |
| `assets/diwali-outage-pipeline.png` | create | Diagram export for Medium upload |
| `bible/story-arcs.md` | modify | Arc 1 status field updated to flag Week 1 article references it |
| `README.md` | modify | Article #1 row added to article index table; Medium URL `(TBD)` until publication |
| `decisions-log.md` | modify (append before "How to use this log") | Phase 6 entry recording publication conventions and Week 1 ship |

## 8. Definition of Done

Phase 6 is done when:

1. Article draft committed at `articles/diwali-outage-freshness-vs-liveness.md` with all 6 sections per the template, ~1500–2000 words.
2. SQL committed at `queries/diwali-outage-freshness-vs-liveness.sql`, runnable against live Supabase, output matches the article's quoted result tables verbatim.
3. Diagram source + PNG export committed under `assets/`.
4. Banned-phrase grep on the article returns zero matches.
5. The article contains specific numbers in at least 5 distinct moments.
6. All 4 character first-mentions (Priya, Aryan, Noel, Vikram) use full name + role and link to `bible/characters.md#<anchor>`. Anchors resolve.
7. Inline `queries/<slug>.sql` link in §3; repo link in §6.
8. Two Revenues foreshadow present in §5; explicit "next post" tease in §6.
9. README article-index table has Article #1 row with `[Medium TBD](#)` placeholder.
10. `bible/story-arcs.md` Arc 1 status field updated.
11. `decisions-log.md` Phase 6 entry committed.
12. All commits pushed to `origin/master`.

## 9. Out of Scope

- **Medium publication itself** — manual author action via medium.com/@hardik_7 after the draft is approved and the diagram is rendered. Article-index Medium URL placeholder gets filled in by author post-publication.
- **Article #2 (Week 2)** — the "next post tease" is forward-looking copy, not an obligation in this plan.
- **Diagram tool selection** — Excalidraw recommended; ASCII fallback acceptable; whatever the author actually wants to use, as long as the diagram conveys the pipeline + two-monitor-positions concept.
- **Schema / DDL / generator changes** — live data already supports the article verbatim. No code changes.
- **Article tags / SEO metadata for Medium** — set by author at publication time.

## 10. After This

- Implementation plan via `superpowers:writing-plans` skill.
- Implementation work follows the plan.
- After draft is committed: author renders the diagram (if not already), reviews the article one more pass with fresh eyes, then publishes on Medium and replaces the README's Medium URL placeholder.
- Phase 7 (Week 2 article — Two Revenues / semantic layer) starts.
