# Phase 5 Public README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the public-facing GitHub README, two LICENSE files (MIT for code, CC BY 4.0 for prose), and a decisions-log entry that records Phase 5 outcomes.

**Architecture:** Hybrid-audience README: hero + jump-link block + Quickstart serve cold visitors and impatient developers; Articles index + Cast card + repo-map serve article readers and the curious. The README is the front door — no detail beyond one level deep; everything else lives in `bible/`, `schema/`, `supabase/README.md`. Dual license (MIT code, CC BY 4.0 prose) supports both forking and quote-with-credit.

**Tech Stack:** Markdown, GitHub-flavored Markdown anchors. No Python, no SQL — pure prose work.

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `LICENSE` | create | MIT license, covers code (Python generator, SQL files, queries) |
| `LICENSE-prose.md` | create | CC BY 4.0 license, covers prose (README, articles, bible, schema, decisions-log) |
| `README.md` | create | Public-facing front door (the bulk of this plan) |
| `decisions-log.md` | modify (append before "How to use this log") | Record Phase 5 license + contributing decisions |

---

## Task 1: `LICENSE` (MIT, code)

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create the file with standard MIT text**

```
MIT License

Copyright (c) 2026 Hardik Savaliya

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license for code (Python generator, SQL, queries)"
```

---

## Task 2: `LICENSE-prose.md` (CC BY 4.0, prose)

**Files:**
- Create: `LICENSE-prose.md`

- [ ] **Step 1: Create the file**

```markdown
# Prose License — CC BY 4.0

The prose content of this repository — including but not limited to:

- `README.md`
- All files in `articles/`
- All files in `bible/`
- All files in `schema/`
- `decisions-log.md`
- `style-guide.md`
- All other Markdown files outside `LICENSE` and `LICENSE-prose.md` themselves

— is licensed under the **Creative Commons Attribution 4.0 International**
license (CC BY 4.0).

You are free to:

- **Share** — copy and redistribute the material in any medium or format
- **Adapt** — remix, transform, and build upon the material for any purpose,
  even commercially

Under the following terms:

- **Attribution** — You must give appropriate credit ("Hardik Savaliya, from
  the BoltBasket project at <REPO-URL>"), provide a link to the license, and
  indicate if changes were made.

Full license text: <https://creativecommons.org/licenses/by/4.0/legalcode>

Code in this repository (the Python generator at `supabase/seed/generator/`,
all SQL files in `supabase/`, and any code in `queries/`) is licensed
separately under the MIT License — see [`LICENSE`](LICENSE).
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE-prose.md
git commit -m "chore: add CC BY 4.0 prose license (README, bible, schema, articles)"
```

---

## Task 3: `README.md` — the front door

**Files:**
- Create: `README.md`

This is the bulk of the implementation. The README has 9 H2 sections in this order. Each step writes one section.

- [ ] **Step 1: Create README with hero + "What you can do here" jump-link block**

```markdown
# BoltBasket

BoltBasket is a fictional Indian quick-commerce company. The Postgres schema in this repo has 12 deliberate imperfections — circular foreign keys, snapshot/log drift, JSONB key chaos, the kind of thing every Series C engineering org actually ships. Each article on [Medium](TBD) walks through one of them as a story: who broke it, who debugged it, what they shipped. The data is here so you can run the queries yourself.

## What you can do here

- 📖 [**Read the articles**](#articles) — story-driven walk-throughs of one imperfection at a time, set inside BoltBasket
- 🐘 [**Run the database yourself**](#quickstart) — ~5 minutes from clone to a live Postgres with 210K rows of plausible Indian quick-commerce data
- 🎭 [**Meet the universe**](#meet-the-cast) — 14 named engineers and PMs you'll see recur across articles
```

- [ ] **Step 2: Append the Quickstart section**

````markdown
---

## Quickstart

```bash
git clone <REPO-URL> && cd boltbasket
cd supabase/seed/generator && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
PYTHONPATH=.. python generate.py
cd ../../..
psql "$SUPABASE_DB_URL" -f supabase/seed/01_smoke_seed.sql
for f in supabase/seed/02*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/marts/01_marts_views.sql
psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
```

You'll need: Postgres 15+ access (Supabase Cloud free tier works), Python 3.10+, `psql` on PATH, `SUPABASE_DB_URL` exported (or any `psql`-compatible connection string). Total time: ~5 minutes from clone to verify.

> **Need more options?** Detailed setup including Supabase Cloud signup, Docker-local Postgres, troubleshooting, and the per-DDL-file walkthrough lives in [`supabase/README.md`](supabase/README.md).
````

- [ ] **Step 3: Append the Articles section (placeholder)**

```markdown
---

## Articles

_No articles published yet — Phase 6 starts soon. Once they ship, each row in the table below maps article → key SQL files / verify queries the article references._

| # | Title | Concept | Imperfection | SQL / queries |
|---|---|---|---|---|

```

- [ ] **Step 4: Read `bible/characters.md` to source taglines, then write the Cast section**

Run: `cat bible/characters.md`

For each of the 14 characters, extract a single sentence (~12-18 words) that captures their recurring role. Use the bio's "Recurring role" field as the strongest source; fall back to "Personality" if needed.

The 14 characters in the order they appear in `bible/characters.md`:

1. Aryan Mehta — CEO
2. Sanya Kapoor — COO
3. Vikram Bansal — CTO
4. Naveen Krishnan — CFO
5. Priya Raghavan — Lead Data Engineer
6. Noel Thomas — Engineering Manager, Data
7. Devika Rao — Senior Data Engineer
8. Arjun Pillai — Data Engineer
9. Meera Joshi — Analytics Engineer
10. Siddharth (Sid) Patel — Senior PM, CX
11. Rohan Desai — PM, Growth
12. Anjali Singh — PM, Supply & Inventory
13. Faisal Khan — VP, Dark Store Operations
14. Pooja Nair — Director, Ad Sales

Append this section, replacing each `<one-line>` with the extracted tagline:

```markdown
---

## Meet the cast

| Name & Role | One-liner |
|---|---|
| **[Aryan Mehta](bible/characters.md#aryan-mehta)** — CEO | <one-line> |
| **[Sanya Kapoor](bible/characters.md#sanya-kapoor)** — COO | <one-line> |
| **[Vikram Bansal](bible/characters.md#vikram-bansal)** — CTO | <one-line> |
| **[Naveen Krishnan](bible/characters.md#naveen-krishnan)** — CFO | <one-line> |
| **[Priya Raghavan](bible/characters.md#priya-raghavan)** — Lead Data Engineer | <one-line> |
| **[Noel Thomas](bible/characters.md#noel-thomas)** — EM, Data | <one-line> |
| **[Devika Rao](bible/characters.md#devika-rao)** — Senior Data Engineer | <one-line> |
| **[Arjun Pillai](bible/characters.md#arjun-pillai)** — Data Engineer | <one-line> |
| **[Meera Joshi](bible/characters.md#meera-joshi)** — Analytics Engineer | <one-line> |
| **[Siddharth (Sid) Patel](bible/characters.md#siddharth-sid-patel)** — Sr PM, CX | <one-line> |
| **[Rohan Desai](bible/characters.md#rohan-desai)** — PM, Growth | <one-line> |
| **[Anjali Singh](bible/characters.md#anjali-singh)** — PM, Supply & Inventory | <one-line> |
| **[Faisal Khan](bible/characters.md#faisal-khan)** — VP, Dark Store Operations | <one-line> |
| **[Pooja Nair](bible/characters.md#pooja-nair)** — Director, Ad Sales | <one-line> |

Full bios in [`bible/characters.md`](bible/characters.md).
```

**Tagline drafting rules:**
- One sentence, 12–18 words.
- Concrete and recurring — what role do they play across multiple articles, not their CV.
- No buzzwords ("comprehensive", "robust", etc., per Section 3 of the spec).
- Specific where possible: name a city, a number, an arc they're tied to.

**Suggested taglines as a starting point** (the implementer reads each bio and adjusts):

| Name | Suggested one-liner |
|---|---|
| Aryan Mehta | Reads dashboards constantly; will Slack a data engineer at 11pm to ask why a number changed. |
| Sanya Kapoor | Mumbai-based. Owns operations, and the constant war between delivery speed and unit economics. |
| Vikram Bansal | Made the 2021 AWS bet. Now stewards the GCP migration he didn't plan for. |
| Naveen Krishnan | Wants one number for revenue. Discovers there are three. |
| Priya Raghavan | Inherited the data platform without anyone calling it that. Diwali-outage protagonist. |
| Noel Thomas | Manages the data team and the budget. Argues with Sid Patel about metrics every Monday. |
| Devika Rao | Quiet authority on the warehouse layer. Shipped the BigQuery migration that's still not done. |
| Arjun Pillai | Newest data engineer. Asks the questions that surface two-year-old assumptions. |
| Meera Joshi | Owns the marts layer. The bridge between data engineers and PMs. |
| Siddharth (Sid) Patel | Sharp, opinionated, has Aryan's ear. Always disagrees with Noel about which metric is true. |
| Rohan Desai | Growth PM running experiments; will fight for every basis point of conversion. |
| Anjali Singh | The bridge between Bengaluru data and Mumbai ops. Translates between both. |
| Faisal Khan | Knows every dark store's rider count by memory. Mumbai HQ, all twelve store-codes. |
| Pooja Nair | Wants multi-touch attribution. Brand customers want last-click. Imperfection #10 lives here. |

- [ ] **Step 5: Append the "What's in this repo" section**

```markdown
---

## What's in this repo

- **[`bible/`](bible/)** — the BoltBasket universe. Cast bios, story arcs, year-by-year timeline, fictional tech stack. Read these before drafting articles or if you want the lore.
- **[`schema/`](schema/)** — the data model on paper. Entities, relationships, and the catalog of [12 deliberate imperfections](schema/imperfections.md). Each imperfection has its own story-potential note.
- **[`supabase/`](supabase/)** — the live reference database. DDL, smoke seed, generator for ~210K rows of bulk activity, marts (BigQuery-equivalent views), verify queries. Setup walkthrough lives in [`supabase/README.md`](supabase/README.md).
- **[`articles/`](articles/)** — drafts and published pieces. (Empty until Phase 6.)
- **[`queries/`](queries/)** — standalone SQL files referenced by articles. Each file named `<article-slug>.sql` so the link from Medium → GitHub is obvious.
- **[`docs/superpowers/`](docs/superpowers/)** — design specs and implementation plans for this project's own development.
```

- [ ] **Step 6: Append the Reproducibility section**

```markdown
---

## Reproducibility

- **Every article links to the specific SQL it walks through.** Article on Medium → `queries/<article-slug>.sql` here. Open it, run it, get the same answer the article does.
- **The bulk seed generator is deterministic.** Fixed `SEED=42`. Re-running `python generate.py` produces byte-identical SQL — your data matches the data the article was written against, row for row.
- **Verify your install** with `psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql`. The script reports counts for all 11 imperfections that are demonstrable in relational data (#1–#8, #10–#12; #9 lives in MongoDB conceptually).
```

- [ ] **Step 7: Append the License + Contributing section**

```markdown
---

## License & contributing

**Two licenses, by file type:**

- **Code** (Python generator, SQL files, queries): [MIT](LICENSE).
- **Prose** (README, `articles/`, `bible/`, `schema/`, `decisions-log.md`): [CC BY 4.0](LICENSE-prose.md).

**About contributions:** This is a writing project. The data and code exist to support specific articles, so I'm not accepting feature PRs.

- **Bug reports welcome** — if a SQL query in an article doesn't reproduce, or a verify check fails on a clean install, please open an issue.
- **Typo fixes welcome as PRs.**
- **Other PRs will probably be politely closed** — please open an issue first if you want to propose something larger.
```

- [ ] **Step 8: Append the "Who's behind this" section**

```markdown
---

## Who's behind this

**Built by Hardik Savaliya.** Articles on [Medium](TBD) · [LinkedIn](TBD).

This is a personal project. Opinions and mistakes are mine, not my employer's.
```

- [ ] **Step 9: Commit the README**

```bash
git add README.md
git commit -m "docs: add public-facing README

Hybrid-audience structure (hero + jump-links + Quickstart for the
impatient; cast + repo-map + reproducibility for the curious).
Article index is a placeholder until Phase 6 ships the first piece.
TBD links: Medium and LinkedIn URLs to be filled in by author before
the first GitHub push; <REPO-URL> in Quickstart and prose-license
attribution to be replaced once the repo is published."
```

---

## Task 4: Verify the README

**Files:** none (verification-only task)

- [ ] **Step 1: Banned-phrase grep**

Per the spec's voice rules, these must not appear in the README:

```bash
cd "/Users/hardiksavaliya/Documents/windsurf projects /boltbasket"
grep -niE 'comprehensive|robust|powerful|seamless|leverage|deep dive|in today.s fast|in the world of data|this project aims to' README.md
```

Expected: no matches (exit code 1 from grep). If anything matches, rewrite the offending sentence.

- [ ] **Step 2: Anchor link verification**

Every internal anchor link in the README (`#articles`, `#quickstart`, `#meet-the-cast`) must resolve to an actual H2 heading in the same file. Every relative path link (`bible/`, `schema/imperfections.md`, `supabase/README.md`, `queries/`, `LICENSE`, `LICENSE-prose.md`) must point to a path that exists.

```bash
# Confirm each H2 heading the jump-links target exists
grep -E '^## (Articles|Quickstart|Meet the cast)' README.md

# Confirm each relative path link resolves to an existing file/dir
ls bible/ schema/imperfections.md supabase/README.md queries/ LICENSE LICENSE-prose.md
ls bible/ schema/ supabase/ articles/ queries/ docs/superpowers/

# Confirm bible/characters.md anchors exist for all 14 characters
for name in "aryan-mehta" "sanya-kapoor" "vikram-bansal" "naveen-krishnan" \
            "priya-raghavan" "noel-thomas" "devika-rao" "arjun-pillai" \
            "meera-joshi" "siddharth-sid-patel" "rohan-desai" "anjali-singh" \
            "faisal-khan" "pooja-nair"; do
  if grep -q "^### " bible/characters.md && grep -i "^### .*${name//-/[ -]}" bible/characters.md > /dev/null; then
    echo "✓ $name"
  else
    echo "✗ $name MISSING"
  fi
done
```

Expected: all 3 H2 anchors present, all paths exist, all 14 character anchors confirmed. If any fail, fix the README link or the bible heading.

- [ ] **Step 3: Manual Quickstart smoke test**

The Quickstart block must work end-to-end against a fresh DB. Since the live DB already has data loaded, the test is to mentally walk through each command and confirm:
- All paths exist relative to the cloned repo root
- `python generate.py` invocation matches what works (`PYTHONPATH=.. python generate.py` from `supabase/seed/generator/` per the existing generator/README.md)
- The for-loop expansion for `02*.sql` files matches the actual filenames in `supabase/seed/`

```bash
ls supabase/seed/01_smoke_seed.sql supabase/seed/02*.sql supabase/marts/01_marts_views.sql supabase/verify/imperfections_check.sql
```

Expected: all 11+ files present (smoke + 7 bulk + marts + verify).

- [ ] **Step 4: Commit any fixes from steps 1–3**

If any of the verifications surfaced fixes to the README, commit them as a follow-up:

```bash
git add README.md
git commit -m "fix(readme): address verification findings (banned phrases / broken anchors / wrong paths)"
```

If everything passed clean, this step is a no-op.

---

## Task 5: Append `decisions-log.md` entry

**Files:**
- Modify: `decisions-log.md` (insert before "## How to use this log")

- [ ] **Step 1: Append the entry**

Find the line `## How to use this log` in `decisions-log.md`. Insert before it (after the previous entry's `---` separator):

```markdown
## 2026-05-04 — Phase 5 complete: public README + dual license + contributing posture

**What changed:**

1. New `README.md` at repo root: hybrid-audience structure (hero + jump-links + Quickstart for the impatient; cast card + repo map + reproducibility for the curious). Article index is a placeholder until Phase 6 ships the first piece.
2. New `LICENSE` (MIT) covers code: the Python generator at `supabase/seed/generator/`, all SQL files in `supabase/`, and any future code in `queries/`.
3. New `LICENSE-prose.md` (CC BY 4.0) covers prose: README, `articles/`, `bible/`, `schema/`, `decisions-log.md`, and other Markdown.
4. README explicitly sets a non-OSS-community contributing posture: bug reports and typo PRs welcome; feature PRs will probably be politely closed.
5. Article-to-source link convention locked in for Phase 6+: each article on Medium links to `queries/<article-slug>.sql` for its specific SQL, plus `bible/characters.md#<character-anchor>` for named engineers.

**Why:** Phase 5's brief was a public README that introduces BoltBasket to anyone landing on the repo. The hybrid structure serves cold visitors in the first 30 seconds (hero), article readers in the next 10 (jump-link to article index), and curious developers in 5 minutes (Quickstart). Dual license keeps SQL fork-friendly while requiring credit on prose. The "no feature PRs" stance is set up-front so the project doesn't accumulate community-management overhead it doesn't have capacity for.

**Author-fill placeholders left in the README** (resolve before publishing the repo):
- `<REPO-URL>` in the Quickstart `git clone` line and in `LICENSE-prose.md` attribution example.
- `[Medium](TBD)` and `[LinkedIn](TBD)` in the hero and "Who's behind this" sections.

**Affects:** `README.md`, `LICENSE`, `LICENSE-prose.md`. No code changes, no schema changes, no Supabase impact.

**What's next:** Push the repo to GitHub (Phase 5's natural endpoint, gated on author-fill of `<REPO-URL>` and the Medium/LinkedIn handles). Then Phase 6 (Week 1 Post 1 draft).

---
```

- [ ] **Step 2: Commit**

```bash
git add decisions-log.md
git commit -m "docs(decisions): record Phase 5 — public README, dual license, contributing posture"
```

---

## Self-Review

Walked the spec sections against the tasks. All Section 1 (structure), Section 2 (Quickstart), Section 3 (voice), Section 4 (cross-link strategy + cast), Section 5 (license + author + contributing), Section 6 (Definition of Done) requirements map to Tasks 1–5:

| Spec section | Task |
|---|---|
| §1 README structure (9 H2 sections) | Task 3 (Steps 1–8) |
| §2 Quickstart block | Task 3 Step 2 |
| §3 Voice/tone (banned phrases) | Task 4 Step 1 |
| §4.1 "What's in this repo" map | Task 3 Step 5 |
| §4.2 Article-link convention | Captured in repo map (Step 5) + decisions-log (Task 5) |
| §4.3 No imperfection enumeration | Honored in hero (Task 3 Step 1) and §4 map (Step 5) |
| §4.4 Cast taglines | Task 3 Step 4 |
| §5 License (MIT + CC BY 4.0) | Tasks 1, 2 |
| §5 Author attribution | Task 3 Step 8 |
| §5 Contributing posture | Task 3 Step 7 |
| §6 Definition of Done | All tasks combined; verification in Task 4 |
| §7 Out of scope | Respected (no sub-dir READMEs created, no diagram, no badges) |

Placeholder scan: clean. The `TBD`/`<REPO-URL>` markers in the README are intentional author-fill placeholders, listed in the decisions-log entry as such — they aren't gaps in the plan.

Type consistency: file paths and section names match across tasks (e.g., `bible/characters.md` referenced consistently in Task 3 Step 4 and Task 4 Step 2).
