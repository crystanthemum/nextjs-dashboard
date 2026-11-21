# Priority G: back-end tests (top 5)

Back to [roadmap](../roadmap.md). Previous: [F](f-features.md).

Extends A3. Order: G2, G1, G3, G4, then G5 once the features exist. All use Vitest.

| ID | Tests | Effort | Status |
|---|---|---|---|
| G2 | Route handlers (`/version`, `/health`) | S | [ ] |
| G1 | Auth | S | [ ] |
| G3 | Server actions | M | [ ] |
| G4 | Repository against real Postgres | M | [ ] |
| G5 | Authorization (needs F6 / F10 / F11) | M | [ ] |

## One-time setup
- [ ] `vite-tsconfig-paths` as dev dependency, used in `vitest.config.ts` (so `@/` imports resolve)
- [ ] Mock the DB: `vi.mock` the shared `db.ts` (A2 makes this easy)
- [ ] Run in the `ci` job (`pnpm test`)

## G2. Route handlers [ ]
Why: the pipeline verify step depends on `/version`; no mocking, about 10 minutes.

- [ ] `GET()` in `app/version/route.ts`: set `process.env.VERSION = "abc123"`, expect 200 and `{ deployedVersion: "abc123" }`
- [ ] `GET()` in `app/health/route.ts` (A1): 200 and `{ status: "ok" }`
- [ ] Optional: assert `Cache-Control: no-store` (E9)

## G1. Auth [ ]
Why: login is the only protection for customer data, and `/version` already broke once through this redirect.

- [ ] `authorized` callback in `auth.config.ts`, called with `{ auth, request: { nextUrl: new URL("http://x/dashboard") } }`:
  - logged out + `/dashboard` is `false`
  - logged in + `/dashboard` is `true`
  - logged out + `/login` is `true`
  - logged in + `/login` redirects to `/dashboard`
- [ ] `authorize()` in `auth.ts`: valid credentials return the user; wrong password and unknown email return `null`; bad email format or password under 6 characters returns `null` without touching the DB (mock the SQL result; use a real `bcrypt.hash`)
- [ ] `proxy.ts` matcher excludes `version` and `health`: the matcher is a path pattern, so check with an end-to-end request to `/version` with no cookie expecting JSON, not a redirect

## G3. Server actions [ ]
Why: main write path and your only business rules; lets you refactor (B1) safely.

- [ ] Build `FormData` (`customerId`, `amount` "12.5", `status` "pending")
- [ ] Mock `next/cache`, `next/navigation`, `@/auth`, and the SQL client
- [ ] `createInvoice` cases:
  - amount 0 or negative gives `errors.amount`
  - missing customer gives `errors.customerId`
  - invalid status gives `errors.status`
  - valid input inserts the amount in **cents** (12.5 is 1250) and calls `redirect("/dashboard/invoices")`
  - DB error returns the message "issue creating invoice" instead of throwing
- [ ] Same pattern for `updateInvoice` and `deleteInvoice` (delete: a DB error throws)

## G4. Repository against real Postgres [ ]
Why: mocks cannot catch SQL mistakes (wrong column, bad join, pagination off-by-one).

- [ ] Make SSL configurable in `db.ts`: `ssl: process.env.DB_SSL === "off" ? false : "require"` (a plain Postgres container has no SSL)
- [ ] Test job `services:` block: `postgres:16`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, port 5432, `pg_isready` health check
- [ ] Job env: `POSTGRES_URL` to the container, `DB_SSL=off`
- [ ] Create tables and seed rows in `beforeAll` (migration files after C1)
- [ ] Test: invoice list search (name, email, amount, date, status), pagination (page 1, last, empty), counts, invoices/customers join
- [ ] Separate script `pnpm test:integration`

## G5. Authorization [ ]
Why: a hidden button is not security; the server check is. Nothing to test until the features exist.

- [ ] Export route (F6): no session returns 401
- [ ] Roles (F10): viewer calling create / update / delete is rejected on the server; admin succeeds
- [ ] Multi-user (F11): user A cannot read or edit user B's invoices (not found or 403)
- [ ] Test both layers: disabled button with a reason, and the server check

## After G1–G5
Service tests (after B1) and migration tests (after C1). Add `pnpm audit` to CI any time.
