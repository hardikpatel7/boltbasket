# Phase 6 Week 1 Article Implementation Plan: The Diwali Outage

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Week 1 of the BoltBasket content project — a Medium-ready Markdown article (~1500–2000 words) about the Diwali outage and the lesson it taught about liveness vs freshness checks, with one runnable SQL companion file, one canonical diagram, and the supporting cross-file updates that lock in the article-publication pattern for Phase 7+.

**Architecture:** Four sequential tasks. SQL first (concrete, smallest, the article's runnable backbone). Diagram second (visual reference for the article's §3). Article third (the bulk; six sections per `templates/long-form-post.md`). Wrap-up updates fourth (story-arc status, README index, decisions-log). Each task produces a single git commit.

**Tech Stack:** Markdown, SQL (Postgres 15+), Excalidraw (or ASCII fallback). No code, no tests in the traditional sense — verifications are grep-based content checks (banned phrases, anchor resolution, number-density), plus running the SQL against the live Supabase to confirm the article's quoted result tables match real output.

---

## Task 1: SQL companion file

**Files:**
- Create: `queries/diwali-outage-freshness-vs-liveness.sql`

- [ ] **Step 1: Create the SQL file with verbatim content from spec §5**

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

- [ ] **Step 2: Run both queries against live Supabase, capture output**

```bash
cd "/Users/hardiksavaliya/Documents/windsurf projects /boltbasket"
set -a; . ./.env; set +a
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f queries/diwali-outage-freshness-vs-liveness.sql \
  2> >(sed -E 's#"[^"]*@[^"]*"#"<REDACTED>"#g' >&2)
```

Expected output:
- Query 1: 5 rows with `pipeline_name = 'inventory_snapshot_refresh'`, status mix is fine — they're real `pipeline_runs` rows, not necessarily all "success". The article copy needs to either (a) describe whatever the actual mix is, OR (b) the implementer filters Query 1 for `status = 'success'` to make the "all green" framing exact. Pick (b): change Query 1's WHERE clause to add `AND status = 'success'`.
- Query 2: exactly 5 rows. Each row shows store_code, product_name, snapshot_says, replay_says, drift. The 5 cells that drift are listed in the SQL header comment of `supabase/seed/02c_inventory.sql` (commit `352532c`).

- [ ] **Step 3: If Query 1 returned mixed statuses, refine to filter for success**

If the bulk-seeded `pipeline_runs` has a mix (which it does — generator produces ~80% success, ~20% failed/partial), update the SQL file to add `AND status = 'success'` to Query 1 so the article's "everything succeeded" framing is unambiguous:

```sql
WHERE pipeline_name = 'inventory_snapshot_refresh'
  AND status = 'success'
```

Re-run after edit, confirm Query 1 still returns 5 rows.

- [ ] **Step 4: Commit**

```bash
git add queries/diwali-outage-freshness-vs-liveness.sql
git commit -m "feat(queries): add Week 1 article SQL — Diwali outage liveness vs freshness

Two queries against the live Supabase. Query 1 is the liveness check
that gave BoltBasket false confidence (5 'success' rows). Query 2 is
the freshness check they should have had — replay vs snapshot returns
the 5 drifted cells from Imperfection #3.

Companion file for the Week 1 article 'The Diwali Outage That Taught
Us the Difference Between Healthy and Right'. Naming convention:
queries/<article-slug>.sql, locks in for Phase 7+."
```

---

## Task 2: Diagram

**Files:**
- Create: `assets/diwali-outage-pipeline.excalidraw` (source) OR replace with ASCII fallback if Excalidraw not used
- Create: `assets/diwali-outage-pipeline.png` (export, only if Excalidraw used)

- [ ] **Step 1: Decide diagram format**

Two options:
- **A (preferred):** Excalidraw source + PNG export. Hand-drawn aesthetic matches the storytelling voice. Workflow: open <https://excalidraw.com>, build the diagram, save as `.excalidraw` JSON to `assets/diwali-outage-pipeline.excalidraw`, export to `assets/diwali-outage-pipeline.png` for Medium upload.
- **B (fallback):** ASCII block diagram embedded directly in the article Markdown. No image files. Less polished but legible on Medium (Medium renders Markdown code blocks).

If choosing A, proceed to Step 2. If choosing B, skip to Step 4 (no image files, the diagram lives in the article body).

- [ ] **Step 2: Build the Excalidraw diagram (Option A)**

Open <https://excalidraw.com> in a browser. Build the diagram per spec §4:

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

Visual layout guidance:
- Three rectangle nodes for the three Postgres tables/jobs (inventory_movements, MV refresh, store_inventory) plus one for the Looker dashboard.
- Solid downward arrows between them.
- A green checkmark badge next to the MV refresh node, labeled "liveness check landed here".
- A red question mark badge BETWEEN the MV refresh node and store_inventory, labeled "freshness check should have been here".
- Below the main pipeline, a callout box containing the freshness-check SQL pseudocode.
- Hand-drawn font (Excalidraw default — Virgil).

Save:
- File → Save to file → save the `.excalidraw` JSON to `assets/diwali-outage-pipeline.excalidraw`.
- File → Export image → PNG, "with background" + "embed scene" both checked → save to `assets/diwali-outage-pipeline.png`.

- [ ] **Step 3: Verify image renders correctly**

```bash
file assets/diwali-outage-pipeline.png
ls -la assets/diwali-outage-pipeline.*
```

Expected: PNG file ~50–200 KB, dimensions reasonable for Medium (recommend ~1200px wide so it doesn't need to scale up). The `.excalidraw` JSON should be human-readable (open it to confirm).

- [ ] **Step 4: Commit (whichever option chosen)**

For Option A:
```bash
git add assets/diwali-outage-pipeline.excalidraw assets/diwali-outage-pipeline.png
git commit -m "docs(assets): add Diwali outage pipeline diagram (Excalidraw + PNG)

Single canonical diagram for the Week 1 article. Block diagram of the
inventory pipeline (movements → MV refresh → snapshot → dashboard)
with annotations showing where the liveness check sat (at the refresh
job's exit) vs where the freshness check should have been (between
the snapshot and the dashboard, comparing replay sum to on-hand).

Source .excalidraw kept in repo so the diagram is reproducible/editable;
PNG is what Medium uploads use."
```

For Option B (ASCII fallback): no commit at this task. The ASCII diagram is embedded directly in the article during Task 3.

---

## Task 3: Article draft

**Files:**
- Create: `articles/diwali-outage-freshness-vs-liveness.md`

The article is ~1500–2000 words across 6 sections. Each step below writes one section against the constraints from spec §2.

**Voice guard rails for every step:**
- First person ("I" / "we"). The author observing/consulting on BoltBasket, not an employee.
- Past tense for the incident. Present tense for systems.
- Specific numbers in every section that can carry one. Plausible over real, honest over polished.
- **Banned phrases** (drop on sight): comprehensive, robust, powerful, seamless, leverage, deep dive, "in today's fast", "in the world of data", "this project aims to". Plus everything in `style-guide.md`.

**Character link convention** (each character's first mention in the article):
- Priya Raghavan → `[Priya Raghavan](../bible/characters.md#priya-raghavan)`, role: Lead Data Engineer
- Aryan Mehta → `[Aryan Mehta](../bible/characters.md#aryan-mehta)`, role: CEO
- Noel Thomas → `[Noel Thomas](../bible/characters.md#noel-thomas)`, role: Engineering Manager, Data
- Vikram Bansal → `[Vikram Bansal](../bible/characters.md#vikram-bansal)`, role: CTO

After first mention, use first names ("Priya", "Aryan", "Noel", "Vikram"). For Siddharth in any future appearance, use "Sid" per `bible/characters.md` rule.

- [ ] **Step 1: Write the article frontmatter + title**

Open `articles/diwali-outage-freshness-vs-liveness.md`. Start the file with:

```markdown
# The Diwali Outage That Taught Us the Difference Between "Healthy" and "Right"

*A story from BoltBasket — a fictional Indian quick-commerce company I use as a teaching device. The data is real (you can run the queries against the [reference Supabase](https://github.com/hardikpatel7/boltbasket)); the company isn't.*

---

```

The italic disclaimer is the project's standard one-line tee-up. It signals to the reader that BoltBasket is fiction without belabouring it.

- [ ] **Step 2: Write Article §1 — The 4pm Saturday moment (~150 words)**

Append to `articles/diwali-outage-freshness-vs-liveness.md`. Constraints:
- Open mid-action.
- Name [Priya Raghavan](../bible/characters.md#priya-raghavan), Lead Data Engineer, in the first three sentences with a linked first-mention.
- One specific time anchor: Saturday, Day 2 of Diwali week 2024, ~4pm IST.
- Two screens: one shows the dashboard (green), the other shows a Slack DM from [Aryan Mehta](../bible/characters.md#aryan-mehta), CEO — a screenshot of a Twitter thread of customer complaints.
- Closing line poses the question: how can both screens be telling the truth?

Sample opening (refine in voice to match author's style):

> The dashboard was green. All five inventory pipelines had succeeded in the last ninety seconds. Priya Raghavan, BoltBasket's Lead Data Engineer, was looking at it on a Saturday afternoon — Day 2 of Diwali week, 4 PM IST, the part of the day where ghee and sweets and dry fruits move faster than anything else BoltBasket sells. Then her phone buzzed. Aryan Mehta, the CEO, had DM'd her a screenshot of a Twitter thread.
>
> *"Ordered ghee from BoltBasket, app showed it in stock, got cancelled 8 minutes later. Sweets ruined."*
>
> *"Same. Three orders cancelled in a row. What is happening."*
>
> *"BoltBasket app is showing things they don't have. Why."*
>
> The dashboard said everything was fine. The customers said it wasn't. Both were telling the truth.

Length target: 150 words. The sample is a starting point — refine the voice, but keep the structure (mid-action open, full-name first mention, two-screens-two-truths setup, question-posing close).

- [ ] **Step 3: Write Article §2 — Why "the dashboard is green" wasn't a lie (~200 words)**

Append. Constraints:
- Walk through the actual inventory pipeline: source query against `raw.inventory_movements` → materialized view refresh → `raw.store_inventory` snapshot. Refresh runs every 90 seconds.
- Explain the monitoring that was in place: did the refresh job complete? Yes. Did it return without error? Yes. Therefore green.
- Reveal the gap: the source query slowed from 12 seconds to 80 seconds under Diwali load. Each refresh got progressively staler input. Job kept "succeeding" while data quietly aged.
- End with a clear restatement: "succeeded" doesn't equal "right".
- Numbers to anchor: 90s refresh interval; 12s normal source query duration; 80s under load.

Length target: 200 words.

- [ ] **Step 4: Write Article §3 — Liveness vs freshness, explained plainly (~700 words)**

The teaching meat. This is the longest section.

Sub-section A — **Definitions** (~150 words):
- Liveness: "did the system do the thing it was supposed to do?" Does the job exit cleanly? Did the API return 200? Did the Cron tick fire on time?
- Freshness: "is the output a faithful representation of reality NOW?" Does what's in the snapshot table match what actually happened upstream? Is the dashboard reading from data younger than its purported staleness budget?
- The two diverge under load — when the system can keep doing the thing, but the thing it's doing is increasingly out-of-date.

Sub-section B — **The diagram** (placed inline, ~50 words of caption):

If using the Excalidraw diagram (Task 2 Option A), embed the PNG with a caption. Markdown:

```markdown
![Inventory pipeline with monitor positions: liveness check sat at the refresh job's exit; freshness check should have been between the snapshot and the dashboard.](../assets/diwali-outage-pipeline.png)

*Where each kind of check belongs in the pipeline. The green ✅ shows where BoltBasket's monitoring sat during Diwali. The red ❓ shows where it should have been.*
```

If using the ASCII fallback (Task 2 Option B), embed the ASCII diagram from spec §4 in a Markdown code block, with the same caption underneath.

Sub-section C — **What liveness checks actually catch** (sub-heading, ~150 words):
- They catch process failures: a job crashed, a connection timed out, a service is unreachable.
- They miss correctness failures: a job completed against stale input; a query returned successfully but with the wrong answer; a snapshot was upserted but the upstream that fed it hadn't actually advanced.
- One concrete BoltBasket example: walking through what each of those 90-second refreshes actually saw during Diwali load. The job took its same ~3 seconds of CPU time. Postgres said the upsert succeeded. The data being upserted was already 60 seconds older than the previous refresh's data.

Sub-section D — **How to write a freshness check** (sub-heading, ~250 words):
- A freshness check compares the system's output to an independent source of truth. For an append-only-log + snapshot pattern, the log IS the independent source of truth. Replay it; compare to the snapshot.
- Show Query 1 from `queries/diwali-outage-freshness-vs-liveness.sql` with its output (5 rows of "success", under 1 second each).
- Show Query 2 (the freshness check) with its output (5 drifted cells with store codes, product names, drift values).
- The contradiction IS the article: Query 1 says the job is fine; Query 2 says the data is wrong; both are true.
- Inline link: *the full file lives at* [`queries/diwali-outage-freshness-vs-liveness.sql`](../queries/diwali-outage-freshness-vs-liveness.sql).

Sub-section E — **Sub-section transitions** (~100 words spread across the section): at most 2 sub-headings total per template rules ("What liveness checks actually catch" and "How to write a freshness check"). Definitions and diagram are part of the running text under §3's main heading, not their own sub-sections.

Length target: 700 words for §3 total.

- [ ] **Step 5: Write Article §4 — How BoltBasket actually fixed it (~300 words)**

Append. Constraints:
- Concrete return to the company. What was built, by whom, in what shape?
- Q1 2025: shipped a parallel **replay reconciliation job**. Every 30 minutes, computes the replay sum from `inventory_movements` and compares to `store_inventory.quantity_on_hand`. Emits a Datadog metric named `inventory.snapshot_replay_drift_cells`.
- Anomaly detection: pages on-call if `> 3 cells drifted for > 15 minutes`.
- Tooling specifics: existing pipeline on Airflow; new reconciliation as a small Python service; Datadog for the metric.
- Cost specifics: 2 engineers × 3 weeks; ~₹7L/year additional Datadog cost.
- Honest scope: applied to inventory only. The pattern is now a checklist for new pipelines. ~12 of 30 legacy pipelines retrofitted. The rest sit on the backlog under "we'll get to it."
- First-mention link to [Vikram Bansal](../bible/characters.md#vikram-bansal), CTO, when describing who joined the war room from Goa during the original incident.
- First-mention link to [Noel Thomas](../bible/characters.md#noel-thomas), Engineering Manager, Data, when describing who was on the Mumbai-bound flight when this started.

Length target: 300 words.

- [ ] **Step 6: Write Article §5 — What you'd watch for / what we got wrong (~200 words)**

Append. Constraints:
- Three real downsides, no apologetic framing.
- (1) The reconciliation job itself can fail. We now monitor TWO things' liveness, neither of which ensures freshness. Two layers of "did it run" is still asking the wrong question.
- (2) False positives during scheduled slow-windows. Sunday-night ETL backfills make replay diverge temporarily. We added an exception list. Exception lists drift from reality.
- (3) Freshness is semantically harder. "Did the job run" is one boolean. "Is the answer correct" requires you to know what 'correct' means. At BoltBasket, "correct" is itself contested. *That's a future post.*
- The third item must explicitly foreshadow the Two Revenues arc → Week 2.

Length target: 200 words.

- [ ] **Step 7: Write Article §6 — TL;DR + what's next (~100 words)**

Append. Constraints:
- TL;DR captures the actual insight, not the title.
- Suggested TL;DR: *Most monitoring asks "did the job run?". Few ask "is the answer right?". The Diwali outage taught us the gap can cost crores. The fix is a parallel reconciliation step with its own metric — and even that has its own failure modes.*
- Next-post tease: *Next post: when finance and the data team disagree on a single number — and what a semantic layer fixes (and doesn't).*
- Repository link: *Schema, queries, and seed data for this post: [github.com/hardikpatel7/boltbasket](https://github.com/hardikpatel7/boltbasket).*
- Connect line: *I write about data, AI, and the gap between what dashboards say and what's actually true. If you build or use them, we'll get along.*
- No prior-article cross-link (Week 1 has no priors). Skip that template element for this article only.

Length target: 100 words.

- [ ] **Step 8: Verify the article**

Run all five checks. Each must pass before commit:

```bash
cd "/Users/hardiksavaliya/Documents/windsurf projects /boltbasket"
ARTICLE=articles/diwali-outage-freshness-vs-liveness.md

echo "=== 1. word count (target 1500-2000) ==="
wc -w "$ARTICLE"

echo ""
echo "=== 2. banned phrases (should be empty) ==="
grep -niE 'comprehensive|robust|powerful|seamless|leverage|deep dive|in today.s fast|in the world of data|this project aims to' "$ARTICLE" \
  && echo "FAIL — rewrite the offending sentence" \
  || echo "OK"

echo ""
echo "=== 3. all 4 character anchors resolve ==="
for slug in priya-raghavan aryan-mehta noel-thomas vikram-bansal; do
  if grep -q "characters.md#${slug}" "$ARTICLE"; then
    if grep -qE "^### " bible/characters.md; then
      anchor_present=$(awk -v s="$slug" '/^### / { gsub(/^### /, ""); gsub(/[^a-zA-Z0-9 ()-]/, ""); name=tolower($0); gsub(/ +/, "-", name); gsub(/[()]/, "", name); if (name == s) print "yes" }' bible/characters.md)
      if [ "$anchor_present" = "yes" ]; then
        echo "OK: $slug linked + anchor exists"
      else
        echo "FAIL: $slug linked but anchor missing in bible/characters.md"
      fi
    fi
  else
    echo "FAIL: $slug not linked in article"
  fi
done

echo ""
echo "=== 4. specific-number density (target ≥5 distinct numeric anchors) ==="
grep -oE '₹[0-9]+(\.[0-9]+)?\s*(cr|crore|lakh|L)|[0-9]+\s*%|[0-9]+\s*(s|sec|second|seconds|min|minute|minutes|hour|hours)|[0-9]+\s*(cells|rows|engineers|weeks|stores)' "$ARTICLE" | sort -u | head -20
echo "(should show ≥5 distinct phrases)"

echo ""
echo "=== 5. required cross-links ==="
grep -c "queries/diwali-outage-freshness-vs-liveness.sql" "$ARTICLE" \
  && echo "OK: queries link present" \
  || echo "FAIL: queries link missing"
grep -c "github.com/hardikpatel7/boltbasket" "$ARTICLE" \
  && echo "OK: repo link present in §6" \
  || echo "FAIL: repo link missing"
```

If any check fails, fix the article and re-run before continuing.

- [ ] **Step 9: Manually re-run the SQL queries one final time, paste fresh output into the article**

The article quotes the result tables of Query 1 and Query 2. Re-run both queries to make sure the article's quoted output matches the live DB EXACTLY (5 rows each, drift values, store codes, product names). If any value drifted (it shouldn't — `SEED=42` is deterministic — but verify), update the article.

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f queries/diwali-outage-freshness-vs-liveness.sql \
  2> >(sed -E 's#"[^"]*@[^"]*"#"<REDACTED>"#g' >&2)
```

- [ ] **Step 10: Commit the article**

```bash
git add articles/diwali-outage-freshness-vs-liveness.md
git commit -m "feat(articles): Week 1 — The Diwali Outage (liveness vs freshness)

First published article. ~1700 words across 6 sections per the
long-form template. Arc 1 (Diwali outage) + Imperfection #3 (snapshot/
log drift) → teaches liveness vs freshness checks. Priya's POV;
Aryan, Noel, Vikram introduced as supporting cast (4 of 14 named
characters introduced).

Companion SQL at queries/diwali-outage-freshness-vs-liveness.sql.
Foreshadows Two Revenues arc for Week 2."
```

---

## Task 4: Wrap-up updates (story-arc + README + decisions-log)

**Files:**
- Modify: `bible/story-arcs.md` (Arc 1 status field)
- Modify: `README.md` (article index table — Article #1 row)
- Modify: `decisions-log.md` (append Phase 6 entry before "How to use this log")

- [ ] **Step 1: Update `bible/story-arcs.md` Arc 1 status**

Find Arc 1's existing status line:

```markdown
**Status:** Resolved. A series of fixes shipped through Q1 2025, kicking off the broader semantic layer / data quality push.
```

Replace with:

```markdown
**Status:** Resolved. A series of fixes shipped through Q1 2025, kicking off the broader semantic layer / data quality push. Referenced in [Week 1 article](../articles/diwali-outage-freshness-vs-liveness.md): *The Diwali Outage That Taught Us the Difference Between "Healthy" and "Right"*.
```

- [ ] **Step 2: Update `README.md` article index — Article #1 row**

Find the article index placeholder block:

```markdown
## Articles

_No articles published yet — Phase 6 starts soon. Once they ship, each row in the table below maps article → key SQL files / verify queries the article references._

| # | Title | Concept | Imperfection | SQL / queries |
|---|---|---|---|---|
```

Replace with:

```markdown
## Articles

| # | Title | Concept | Imperfection | SQL / queries |
|---|---|---|---|---|
| 1 | [The Diwali Outage That Taught Us the Difference Between "Healthy" and "Right"](#)¹ | Liveness vs freshness | [#3](schema/imperfections.md) snapshot/log drift | [queries/diwali-outage-freshness-vs-liveness.sql](queries/diwali-outage-freshness-vs-liveness.sql) |

*¹ Medium URL TBD — replace `(#)` with the Medium link once the article publishes at <https://medium.com/@hardik_7>.*
```

- [ ] **Step 3: Append `decisions-log.md` Phase 6 entry**

Find the line `## How to use this log` in `decisions-log.md`. Insert before it (after the previous entry's `---` separator):

```markdown
## 2026-05-04 — Phase 6 complete: Week 1 article shipped (Diwali Outage)

**What changed:**

1. New article at `articles/diwali-outage-freshness-vs-liveness.md` — Week 1's published piece. Arc 1 (Diwali outage) + Imperfection #3 (inventory snapshot/log drift); teaches liveness vs freshness checks via Priya's POV. ~1700 words across the 6-section template.
2. New companion SQL at `queries/diwali-outage-freshness-vs-liveness.sql` — two runnable queries against the live Supabase. Output verbatim quoted in the article.
3. New diagram at `assets/diwali-outage-pipeline.png` (+ Excalidraw source) showing the inventory pipeline with the two kinds of monitor positions annotated. (Or ASCII fallback embedded directly in the article — implementation chose <pick one>.)
4. README article index now has its first row. Medium URL is `(#)` placeholder until the author publishes and replaces it.
5. `bible/story-arcs.md` Arc 1 status field updated to flag Week 1 article references it.

**Why:** Week 1's job is to set the voice, the structural bar, and seed the universe so future articles can callback to a known incident. Diwali outage is the bible's flagship story; using it for Week 1 gives Week 2-N pieces an anchor to reference (the project's reader-retention tactic).

**Conventions locked in by Week 1** (apply to all future articles):

- **Filename pattern:** `articles/<slug>.md` and `queries/<slug>.sql` use the same slug. No date in filename. ≤6 words, lowercase-kebab, no stopwords.
- **Character first-mention:** full name + role + link to `bible/characters.md#<anchor>`. Subsequent mentions: first name only (or "Sid" for Siddharth per bible rule).
- **Diagram:** one canonical block diagram per article, Excalidraw source + PNG export under `assets/`, both committed.
- **End-of-article elements:** GitHub repo link + connect line, always. Cross-link to a previous BoltBasket article from Week 2 onward. No "subscribe and like" CTA.
- **Cross-arc foreshadowing:** every article ends with a foreshadow line that hooks the next article. Week 1 → Week 2 = Two Revenues arc / semantic layer.
- **Voice + banned phrases:** see `style-guide.md` and the README's Voice section. The 9-phrase banned list (`comprehensive`, `robust`, `powerful`, `seamless`, `leverage`, `deep dive`, "in today's fast", "in the world of data", "this project aims to") is gated by `grep -niE` before commit.

**Affects:** `articles/`, `queries/`, `assets/`, `bible/story-arcs.md`, `README.md`. No code changes, no schema changes.

**What's next:**

- Author renders/finalizes the diagram (if not already), reviews the article one more pass with fresh eyes, then publishes on Medium and replaces the README's `(#)` Medium URL placeholder.
- Phase 7 (Week 2 article — Two Revenues arc, semantic layer) starts.

---
```

- [ ] **Step 4: Final commit**

```bash
git add bible/story-arcs.md README.md decisions-log.md
git commit -m "docs: Phase 6 wrap-up — story-arcs status, README article index, decisions-log

Arc 1 status now references the Week 1 article. README article-index
table has its first row (Medium URL TBD until publication).
decisions-log entry locks in the per-article conventions for Phase 7+:
filename pattern, character-link convention, diagram convention,
end-of-article elements, cross-arc foreshadowing."
```

- [ ] **Step 5: Push to origin**

```bash
git push origin master
```

Expected: pushes 4 new commits (Tasks 1-4) to GitHub. Post-push, the article + queries are visible at <https://github.com/hardikpatel7/boltbasket>.

---

## Self-Review

Walked the spec sections against the tasks. Coverage:

| Spec section | Plan task |
|---|---|
| §1 Pre-draft anchors (concept, protagonist, imperfection, etc.) | Task 3 (steps 2-7) — encoded in each section's constraints |
| §2 Article 6-section structure | Task 3 steps 2-7 (one step per section) |
| §3 Voice & tone (banned phrases) | Task 3 step 8 (grep verification) |
| §4 Diagram | Task 2 |
| §5 SQL queries | Task 1 |
| §6 Character intros + cross-links + foreshadow | Task 3 steps 2 + 5 + 6 + 7 (specifies which character appears in which section, plus link conventions) |
| §7 File deliverables | All 4 tasks (one per major file) |
| §8 Definition of Done | Task 3 step 8 (verification) + Task 4 step 5 (push) |
| §9 Out of scope (Medium publication, etc.) | Respected — Medium upload is post-plan author action |

**Placeholder scan:** clean. The `(#)` Medium URL in the README index row is intentional, documented in the decisions-log entry as a post-publication fill-in. The "implementation chose <pick one>" in the decisions-log Phase 6 entry's diagram bullet is a pick-one-and-fill-in based on which Task 2 option the implementer chose, not a vague gap.

**Type/path consistency:** the slug `diwali-outage-freshness-vs-liveness` is used identically across `queries/`, `articles/`, and the README index row. The diagram path `assets/diwali-outage-pipeline.*` is consistent across Task 2 (creation), Task 3 step 4 (article embed), and the decisions-log entry.
