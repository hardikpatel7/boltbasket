# BoltBasket — Company Bible

This is the canonical source of truth for everything about BoltBasket. When in doubt, this file wins.

## One-line pitch

BoltBasket is a Series C Indian quick-commerce company delivering groceries, daily essentials, and meal kits to urban households in 10–15 minutes through a network of dark stores.

## Founding story

Founded in **August 2021** in Bangalore by:

- **Aryan Mehta** — CEO, ex-product at a Bangalore-based foodtech unicorn (think the kind of person who shipped supply-side tooling at Swiggy/Zomato). Operations brain. Lives in Indiranagar.
- **Vikram Bansal** — CTO, ex-staff engineer at a US payments company, returned to India in 2020. Built the original BoltBasket app and inventory system in 9 weeks. Reluctant manager, prefers writing Go to running 1:1s.

The third co-founder, **Sanya Kapoor**, joined six months later as **COO** from a global QSR chain's India team. She owns the dark store network and is the reason BoltBasket's Mumbai operations exist as a serious thing.

The founding insight wasn't speed — Zepto already had that. It was **mid-market dark stores** in tier-1 cities where Zepto/Blinkit underserve: 2km from elite zones, serving the actually-large demographic of mid-income households who care more about price + reliability than 10-minute delivery. BoltBasket promises 15 minutes (often delivers in 12) at prices ~8% below Zepto on equivalent SKUs.

## Current scale (canonical numbers — use these)

As of the canonical "now" of the BoltBasket universe (treat as late 2025):

- **~$200M raised** across Seed → Series C. Last round: $90M Series C in March 2025, led by a Singapore-based growth fund, with participation from existing investors.
- **~1,500 employees** total (including ~900 dark store staff, ~400 riders on payroll + ~3,000 gig riders, ~200 corporate).
- **15 cities** of operation — full list in `timeline.md`. Heavy in: Bangalore, Mumbai, Pune, Hyderabad, Delhi NCR, Chennai. Lighter footprint: Ahmedabad, Kolkata, Jaipur, Chandigarh, Coimbatore, Kochi, Indore, Nagpur, Lucknow.
- **~280 dark stores** across all cities. Average store: ~2,500 sq ft, ~6,500 SKUs stocked locally, services ~3km radius.
- **~4.2 million** Monthly Active Users.
- **~1.1 million** orders per day at steady state. Peaks of ~1.6 million on weekends and ~2.4 million during major events (Diwali week, IPL finals, monsoon onset days).
- **~47,000 SKUs** in the master catalog (not all stocked everywhere).
- **Average order value: ₹385.** Median: ₹290. Heavy long-tail of large weekly grocery orders pushing the mean.
- **Median delivery time: 12 minutes 40 seconds.** P90: 18 minutes. Their public marketing claim is "in 15 minutes or less" with an asterisk.
- **Unit economics:** contribution-positive in 9 of 15 cities. Bangalore and Pune are profitable at the city level. Mumbai is breakeven. Delhi NCR and Hyderabad are still losing money per order, blamed on aggressive Zepto/Blinkit competition.

## Business model

**Revenue streams:**
1. **Product margin** (primary) — buy from brands/distributors, sell to consumers. ~22% gross margin on grocery, ~35% on private label, ~12% on staples.
2. **Delivery fee** — ₹15–₹30 depending on order size and time. Waived above ₹199.
3. **BoltBasket Plus** (subscription) — ₹199/quarter for free delivery + early access to deals. Launched late 2023. ~340K subscribers.
4. **Brand advertising** (growing) — placement in app, sponsored search, push notification slots. ~₹4 crore/month run rate, growing fast. This is where the data team's attention is increasingly going.
5. **Private label** ("BoltBasket Daily") — staples, snacks, household. ~14% of GMV, much higher margin.

**Cost structure (rough):**
- ~75% Cost of Goods Sold
- ~8% rider payments
- ~6% dark store operations (rent, utilities, staff)
- ~5% tech & data
- ~3% marketing
- ~3% G&A and corporate

## Two HQs (this matters for content)

**Bangalore office (Indiranagar)** — ~180 people. Tech, product, data, design, growth, finance. Aryan and Vikram both based here. This is where the data team lives. Vibe: WeWork-style office, dogs allowed, quarterly hackathons, lots of Telegram/Slack debate about whether to standardize on AWS or push more workloads to GCP.

**Mumbai office (BKC)** — ~140 people. Operations, supply chain, dark store leadership, key account management with brands, ad sales, customer support leadership. Sanya based here. Vibe: more formal, more sales-y, more spreadsheets, less hoodies, more "let's grab a coffee at Trident."

**The political tension between the two offices is canonical and should be mined for content.** The Bangalore tech team builds tools the Mumbai ops team doesn't adopt. The Mumbai team has Excel-based parallel systems for everything. Quarterly "alignment offsites" are a recurring story device.

## Key business metrics the company tracks

These show up across articles. Get the names right.

- **GMV** (Gross Merchandise Value) — total order value before discounts
- **NMV** (Net Merchandise Value) — after discounts and returns
- **Take rate** — net revenue / GMV
- **CM1** (Contribution Margin 1) — order-level margin after COGS and direct delivery
- **CM2** — after dark store ops cost
- **CM3** — after marketing and tech allocation
- **TTD** (Time To Deliver) — order placement → customer hand-off
- **TTP** (Time To Pick) — order placement → rider leaves dark store
- **First Order Conversion** — install → first paid order
- **D30 retention** — % of users ordering again within 30 days
- **Stockout rate** — % of orders where at least one SKU was substituted/refunded
- **Dark store fill rate** — % of demand met without inter-store transfer

## The competitive landscape (in BoltBasket's worldview)

- **Zepto** — the speed obsessive. BoltBasket positions as more reliable, less burn-y.
- **Blinkit** (Zomato) — the deepest pockets. BoltBasket avoids head-on price wars in cities where Blinkit dominates.
- **Instamart** (Swiggy) — bundled with food delivery. BoltBasket's hardest competitor in tier-1.
- **BigBasket** (Tata) — slower (next-day) but trusted for large weekly orders. Different segment, but encroaching.
- **DMart Ready** — price-led, slower. Threat in price-sensitive zones.

## Public narrative vs. internal reality

What BoltBasket says publicly:
> "Profitability path by FY27. Differentiated through dark store density and private label."

What's true internally (and the kind of nuance you can mine for content):
- Profitability is realistic in 8–10 cities. The other 5 are strategic bets that may or may not pay off.
- Private label margin is real but cannibalises higher-margin brand sales.
- The data team is understaffed for the ad business they're trying to build.
- BoltBasket Plus is loss-making per subscriber but increases retention dramatically — leadership debates whether to push it.

## Cultural texture (use sparingly for color)

- Internal Slack channel `#metrics-debates` is famous for being where Sid (Sr PM, CX) and Noel (EM) argue weekly about which definition of "active user" is correct.
- Aryan's all-hands have a running gag: he ends every one with "and one more thing — we ship next week," even when nothing is shipping.
- Vikram is known for code reviews that are 80% praise and 20% absolutely brutal architecture critique buried at the bottom.
- The Mumbai office has a tradition of vada pav lunch every Friday that the Bangalore office grumbles about not getting an equivalent for.
- Diwali week is the company's biggest moment of the year — both for revenue and for things-going-wrong stories.
