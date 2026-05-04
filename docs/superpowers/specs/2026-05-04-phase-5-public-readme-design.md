# Phase 5 — Public GitHub README Design

**Date:** 2026-05-04
**Status:** Design approved by author; ready for implementation plan
**Phase reference:** CLAUDE.md → "Phase 5 (Public GitHub README) — NOT STARTED"

## Context

Phase 5 ships the public-facing README that introduces BoltBasket to anyone who lands on the GitHub repo. The repo already contains the bible (universe), schema (data model), Supabase database (smoke seed + ~210K bulk rows from Phase 4b), and decisions-log. None of these surface well to a first-time visitor — they're internal-facing files. The README is the front door.

**Audience reality.** Visitors will arrive from three places, in order of expected volume once articles ship:
1. Click-through from a Medium article they're reading.
2. The author's LinkedIn / Twitter share.
3. Cold GitHub search (rare initially).

**Out of scope for Phase 5.** Article index population (no articles published yet — Phase 6+ fills this). README internationalisation. CI badges (no CI yet). Custom GitHub topics / About metadata (set via GitHub UI, not via repo files).

## 1. README structure (top-level outline)

The README serves a hybrid audience: cold visitor (needs context), article reader (needs to find specific source files), and curious developer (wants to fork and play). The structure delivers all three from a single page:

```markdown
# BoltBasket

> Hero (3 sentences max): what BoltBasket is, that the Postgres schema has
> 12 deliberate imperfections, that articles on Medium walk through them
> as stories.

## What you can do here
- 📖 Read the articles → article index ↓
- 🐘 Run the database yourself → Quickstart ↓
- 🎭 Meet the universe → Cast / Schema / Bible ↓

---

## Quickstart (~5 minutes)
[5-line copy-pasteable setup, see Section 2]

---

## Articles
[Placeholder table — populated as articles ship in Phase 6+]

---

## Meet the cast
[14 named characters from bible/characters.md, name + role + 1-line trait,
table format. Links to bible/characters.md for full bios.]

---

## What's in this repo
[Directory map, one line per top-level dir, Section 4 details.]

---

## Reproducibility
[Three-bullet promise: every article links to specific SQL; generator is
deterministic with SEED=42; verify suite confirms expected state.]

---

## License & contributing
[See Section 5.]

---

## Who's behind this
[Author attribution, Section 5.]
```

**Section ordering rationale.** The article-reader's job ("find my article's source") and the impatient developer's job ("get the data running") sit immediately under the hero — both within scrollable reach without a click. The cold visitor reads the hero and either bounces or scrolls past Quickstart toward the cast / repo map / reproducibility, which collectively answer "what is this project, who's it for, how do I trust it." License and author live at the bottom because they're confirmation reads, not decision-driving content.

**Anchors.** The bullets in "What you can do here" use Markdown anchor links (`#articles`, `#quickstart`, `#meet-the-cast`) rather than relative paths. GitHub auto-generates these from H2 headings.

## 2. Quickstart block (verbatim)

The Quickstart section gets a 5-line copy-pasteable bash block plus a one-paragraph pointer to the longer walkthrough. Exact content:

````markdown
## Quickstart (~5 minutes)

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

You'll need: Postgres 15+ access (Supabase Cloud free tier works), Python
3.10+, `psql` on PATH, `SUPABASE_DB_URL` exported (or any `psql`-compatible
connection string). Total time: ~5 minutes from clone to verify.

> **Need more options?** Detailed setup including Supabase Cloud signup,
> Docker-local Postgres, troubleshooting, and the per-DDL-file walkthrough
> lives in [`supabase/README.md`](supabase/README.md).
````

`<REPO-URL>` is a placeholder the author replaces once the GitHub repo URL is known.

## 3. Voice & tone

Anchored to `style-guide.md`'s rules. README-specific rendering:

- **Person:** mostly third person ("BoltBasket is..."). First person only in "Who's behind this".
- **Sentence length:** short. Hero capped at 3 sentences. Section intros 1–2 sentences max. Lists do most of the work.
- **Numbers everywhere:** "210K rows", "12 deliberate imperfections", "14 named characters", "7 SQL files", "5-minute setup". Resists "lots of" / "extensive" / "comprehensive."
- **Indian context as default, not exotic:** "Bengaluru / Mumbai / Pune", "₹", "PMs and EMs at Series C startups." No need to over-explain quick-commerce or pincodes.
- **Banned phrases for the README** (extending `style-guide.md`):
  - "comprehensive", "robust", "powerful", "seamless", "leverage", "deep dive"
  - "in today's fast-paced world", "in the world of data"
  - "this project aims to..." (just say what it is)
- **Imperfection framing:** matter-of-fact. "The schema has 12 deliberate imperfections" — not "we cleverly designed this with realistic flaws." The reader figures out the cleverness; spelling it out kills the punch.

**Hero example** (sets the tone for the rest of the README):

> BoltBasket is a fictional Indian quick-commerce company. The Postgres schema in this repo has 12 deliberate imperfections — circular foreign keys, snapshot/log drift, JSONB key chaos, the kind of thing every Series C engineering org actually ships. Each article on Medium walks through one of them as a story: who broke it, who debugged it, what they shipped. The data is here so you can run the queries yourself.

## 4. Cross-link strategy + what lives where

The README is the front door but it's not where the depth lives. Each top-level directory has its own README serving its own audience.

### "What's in this repo" section content (verbatim)

```markdown
## What's in this repo

- **`bible/`** — the BoltBasket universe. Cast bios, story arcs, year-by-year
  timeline, fictional tech stack. Read these before drafting articles or if
  you want the lore.
- **`schema/`** — the data model on paper. Entities, relationships, and the
  catalog of 12 deliberate imperfections. Each imperfection has its own
  story-potential note.
- **`supabase/`** — the live reference database. DDL, smoke seed, generator
  for ~210K rows of bulk activity, marts (BigQuery-equivalent views), verify
  queries. Setup walkthrough lives in `supabase/README.md`.
- **`articles/`** — drafts and published pieces. (Empty until Phase 6.)
- **`queries/`** — standalone SQL files referenced by articles. Each file
  named `<article-slug>.sql` so the link from Medium → GitHub is obvious.
- **`docs/superpowers/`** — design specs and implementation plans for this
  project's own development.
```

### Article ↔ source link convention (locked in for Phase 6+)

Each article on Medium will link back to GitHub at three points:

1. **Top of article** → `README.md#articles` (index row so readers see siblings)
2. **Inline mid-article** → `queries/<article-slug>.sql` (the specific SQL the article walks through)
3. **End of article** → `bible/characters.md#<character-anchor>` for the named engineer in the article

The `queries/<article-slug>.sql` filename convention locks in starting Phase 6. Standardizing day-one prevents article #14 from drifting (e.g. `queries/article14.sql` vs. `queries/diwali-outage.sql`).

### File-tree depth and what the README does NOT enumerate

- **One level deep only.** The README lists `bible/` but not `bible/company.md`, `bible/characters.md`, etc. Sub-directory READMEs handle internal maps.
- **No imperfection enumeration.** README mentions "12 deliberate imperfections" exactly twice (hero + `schema/` directory map line). Both link to `schema/imperfections.md`. The README does not list the 12 by name — preserves the article reveal.
- **No architecture diagram.** The fictional AWS+GCP / BigQuery / Snowflake migration / MongoDB blind spot stack lives in `bible/stack.md`. The main README's pointer to that file is enough; the cold visitor doesn't need a stack diagram in the first 30 seconds.

### Cast section content

The "Meet the cast" section is a two-column table pulled from `bible/characters.md`. Columns: **Name + Role** | **One-line trait**. All 14 characters listed. Each name links to its anchor in `bible/characters.md` for full bio. Example two rows:

| Name + Role | One-line |
|---|---|
| **[Aryan Mehta](bible/characters.md#aryan-mehta)** — CEO | Founded BoltBasket in 2021. Tech-fluent enough to know what to ignore. |
| **[Priya Raghavan](bible/characters.md#priya-raghavan)** — Lead Data Engineer | Inherited the data platform without anyone calling it that. Diwali-outage protagonist. |

Implementation note: the one-liners come from `bible/characters.md`. If the bible doesn't already have a single-sentence summary per character, the implementation plan needs to either (a) extract from existing bios or (b) add a "tagline" field to the bible during this phase.

## 5. License + author attribution + contributing posture

### License (dual structure)

- **Code** (Python generator, SQL files, queries): **MIT License**.
- **Prose** (README, `articles/`, `bible/`, `schema/`, `decisions-log.md`): **CC BY 4.0**.
- One `LICENSE` file at root containing the MIT terms; a `LICENSE-prose.md` file containing CC BY 4.0; the README's License section names which paths are which.

Why dual: people copying SQL into their own projects shouldn't have attribution overhead (MIT). People quoting the bible / articles in their own writing should credit (CC BY 4.0). Both encourage sharing; neither blocks it.

### Author attribution

Section content (placeholders for the author to confirm/replace):

```markdown
## Who's behind this

**Built by Hardik Savaliya.** Articles on [Medium](TBD) · [LinkedIn](TBD).

This is a personal project. Opinions and mistakes are mine, not my
employer's.
```

The author name + the disclaimer ("not my employer's") are the only required content. Medium and LinkedIn URLs are placeholders the author fills in before publishing the repo. No employer mention in the body keeps the project clearly independent.

### Contributing posture

The README sets explicit non-OSS-community expectations so the author isn't trapped managing PR backlog:

```markdown
## Contributing

This is a writing project. The data and code exist to support specific
articles, so I'm not accepting feature PRs.

- **Bug reports welcome** — if a SQL query in an article doesn't reproduce,
  or a verify check fails on a clean install, please open an issue.
- **Typo fixes welcome as PRs.**
- **Other PRs will probably be politely closed** — please open an issue
  first if you want to propose something larger.
```

## 6. Definition of Done

Phase 5 is done when:

1. `README.md` exists at repo root with all 9 sections from Section 1, in the specified order, populated per Sections 2–5.
2. `LICENSE` (MIT) and `LICENSE-prose.md` (CC BY 4.0) files exist at root.
3. The article index table is present as a placeholder ("No articles published yet — Phase 6 starts soon.") so the structure is locked in for Phase 6+ to fill.
4. The "Meet the cast" table has all 14 characters with anchors that resolve to actual headings in `bible/characters.md` (or the bible has been updated to make these anchors exist).
5. All Markdown links in the README resolve — no 404s for relative paths.
6. The README's banned-phrases list (Section 3) is verified absent: a quick `grep -i` for "comprehensive\|robust\|powerful\|seamless\|leverage\|deep dive" returns zero matches.
7. The Quickstart block (Section 2) is copy-pasteable end-to-end and works against a fresh Supabase project (manual smoke test by the author).
8. A new `decisions-log.md` entry records: license choices, the article-link convention, the "no PRs" contributing posture.

## 7. Out of Scope for Phase 5

- **Sub-directory READMEs** beyond the existing ones in `supabase/`, `articles/`, `assets/`, `queries/`. Specifically: `bible/README.md` and `schema/README.md` are NOT created in Phase 5. The main README's "What's in this repo" map serves as their substitute. (Add later if the project grows enough to need them.)
- **Article index population.** Phase 5 ships the empty-table placeholder; Phase 6+ articles add their own rows.
- **Author bio expansion.** No author-page or about-me section beyond the 3-line attribution.
- **Repo-level metadata** (GitHub topics, About description, social preview image) — set via GitHub UI when the repo is published; not code-managed.
- **CI / lint / test badges** — no CI configured yet; badges added when CI ships.

## 8. After This

- Implementation plan via `superpowers:writing-plans` skill.
- Implementation work follows the plan.
- After README + LICENSE files are in place, push the repo to GitHub (Phase 5's natural endpoint).
- Phase 6 (Week 1 Post 1 draft) starts.
