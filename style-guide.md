# Style Guide

This is the voice of the BoltBasket content project. Read this before drafting any article.

## Voice in one line

**A senior practitioner explaining hard things plainly to peers, using stories instead of jargon.** Not a teacher. Not a guru. Not a vendor. Just someone who's been in the room when things broke.

## The three principles

### 1. Show the engineer suffering

Every concept enters the article through a person. Not "data lineage is important because…" — but "Priya got paged at 2:47am on a Tuesday because the daily revenue dashboard showed ₹0…"

Named characters > abstract systems. Specificity > generality. Tuesday at 2:47am > "one night."

### 2. Numbers, always

Every article has at least one specific number. Not "many SKUs" — "47,000 SKUs." Not "high traffic" — "12,000 orders/min during the 7pm peak." Numbers signal you've actually seen the system. They don't have to be real, but they must be plausible (see `bible/company.md` for canonical scale).

### 3. The honest tradeoff section is non-negotiable

Every article has a "what you'd watch for" or "what we got wrong" section. This is the part 95% of Medium posts skip — and it's the thing that separates thought leadership from content marketing. If you can't articulate the downside, you don't understand the topic well enough to write about it.

## Banned words and phrases

These trigger an immediate revision request. Find a better way to say it.

- **leverage** (use: use, rely on, build on)
- **utilize** (use: use)
- **synergy / synergistic** (just don't)
- **best-in-class / world-class / cutting-edge / state-of-the-art**
- **revolutionize / disrupt / unlock / supercharge / streamline**
- **In today's fast-paced world** / **In the era of [X]** (any opener like this = delete)
- **At the end of the day** (used as transition)
- **It's worth noting that** (just say the thing)
- **Game-changer / game-changing**
- **Robust** (be specific: durable? fault-tolerant? high-throughput?)
- **Seamlessly** (rarely true; if true, prove it)
- **Empower / empowering**
- **Journey** (used metaphorically — "data journey" is forbidden)
- **Holistic**
- **Solution** (when you mean "thing" or "system")
- **Best practices** (whose? cite or rephrase)

## Banned structural moves

- Opening with a dictionary definition
- Opening with a quote from Einstein, Bezos, or any LinkedIn-famous person
- "Let me tell you a story" (just tell it)
- Bullet lists where prose would do (lists are for genuinely parallel items, not lazy formatting)
- Numbered steps when the process isn't actually sequential
- "TL;DR: [restating the title]"
- Ending with "What's your experience? Comment below!" (find a better engagement hook)
- Em-dash overuse — like this — when a comma or period would do (use sparingly, with intent)

## Preferred moves

- Open with a moment, not a thesis. The thesis comes after the reader cares.
- Name the person before you describe the system.
- Use Indian context naturally: Diwali traffic spikes, Bangalore vs Mumbai office tension, Kannada/Hindi/English code-mixing in Slack messages, real cities and pincodes.
- INR, not USD, unless explicitly comparing globally. Use ₹ symbol or "lakh"/"crore" naturally.
- Specific tools by name: Snowflake, dbt, Airflow, Kafka, Looker, Superset, Postgres, ClickHouse. Generic terms like "the warehouse" only after first naming.
- Diagrams over walls of text for any system with >3 components.
- Code and SQL as screenshots from the actual BoltBasket Supabase, not pseudo-code.

## Length conventions

- **Long-form post:** 1,500–2,000 words. The flagship format. One per week.
- **Field note:** 600–900 words. One sharp idea, fast read. One per week.
- Never pad to hit a word count. If a long-form draft comes in at 1,200 words and feels complete, ship it as a field note instead.

## Indian English conventions

- "Crore" and "lakh" are fine and preferred for INR amounts above ~10 lakh.
- "Jugaad" is allowed *once per article maximum* and only when genuinely meant.
- Don't write fake Hinglish. If a character would say "yaar" in Slack, fine. Don't sprinkle it for flavor.
- Spelling: prefer Indian/British conventions (organisation, optimisation, colour) but be consistent within a piece.

## Naming conventions for examples

- Engineers and PMs: Indian first names, surname optional. Mix of regions (Tamil, Punjabi, Gujarati, Bengali, etc.) — see `bible/characters.md`.
- Don't reuse the same character for every story. Rotate.
- Customers in examples: use first names + last initial ("Rohit S.", "Meera T."). Don't make up full personal data.
- Pincodes: use real Indian pincodes (560001 = Bangalore, 400001 = Mumbai, etc.)
- SKU codes: format `BB-XXXXX` (e.g., `BB-04721` for a specific product)

## How to handle uncertainty

If you're drafting and you're unsure whether something is canon:
- Check the bible files first.
- If not found, write `[CANON?: <your invented detail>]` inline.
- Don't silently invent. The author needs to decide what gets canonized.
