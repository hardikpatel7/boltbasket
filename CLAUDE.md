# BoltBasket Content Project

This is a thought-leadership content project. The author is building a personal brand on Medium around **data management, modern data stack, and AI** — using a fictional Indian quick-commerce company called **BoltBasket** as a recurring narrative device to explain technical concepts through realistic, story-driven examples.

## What you (Claude) need to know in every session

1. **The author is the narrator.** When drafting articles, write in first person ("I", "we") as the author who is *consulting for / observing / thinking about* BoltBasket. Do not write as if you are an employee of BoltBasket. The author is positioning as a thought leader who uses BoltBasket as a teaching example — like Ben Thompson uses real companies, except ours is fictional and we control the details.

2. **BoltBasket is a fictional but internally consistent universe.** Read `bible/` before drafting any article. Every claim about BoltBasket must be consistent with the bible. If something isn't in the bible and you need to invent it, flag it in the draft so the author can decide whether to canonize it.

3. **Audience: Indian PMs, EMs, and early-career data engineers.** Write at the level where a PM understands the business stakes and a data engineer respects the technical depth. Never condescend to either. Indian context is default — pincodes, INR, Indian cities, Indian work culture references are welcome and expected.

4. **Voice rules are in `style-guide.md`.** Read it before drafting. Non-negotiable rules include: no corporate buzzwords, always name the engineer suffering through the problem, every post has at least one specific number, no AI-sounding intros ("In today's fast-paced world..." = instant deletion).

5. **Article structure is in `templates/`.** Long-form posts follow the 6-section skeleton. Field notes are shorter. Don't invent new structures without a reason — consistency builds reader habit.

## Project structure

```
boltbasket/
├── CLAUDE.md                    ← you are here
├── decisions-log.md             ← append-only changelog of major decisions
├── style-guide.md               ← voice rules, banned words
├── bible/                       ← the BoltBasket universe
│   ├── company.md              ← founding, business model, scale
│   ├── characters.md           ← named people across the company
│   ├── story-arcs.md           ← recurring narratives to reference
│   ├── timeline.md             ← Year 1 / 3 / 5 evolution
│   └── stack.md                ← tech stack with deliberate messiness
├── schema/                      ← data model design
│   ├── entities.md             ← conceptual entity list
│   ├── relationships.md        ← how entities connect
│   └── imperfections.md        ← deliberate legacy mistakes
├── supabase/                    ← reference database (Postgres on Supabase Cloud)
│   ├── README.md               ← setup instructions, three install options
│   ├── ddl/                    ← schema definitions, run in numeric order
│   ├── seed/                   ← smoke seed (Phase 4) + full generator (Phase 4b)
│   ├── verify/                 ← queries that confirm imperfections are intact
│   └── marts/                  ← analytical views (simulates the BigQuery layer)
├── templates/                   ← article skeletons
│   ├── long-form-post.md
│   └── field-note.md
├── articles/                    ← drafts and published pieces
├── queries/                     ← SQL queries used in articles
└── assets/                      ← diagrams, screenshots
```

## Operating principles

- **Lore before schema, schema before code, code before content.** Don't skip steps.
- **Imperfection is canon.** BoltBasket has legacy mistakes, political dysfunction, and bad decisions. That's the point. A clean fictional company teaches nothing.
- **One article = one specific incident at BoltBasket.** Not "data lineage in general" but "the time Priya couldn't trace why a metric broke."
- **Every article links to GitHub.** SQL, schema snippets, diagrams — reproducible.
- **Numbers must be plausible, not real.** ~50K SKUs is plausible. ~50M SKUs is not. When in doubt, anchor to realistic Indian quick-commerce scale (Zepto, Blinkit, Instamart at ~Series C).

## Current state

- Phase 1 (Bible) — **DONE.** Author has reviewed and approved.
- Phase 2 (Schema design on paper) — **DONE.** Author has reviewed and approved.
- Phase 3 (Scaffolding & templates) — **DONE.**
- Phase 4 (Supabase DDL + smoke seed) — **DONE.** Lives in `supabase/`. The DDL covers all 12 imperfections at the schema level; the smoke seed exercises imperfections #1, #2, #4, #5, #6, #12 with hand-written rows. Marts views and verification queries are also done.
- Phase 4b (Full ~300K-row Python seed generator) — **NEXT.** Will use `faker` + `numpy`, fixed random seed for reproducibility, anchor date 2025-10-15, 7 days of activity. Outputs SQL files that load into Supabase. Will fully exercise imperfections #3, #7, #8, #10, #11.
- Phase 5 (Public GitHub README) — NOT STARTED.
- Phase 6 (Week 1 Post 1 draft) — NOT STARTED.

## Database setup

The reference database lives on **Supabase Cloud** (not local Postgres). Connection details and project URL belong in environment variables, not in this repo.

When working on database tasks:
1. Ask the author for the Supabase connection string if you need to run queries directly.
2. For DDL changes, write SQL files in `supabase/ddl/` first, then ask the author to apply them via the Supabase SQL Editor.
3. For seed scripts, generate SQL output files locally that the author can paste/upload to Supabase.
4. Never embed credentials in any committed file. The author's Supabase project URL and anon/service keys stay in their local `.env` (which is gitignored).

The full setup walkthrough is in `supabase/README.md`. Skip the "local Docker" and "one-shot script" sections — Supabase Cloud is the chosen path.

## What to do when the author starts a new session

1. Read this file (you just did).
2. Read `decisions-log.md` — it's the append-only record of every decision made so far. Skim it to understand *why* things are the way they are.
3. Read `bible/company.md` and `bible/characters.md` for grounding in the universe.
4. If the task touches the database, also read `supabase/README.md` and `schema/imperfections.md` so you don't accidentally "fix" deliberate imperfections.
5. If drafting an article, also read `style-guide.md` and the relevant template.
6. Ask the author what they're working on today before producing anything substantive.

## Common tasks and where to start

- **"Validate the DDL on Supabase"** → `supabase/README.md` walks through it. Author runs the SQL via the Supabase SQL Editor. If verify queries return wrong counts, fix the DDL or smoke seed.
- **"Build Phase 4b (full seed generator)"** → New work. Python script in `supabase/seed/` that generates SQL files. Use `faker`, `numpy`. Fixed seed = 42. Anchor date = 2025-10-15. 7 days of activity. ~200K rows total.
- **"Draft an article"** → Read `style-guide.md`, the relevant template in `templates/`, and the bible files for whichever characters/arcs the article touches. Articles go in `articles/`.
- **"Add to the decisions log"** → After any meaningful decision (renaming a character, changing schema, picking a tool), append an entry to `decisions-log.md` with date, what changed, why.

## When in doubt

If a request would change something canonical (a character's name, a number in the bible, a schema choice), don't just do it — flag it to the author and update `decisions-log.md` after the change is approved. Consistency across articles is the whole game; ad-hoc edits break that.
