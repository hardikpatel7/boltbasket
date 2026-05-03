# Template: Long-form Post

The flagship format. ~1,500–2,000 words. One per week.

Read `style-guide.md` and `bible/` before drafting. This template is the skeleton — the bible is the soul.

---

## Pre-draft checklist

Before writing, answer these in 1–2 sentences each. Don't skip — drafts written without these come out generic.

- **The concept:** What technical idea am I teaching? (e.g., "data lineage")
- **The protagonist:** Which BoltBasket character is suffering through this? (e.g., Priya at 2:47am)
- **The imperfection:** Which schema/lore imperfection makes this concept matter here? (See `schema/imperfections.md`)
- **The arc connection:** Does this hook into an existing story arc? (See `bible/story-arcs.md`)
- **The honest tradeoff:** What will I admit doesn't work / what we got wrong? (Non-negotiable section)
- **The specific number:** What plausible BoltBasket-scale number anchors the story?

---

## The 6-section skeleton

### Section 1 — The Mercato moment (~150 words)

A specific scene at BoltBasket. A named person, a moment in time, a concrete pain. Not "data lineage matters because…" — but "It was 2:47am on a Tuesday in October when Priya's phone buzzed for the fourth time…"

Rules:
- Open mid-action. The reader should feel they walked into a room where something is happening.
- Name the person and their role within the first three sentences.
- End the section with the question the reader now wants answered.

### Section 2 — Why the obvious fix doesn't work (~200 words)

Set up the failed attempts. What would most teams try? Why does it break in BoltBasket's real conditions?

Rules:
- Be specific about what was tried. "We tried adding tests" is weak. "Devika added 14 dbt tests; the broken pipeline still passed all of them because the tests checked schema, not freshness" is strong.
- This section earns the reader's attention for the actual concept that's coming.

### Section 3 — The actual concept, explained plainly (~600–800 words)

The teaching meat. Define the concept, show how it works, give one diagram.

Rules:
- Define the concept *before* you assume it. Don't write to the audience that already knows.
- One canonical diagram per article. Use a simple style — boxes, arrows, captions. No 30-component architecture porn.
- If using SQL or code, it must be runnable against the BoltBasket Supabase. Screenshot real query results.
- Use sub-headings sparingly. 2–3 max. They should read like signposts ("So what does lineage actually capture?"), not corporate slide titles ("Key Components of Data Lineage").

### Section 4 — How BoltBasket actually implemented it (~300 words)

Concrete return to the company. What did BoltBasket build/buy/decide? What did the rollout look like?

Rules:
- Be specific about tooling. "We used Airflow + a custom collector" beats "we built a solution."
- Include rough numbers: how long it took, how many people worked on it, what it cost in some unit.
- It's fine — encouraged — to admit it's still in progress. Real companies are always in progress.

### Section 5 — What you'd watch for / what we got wrong (~200 words)

The non-negotiable honesty section. The thing 95% of Medium posts skip.

Rules:
- At least two real downsides, limitations, or things you'd do differently.
- Don't bury this. Don't disclaim it away. Lean into it.
- This is the section that makes the difference between thought leadership and content marketing.

### Section 6 — TL;DR + what's next (~100 words)

Short recap. One-line tease for what's coming next.

Rules:
- TL;DR should not be the title restated. Capture the actual insight, in fewer words than the article.
- "Next" tease: a real next post, not a generic "subscribe for more."
- Link to the GitHub repo with code/schema/queries from this post.

---

## Title patterns that work

Avoid clickbait. Avoid generic. The title should hint at the story, not just the topic.

**Good:**
- "The Diwali Outage Taught Us What 'Production-Ready' Actually Means"
- "Why BoltBasket's 'Single Source of Truth' Was a Lie"
- "Materialized Views: The Tool That Saved Us Until It Cost Us ₹4 Crore"

**Avoid:**
- "Everything You Need to Know About Data Lineage" (generic)
- "10 Things About ETL" (listicle)
- "Data Lineage: A Comprehensive Guide" (textbook)

---

## End-of-article elements

Every long-form post ends with:

1. **GitHub link:** "Schema, queries, and seed data for this post: [repo URL]"
2. **Cross-link:** One link to a previous related BoltBasket article (when you have a body of work to link to). Build the reader's sense of universe.
3. **Connect line:** A genuine, non-cringe one-liner. e.g., "I write about data, AI, and the messy reality of building systems. If you build or use them, we'll get along."

Avoid: "Like and follow!", "Smash that subscribe button," "Comment your thoughts below!"

---

## Diagrams

Every long-form post should have *at least one* visual. Options in order of preference:

1. A simple block diagram (boxes + arrows) showing the system being explained.
2. A schema fragment showing the relevant tables (use `schema/` as ground truth).
3. A query result screenshot from the BoltBasket Supabase.
4. A timeline (for incidents or evolution stories).

Avoid: stock photos, cartoon-y AI-generated illustrations, generic Unsplash images.

---

## Voice reminders

- First person. "I" or "we." The author observing/consulting on BoltBasket, not an employee.
- Past tense for incidents ("Priya was paged…"). Present tense for systems ("BoltBasket runs Airflow…").
- Specific over general. Plausible over real. Honest over polished.

Now go check `style-guide.md` again for the banned words list, then draft.
