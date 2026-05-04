# BoltBasket

BoltBasket is a fictional Indian quick-commerce company. The Postgres schema in this repo has 12 deliberate imperfections — circular foreign keys, snapshot/log drift, JSONB key chaos, the kind of thing every Series C engineering org actually ships. Each article on [Medium](TBD) walks through one of them as a story: who broke it, who debugged it, what they shipped. The data is here so you can run the queries yourself.

## What you can do here

- 📖 [**Read the articles**](#articles) — story-driven walk-throughs of one imperfection at a time, set inside BoltBasket
- 🐘 [**Run the database yourself**](#quickstart) — ~5 minutes from clone to a live Postgres with 210K rows of plausible Indian quick-commerce data
- 🎭 [**Meet the universe**](#meet-the-cast) — 14 named engineers and PMs you'll see recur across articles

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

---

## Articles

_No articles published yet — Phase 6 starts soon. Once they ship, each row in the table below maps article → key SQL files / verify queries the article references._

| # | Title | Concept | Imperfection | SQL / queries |
|---|---|---|---|---|

---

## Meet the cast

| Name & Role | One-liner |
|---|---|
| **[Aryan Mehta](bible/characters.md#aryan-mehta)** — CEO | Reads dashboards constantly. Slacks a data engineer at 11pm when a number looks off. |
| **[Sanya Kapoor](bible/characters.md#sanya-kapoor)** — COO | Mumbai-based operations brain. Voice of dark store managers who don't trust the data. |
| **[Vikram Bansal](bible/characters.md#vikram-bansal)** — CTO | Made the 2021 AWS bet. Will jump into a midnight Slack thread to debug something interesting. |
| **[Naveen Krishnan](bible/characters.md#naveen-krishnan)** — CFO | Old-school finance. Wants one source of truth; finds three. Brings up cross-cloud egress costs in QBRs. |
| **[Priya Raghavan](bible/characters.md#priya-raghavan)** — Lead Data Engineer | Pragmatist. Protagonist of every 2am incident. Has a 4-page `things-i-said-i-would-fix.md` and counting. |
| **[Noel Thomas](bible/characters.md#noel-thomas)** — EM, Data | Translates data team chaos to leadership. "Let me think overnight" becomes a 6-page Notion doc by morning. |
| **[Devika Rao](bible/characters.md#devika-rao)** — Senior Data Engineer | Wrote the dbt style guide. Owns the Debezium → Kafka → BigQuery pipeline that runs on hopes and prayers. |
| **[Arjun Pillai](bible/characters.md#arjun-pillai)** — Data Engineer | Newest hire. The audience surrogate — when he asks "why are we doing it this way?" it's the reader asking. |
| **[Meera Joshi](bible/characters.md#meera-joshi)** — Analytics Engineer | Owns the dbt mart layer. The patient explainer in metric-definition disagreements. |
| **[Siddharth (Sid) Patel](bible/characters.md#siddharth-sid-patel)** — Sr PM, CX | Sharp, opinionated, has Aryan's ear. Famously confrontational with Noel about engineering timelines. |
| **[Rohan Desai](bible/characters.md#rohan-desai)** — PM, Growth | Experimentation-obsessed. Runs ~30 A/B tests a quarter. Lives in Amplitude. |
| **[Anjali Singh](bible/characters.md#anjali-singh)** — PM, Supply & Inventory | Bridge between Bengaluru tech and Mumbai ops. Her features often span both AWS and GCP sides. |
| **[Faisal Khan](bible/characters.md#faisal-khan)** — VP, Dark Store Operations | Doesn't write SQL but knows what every column should mean. Defender of the Mumbai Excels. |
| **[Pooja Nair](bible/characters.md#pooja-nair)** — Director, Ad Sales | Hired in 2025 to build the ad business. Source of the multi-model attribution debate (#10). |

Full bios in [`bible/characters.md`](bible/characters.md).

---

## What's in this repo

- **[`bible/`](bible/)** — the BoltBasket universe. Cast bios, story arcs, year-by-year timeline, fictional tech stack. Read these before drafting articles or if you want the lore.
- **[`schema/`](schema/)** — the data model on paper. Entities, relationships, and the catalog of [12 deliberate imperfections](schema/imperfections.md). Each imperfection has its own story-potential note.
- **[`supabase/`](supabase/)** — the live reference database. DDL, smoke seed, generator for ~210K rows of bulk activity, marts (BigQuery-equivalent views), verify queries. Setup walkthrough lives in [`supabase/README.md`](supabase/README.md).
- **[`articles/`](articles/)** — drafts and published pieces. (Empty until Phase 6.)
- **[`queries/`](queries/)** — standalone SQL files referenced by articles. Each file named `<article-slug>.sql` so the link from Medium → GitHub is obvious.
- **[`docs/superpowers/`](docs/superpowers/)** — design specs and implementation plans for this project's own development.

---

## Reproducibility

- **Every article links to the specific SQL it walks through.** Article on Medium → `queries/<article-slug>.sql` here. Open it, run it, get the same answer the article does.
- **The bulk seed generator is deterministic.** Fixed `SEED=42`. Re-running `python generate.py` produces byte-identical SQL — your data matches the data the article was written against, row for row.
- **Verify your install** with `psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql`. The script reports counts for all 11 imperfections that are demonstrable in relational data (#1–#8, #10–#12; #9 lives in MongoDB conceptually).

---

## License & contributing

**Two licenses, by file type:**

- **Code** (Python generator, SQL files, queries): [MIT](LICENSE).
- **Prose** (README, `articles/`, `bible/`, `schema/`, `decisions-log.md`): [CC BY 4.0](LICENSE-prose.md).

**About contributions:** This is a writing project. The data and code exist to support specific articles, so I'm not accepting feature PRs.

- **Bug reports welcome** — if a SQL query in an article doesn't reproduce, or a verify check fails on a clean install, please open an issue.
- **Typo fixes welcome as PRs.**
- **Other PRs will probably be politely closed** — please open an issue first if you want to propose something larger.

---

## Who's behind this

**Built by Hardik Savaliya.** Articles on [Medium](TBD) · [LinkedIn](TBD).

This is a personal project. Opinions and mistakes are mine, not my employer's.
