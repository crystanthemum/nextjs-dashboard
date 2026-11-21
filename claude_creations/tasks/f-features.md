# Priority F: product features

Back to [roadmap](../roadmap.md). Previous: [E](e-ui.md). Next: [G back-end tests](g-backend-tests.md).

App today: log in, dashboard cards, revenue chart, latest invoices, then list / search / paginate / create / edit / delete invoices, and a read-only customers table.

Rules
- **(schema)** = changes the database. Do after migrations (C1), not by hand on production.
- Add a test for each rule as you build it (A3, E2).
- Delete `/query` first (A2, done) before any export or API feature.

| ID | Feature | Size | Status |
|---|---|---|---|
| F1 | Sort and filter invoices | S | [ ] |
| F2 | Overdue status (schema) | S | [ ] |
| F3 | Customer detail page | S | [ ] |
| F4 | Safer delete (schema) | S | [ ] |
| F5 | Customer CRUD | M | [ ] |
| F6 | Export to CSV | M | [ ] |
| F7 | Printable invoice | M | [ ] |
| F8 | Revenue chart from real data | M | [ ] |
| F9 | Audit trail (schema) | M | [ ] |
| F10 | Roles and permissions (schema) | L | [ ] |
| F11 | Sign-up + multi-account (schema) | L | [ ] |
| F12 | Email reminders | L | [ ] |
| F13 | REST API + OpenAPI | L | [ ] |

Suggested order: F1, F8, F2, F10, F9 (UI win, consistent data, a migration, RBAC, audit trail).

## Small

**F1. Sort and filter invoices** [ ] Most visible win.
- [ ] Sort by amount, date, status; filter by status and date range
- [ ] Keep choices in the URL like `query` and `page`; validate with zod (B2)

**F2. Overdue status (schema)** [ ] First real migration, plus a business rule with a unit test.
- [ ] Add `due_date`; show "overdue" when pending and past due (rule lives in the service, B1)

**F3. Customer detail page** [ ] Uses a join.
- [ ] Click a customer: their invoices, total paid, total owed

**F4. Safer delete (schema)** [ ] Today `deleteInvoice` removes the row permanently.
- [ ] `deleted_at` column plus an "undo" message, or at least a confirmation step

## Medium

**F5. Customer CRUD** [ ] Proves the form kit (E1) is reusable; covers duplicate-email checks.
- [ ] Create, edit, delete customers

**F6. Export to CSV** [ ] Teaches streaming and auth on route handlers.
- [ ] Route handler streaming filtered invoices; requires login; wrapped in the error handler (B4)

**F7. Printable invoice** [ ] Real user value, almost no code.
- [ ] `/dashboard/invoices/[id]/print` with print-only CSS; use the browser's "Save as PDF"

**F8. Revenue chart from real data** [ ] Two numbers on one screen must come from the same rule.
- [ ] Compute monthly revenue from paid invoices instead of the `revenue` seed table

**F9. Audit trail (schema)** [ ] Standard in business software.
- [ ] `audit_log` table (who created / edited / deleted which invoice, when) and a simple view page
- [ ] Write entries in the service layer, not the page

## Big (pick one as a showcase)

**F10. Roles and permissions (schema)** [ ]
- [ ] `role` on `users` (admin, viewer); viewers cannot create / edit / delete
- [ ] Buttons disabled with a reason, and the server checks again
- [ ] Test both the UI state and the server check

**F11. Sign-up and multiple accounts (schema)** [ ]
- [ ] Registration with password rules; rate limit on login
- [ ] `user_id` so each user sees only their own data

**F12. Invoice email reminders** [ ]
- [ ] Check AWS SES cost, sandbox limits and domain verification first (you want to stay free)
- [ ] Reminder for overdue invoices

## F13. REST API with OpenAPI (schema-first with zod) [ ]
Why: UI and server cannot disagree about the API shape.

Your zod schemas play the role of a design file:

| Design-first world | Your stack |
|---|---|
| Design file | zod schemas for requests and responses |
| Generated `openapi` spec | `@asteasolutions/zod-to-openapi` (or `zod-openapi`) writes `openapi.json` |
| Generated UI client | `openapi-typescript` types + `openapi-fetch` |
| Generated server validation | the same zod schemas in the route handler |
| Never hand-edit generated files | same, plus a CI check |

- [ ] `app/lib/api/schemas.ts`: `InvoiceSchema`, `ListInvoicesQuery`, `CreateInvoiceBody`, `ErrorSchema`
- [ ] `app/api/invoices/route.ts` (`GET`, `POST`): parse with schemas (B2), call service (B1), wrap with error handler (B4), require login
- [ ] Register routes with the zod-to-openapi library; `scripts/generate-openapi.ts` (uses `tsx`) writes `openapi.json`
- [ ] `openapi-typescript openapi.json -o app/lib/api/generated.d.ts`; `pnpm api:generate` runs both
- [ ] Use `openapi-fetch` in one client component (e.g. live-search table)
- [ ] CI: run `pnpm api:generate`, fail on `git diff --exit-code`
- [ ] Contract test in Vitest: call the handler, validate the response schema
- [ ] Read the library README first: you are on zod 3 and OpenAPI libraries differ by zod version

Limits
- Server actions have no URL, so they never appear in the spec; only route handlers do
- zod is the source of truth (schema-first), not a hand-written spec
