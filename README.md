# BoltBasket Content Project

A thought-leadership content project on data, AI, and business — built around a fictional Indian quick-commerce company called **BoltBasket** that serves as a recurring narrative device across all articles.

## Why this exists

Most technical writing on Medium uses generic, abstract examples. This project does the opposite: every concept is taught through a single, internally consistent fictional company that readers come to know — its people, its problems, its history. By article #20, "Priya," "Noel," and "the Diwali outage" are familiar to readers. That familiarity is the difference between content that gets read and content that gets remembered.

## How to use this project

If you're the author: read `CLAUDE.md`, then `bible/company.md`, then `bible/characters.md`. That's enough grounding to draft your first article.

If you're Claude (any session): `CLAUDE.md` at the root tells you what to do.

## Folder map

- **`CLAUDE.md`** — master context, loaded by Claude in every session
- **`style-guide.md`** — voice rules, banned words, conventions
- **`bible/`** — the BoltBasket universe (company, characters, story arcs, timeline, stack)
- **`schema/`** — conceptual data model design (entities, relationships, deliberate imperfections)
- **`templates/`** — article skeletons (long-form and field note)
- **`articles/`** — your drafts and published pieces will live here
- **`queries/`** — SQL queries used in articles
- **`assets/`** — diagrams, screenshots, images

## Build phases

1. **Phase 1 — The Bible** (DONE) — company lore, characters, story arcs, timeline, stack
2. **Phase 2 — Schema design on paper** (DONE) — entities, relationships, imperfections catalog
3. **Phase 3 — Project scaffolding** (DONE) — `CLAUDE.md`, style guide, templates, folder structure
4. **Phase 4 — Supabase schema + seed data** (NEXT) — actual SQL DDL, seed scripts, deliberate messiness preserved
5. **Phase 5 — Public GitHub README** (AFTER PHASE 4) — the introduction to BoltBasket that lives on GitHub

## What to do next

1. **Read the bible.** Spend 30 minutes with `bible/company.md`, `bible/characters.md`, and at least skim the others. You'll have opinions. Good — that's the point.
2. **Note your changes.** Mark anything that doesn't fit your taste (a character's vibe, a number that feels wrong, a story arc you'd rather kill). Easier to change now than after Supabase is built.
3. **Confirm or push back on the schema design.** Read `schema/entities.md`, `schema/relationships.md`, and `schema/imperfections.md`. Anything missing? Anything overdone?
4. **Then:** ping me to start Phase 4 (Supabase build).

After Phase 4, we draft Week 1 Post 1.

## A note on the lore

The BoltBasket universe is meant to be a *living* document. As you write articles, new details will emerge — a story arc resolves, a character develops, a tooling decision gets made. Update the bible files as you go. Future-you (and future-Claude) will need them to stay consistent.
