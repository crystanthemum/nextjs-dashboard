# Roadmap (start here)

One page. Tick a box when a task is done. Details for each task are in `tasks/`.
Effort: S = under 1 hour, M = a few hours, L = a weekend or more.
Contains no secrets, account IDs or URLs.

## Contents

| File | What is in it |
|---|---|
| [tasks/a-quick-wins.md](tasks/a-quick-wins.md) | A1–A4: health route, cleanup, first tests, hadolint, Dependabot |
| [tasks/b-layering.md](tasks/b-layering.md) | B1–B4: repository/service split, validation, logging, error wrapper |
| [tasks/c-delivery.md](tasks/c-delivery.md) | C1–C4: migrations, Taskfile, Trivy, approval gate |
| [tasks/d-hardening.md](tasks/d-hardening.md) | D1–D11: IAM, pinning, PR template, commit lint, docs |
| [tasks/e-ui.md](tasks/e-ui.md) | E1–E10: component kit, UI tests, states, a11y, performance |
| [tasks/f-features.md](tasks/f-features.md) | F1–F13: product features (small, medium, big) |
| [tasks/g-backend-tests.md](tasks/g-backend-tests.md) | G1–G5: the top 5 back-end tests |

Status: `[ ]` todo, `[~]` in progress, `[x]` done.

## Done

- [x] Delete `/query` route (public data leak)
- [x] Remove artificial `setTimeout` delays
- [x] A2: one shared `sql` connection in `app/lib/db.ts` (SQL is consolidated there; re-check that `auth` uses it too)

## The table

| ID | Task | Effort | Status |
|---|---|---|---|
| A1 | `/health` route | S | [ ] |
| A3 | Vitest + test step in CI | S | [ ] |
| A4 | hadolint + Dependabot | S | [ ] |
| G2 | Test the `/version` and `/health` routes | S | [ ] |
| G1 | Auth tests | S | [ ] |
| D1 | Least-privilege pipeline user | S | [ ] |
| D5 | PR template | S | [ ] |
| D6 | Commit message lint | S | [ ] |
| D7 | Protect `main` | S | [ ] |
| D10 | Comment tags | S | [ ] |
| D2 | Pin `latest` dependencies | S | [ ] |
| D3 | Housekeeping list | S | [ ] |
| B1 | Repository / service split | M | [ ] |
| G3 | Server action tests | M | [ ] |
| C1 | Migrations (`node-pg-migrate`) | M | [ ] |
| G4 | Real-Postgres repository tests | M | [ ] |
| B2 | zod at every boundary | S | [ ] |
| B3 | Request ID + JSON logs | M | [ ] |
| B4 | Error wrapper for route handlers | S | [ ] |
| C2 | Taskfile / Makefile | S | [ ] |
| C3 | Trivy image scan | S | [ ] |
| C4 | Approval gate (free) / staging (may cost) | S / L | [ ] |
| D8 | Lighthouse CI | M | [ ] |
| D9 | `docs/` folder + README rewrite | M | [ ] |
| D11 | Optional extras (flag, alarm) | M | [ ] |
| E1 | Form component kit | M | [ ] |
| E4 | Error / loading / not-found / empty states | M | [ ] |
| E2 | Component tests + coverage gate | M | [ ] |
| E2b | Layer rule enforced by lint | S | [ ] |
| E6 | Typecheck script + stronger pre-commit | S | [ ] |
| E9 | Caching + Lighthouse numbers | S | [ ] |
| E10 | Accessibility checks | M | [ ] |
| E3 | One form pattern | M | [ ] |
| E5 | Small hooks (URL params) | S | [ ] |
| E7 | Telemetry helper (optional) | S | [ ] |
| E8 | Storybook (optional) | M | [ ] |
| F1 | Sort and filter invoices | S | [ ] |
| F8 | Revenue chart from real data | M | [ ] |
| F2 | Overdue status (schema) | S | [ ] |
| F10 | Roles and permissions (schema) | L | [ ] |
| F9 | Audit trail (schema) | M | [ ] |
| G5 | Authorization tests | M | [ ] |
| F3 | Customer detail page | S | [ ] |
| F4 | Safer delete (schema) | S | [ ] |
| F5 | Customer CRUD | M | [ ] |
| F6 | Export to CSV | M | [ ] |
| F7 | Printable invoice | M | [ ] |
| F11 | Sign-up + multi-account (schema) | L | [ ] |
| F12 | Email reminders (check cost first) | L | [ ] |
| F13 | REST API + OpenAPI (schema-first, zod) | L | [ ] |

The table is already in a sensible order, top to bottom.

## Suggested order (short version)

1. A1, A3, A4, G2, G1 (an afternoon, no database needed)
2. D1, D2, D3, and the process wins D5, D6, D7, D10
3. B1, then G3 and C1, then G4
4. B2, B3, B4, then C2, C3, C4
5. UI: E1 and E4 first, then E2, E6, E9, E10, E3, E5
6. Features: F1, F8, F2, F10, F9. G5 once F10 exists.

## What you can honestly say on a CV after each

Only claim what you have built and seen working.

| Done | Line you can then claim |
|---|---|
| A3 | Added unit tests as a required pipeline gate |
| A4 + C3 | Pipeline scans secrets, Dockerfile and image vulnerabilities before deploy |
| B1 | Separated data access from business rules so logic is testable without a database |
| B3 | Structured JSON logging with per-request IDs, searchable in CloudWatch |
| C1 | Versioned database migrations run from the pipeline |
| C4 | Manual approval gate before production releases |
| E1 + E2 | Reusable form-component kit with component tests and a CI coverage threshold |
| E4 | Error, loading, empty and not-found states across all routes |
| E9 + E10 | Measured and improved Lighthouse scores; automated accessibility checks in CI (add real numbers) |
| F10 | Role-based access control enforced in the UI and on the server, with tests for both |
| F9 | Audit trail recording who changed which invoice |
| F8 | Fixed inconsistent figures by deriving chart and cards from the same source |
| D1 | Least-privilege IAM for the pipeline (only after you have verified it) |
