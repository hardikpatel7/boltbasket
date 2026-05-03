# BoltBasket — Characters

These are the named people who recur across articles. Use them. Don't invent new ones unless absolutely needed. When you do, add them here so they become canon.

Rotate which character is the protagonist of each article — readers should feel they're following a small ensemble, not a single hero.

---

## Leadership

### Aryan Mehta
- **Role:** CEO and Co-founder
- **Background:** ex-product at a Bangalore-based foodtech unicorn (think the kind of person who shipped supply-side tooling at Swiggy/Zomato). Operations brain. Lives in Indiranagar, Bangalore.
- **Personality:** Visionary, intense, demanding. Reads dashboards constantly. Will Slack a data engineer at 11pm to ask why a number changed. Trusts data more than instinct, which is unusual for a CEO.
- **Recurring role:** The escalation point. When a metric is wrong, Aryan eventually finds out and someone has to explain.
- **Quirks:** All-hands have a running gag — he ends every one with "and one more thing — we ship next week," even when nothing is shipping.

### Sanya Kapoor
- **Role:** COO and Co-founder
- **Background:** ex-global QSR chain's India team, joined 6 months after founding. Heads Mumbai office.
- **Personality:** Operations brain. Does not suffer fools. Has been known to terminate ineffective dark store managers within their first 30 days. The reason BoltBasket's Mumbai operations exist as a serious thing.
- **Recurring role:** The voice of "the data the tech team produces is wrong, and here's why my dark store managers don't trust it."

### Vikram Bansal
- **Role:** CTO and Co-founder
- **Background:** ex-staff engineer at a US payments company, returned to India in 2020. Built the original BoltBasket app and inventory system in 9 weeks. Reluctant manager, prefers writing Go to running 1:1s.
- **Personality:** Technical depth, low patience for process. Will jump into a Slack thread to debug something at midnight if interested. Doesn't enjoy being a manager but is good at it when he focuses.
- **Recurring role:** The voice of "why are we still doing this the old way." Often the one who unblocks decisions stuck in committee. Made the original AWS choice in 2021 that the company is still living with.
- **Quirks:** Code reviews are 80% praise and 20% absolutely brutal architecture critique buried at the bottom.

### Naveen Krishnan
- **Role:** CFO
- **Tenure:** Joined post-Series B from a listed company.
- **Personality:** Old-school finance. Reconciles every number. Trusts spreadsheets more than dashboards.
- **Recurring role:** The voice demanding "single source of truth" — because his Excel says one thing and the BI tool says another. Also the one bringing up cross-cloud egress costs in quarterly reviews.

---

## Data & Engineering Team (Bangalore HQ)

### Priya Raghavan
- **Role:** Lead Data Engineer
- **Tenure:** Joined late 2022 as Senior, promoted to Lead in early 2024.
- **Background:** ex-data infra at a Bangalore B2B SaaS company. Before that, two years at a US fintech (returned during COVID).
- **Personality:** Pragmatist. Skeptical of hype. Will rewrite a junior's PR with a one-line comment that says "much simpler — see attached." Owns the warehouse layer end-to-end. Gets paged more than anyone else.
- **Recurring role:** The protagonist of incidents. When something breaks at 2am, it's Priya. When a metric is wrong, Priya is the one who has to explain why.
- **Quirks:** Drinks too much filter coffee. Has a running document called `things-i-said-i-would-fix.md` that's now 4 pages long.

### Noel Thomas
- **Role:** Engineering Manager, Data Platform
- **Tenure:** Joined Series B (mid-2023) as EM. Owns Priya, two senior data engineers, and four mid/junior engineers.
- **Background:** ex-staff engineer at a US adtech company. First-time manager. Still occasionally writes production code (which Priya quietly fixes).
- **Personality:** Deliberative. Writes long Notion docs before meetings. Cares deeply about team morale and gets visibly stressed during incidents.
- **Recurring role:** The one who has to translate data team chaos to leadership. Often the antagonist-from-the-team-POV when he pushes back on shipping fast.
- **Quirks:** Notorious for the "let me think about it overnight" response that becomes a 6-page architecture doc by morning.

### Devika Rao
- **Role:** Senior Data Engineer
- **Tenure:** Joined early 2024 from a payments unicorn.
- **Personality:** Detail-obsessed. Wrote BoltBasket's first dbt style guide. Has strong opinions about table naming conventions. Owns the Debezium → Kafka → BigQuery CDC pipeline (her pet project that actually ships value despite being held together with hopes and prayers).
- **Recurring role:** Often the foil to Priya — disagrees on philosophical engineering choices but in a respectful, productive way. The driver of the cross-cloud bridge stories.

### Arjun Pillai
- **Role:** Data Engineer (early career, ~2 years experience)
- **Tenure:** Joined late 2024, his second job.
- **Personality:** Eager, fast, slightly under-confident. Asks good questions. Sometimes ships things slightly broken because he doesn't know what to test for.
- **Recurring role:** The audience surrogate for early-career readers. Many articles can be framed around something Arjun is learning. When he asks "why are we doing it this way?" it's the reader asking.

### Meera Joshi
- **Role:** Analytics Engineer
- **Tenure:** Joined 2024.
- **Personality:** Bridges data engineering and analytics. Owns the dbt project's mart layer. Patient explainer.
- **Recurring role:** The semantic layer / metrics layer protagonist. Stories about metric definitions usually feature Meera.

---

## Product Team

### Siddharth (Sid) Patel
- **Role:** Senior Product Manager, Customer Experience
- **Tenure:** Joined Series B from a Bangalore D2C company.
- **Personality:** Sharp, fast, opinionated. Has a famously confrontational relationship with Noel over engineering timelines. Has CEO Aryan's ear.
- **Recurring role:** The PM perspective. The one who pushes for faster shipping and is sometimes right and sometimes wrong about it. Drives a lot of the "metrics disagreement" stories.
- **In Slack and informal contexts, refer to him as "Sid."** Use "Siddharth" in formal mentions or first introductions; "Sid" elsewhere.

### Rohan Desai
- **Role:** Product Manager, Growth
- **Tenure:** Joined late 2023.
- **Personality:** Experimentation-obsessed. Runs ~30 A/B tests a quarter. Lives in Amplitude.
- **Recurring role:** Stories about experimentation infrastructure, attribution, and metric instrumentation.

### Anjali Singh
- **Role:** PM, Supply & Inventory (joint Bangalore-Mumbai role)
- **Personality:** The bridge between Bangalore tech and Mumbai ops. Travels constantly between the two offices. Patient, diplomatic, the person who actually makes cross-office decisions stick.
- **Recurring role:** Stories about inventory data, dark store ops, the fault-line between tech and ops cultures. Also stories about the cross-cloud bridge — Anjali's features often need data from both AWS and GCP sides.

---

## Operations & Commercial Team (Mumbai HQ)

### Faisal Khan
- **Role:** VP, Dark Store Operations
- **Personality:** Veteran of QSR operations. Doesn't write SQL but knows what every column should mean. Quietly the most important non-tech consumer of data team output.
- **Recurring role:** The customer of the analytics function. Stories about misaligned definitions, broken dashboards, ops trust in data. The defender of the Mumbai Excels (Arc 3).

### Pooja Nair
- **Role:** Director, Ad Sales
- **Tenure:** Joined Q2 2025 specifically to build out the new advertising business.
- **Recurring role:** The driver of new data requirements as the ad business ramps. Brand campaigns need attribution, audience segmentation, reporting — all things the data team is scrambling to support. Source of the multi-model attribution debate (Imperfection #10).

---

## Customers (Recurring Examples)

When a story needs a customer:
- **Rohit S.** — A Bangalore IT professional, frequent ordering, BoltBasket Plus subscriber.
- **Ritika T.** — A Mumbai household manager, weekly large orders.
- **Aakash V.** — A Pune student, small frequent orders, price sensitive.

Don't invent more unless the story needs it.

---

## Adding a new character

If your article genuinely needs a new named person:

1. Check if an existing character could fill the role (90% of the time, yes).
2. If truly new, add them here with: name, role, tenure, one-line personality, and the article they first appeared in.
3. Try to keep the cast under ~16 named characters total. Beyond that, readers can't track them.

---
