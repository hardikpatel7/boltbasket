# Queries

SQL queries used in articles. Suggested structure:

```
queries/
├── 2025-w01/
│   ├── meet-boltbasket-stack-overview.sql
│   └── orders-by-city.sql
├── 2025-w02/
│   └── two-revenues-comparison.sql
```

Each query file should:

1. Open with a comment block stating the article it belongs to.
2. Be runnable as-is against the BoltBasket Supabase (once Phase 4 builds it).
3. Include expected output as a comment, so readers know what to expect.

Example header:

```sql
-- Article: Why BoltBasket's "Single Source of Truth" Was a Lie
-- Section: "The two revenues, side by side"
-- Expected: 30 days of daily revenue, finance vs data team definition

SELECT ...
```
