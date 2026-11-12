# Priority E: UI

Back to [roadmap](../roadmap.md). Previous: [D](d-hardening.md). Next: [F features](f-features.md).

Copy the **habits** of large React codebases, not their heavy tooling.

| ID | Task | Effort | Status |
|---|---|---|---|
| E1 | Form component kit | M | [ ] |
| E2 | Component tests + coverage gate | M | [ ] |
| E2b | Layer rule enforced by lint | S | [ ] |
| E3 | One form pattern | M | [ ] |
| E4 | Error / loading / not-found / empty states | M | [ ] |
| E5 | Small hooks | S | [ ] |
| E6 | Typecheck + stronger pre-commit | S | [ ] |
| E7 | Telemetry helper (optional) | S | [ ] |
| E8 | Storybook (optional) | M | [ ] |
| E9 | Caching + performance | S | [ ] |
| E10 | Accessibility checks | M | [ ] |

## Where the UI is today
- Raw `<select>`, `<input>` and long Tailwind strings repeated in `create-form.tsx` and `edit-form.tsx`
- `app/ui/invoices/page.tsx` duplicates `app/dashboard/invoices/page.tsx` (see A2)
- `console.log("state", state)` in `create-form.tsx`; `required` commented out on the customer select
- Only `app/dashboard/invoices/error.tsx` exists; no `loading.tsx`, no global `not-found.tsx`
- Skeletons only for the invoices table; no UI tests

## E1. Form component kit [ ]
Why: a style or a11y fix is made once, and create/edit forms stop drifting.

- [ ] `app/ui/form/`: `TextInput.tsx`, `Select.tsx`, `FieldError.tsx` (move `form-error.tsx` here); each takes `label`, `name`, `error`, passes the rest to the native element
- [ ] Use them in `create-form.tsx` and `edit-form.tsx`
- [ ] One component per folder with an `index.tsx` that only re-exports
- [ ] Delete the `console.log`; restore `required` or note why not

## E2. Component tests and coverage gate [ ]
Why: UI regressions fail the build; a threshold that only goes up stops tests rotting.

- [ ] `pnpm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom`
- [ ] `vitest.config.ts` with `environment: 'jsdom'`
- [ ] Tests for `status.tsx` (Paid vs Pending), `pagination.tsx`, the new fields (error text), `login-form.tsx`
- [ ] `"test:coverage": "vitest run --coverage"` with a low start threshold (e.g. 30%); raise over time (85% is an end state)
- [ ] `coverage.exclude` for config files, `*.d.ts`, `placeholder-data.ts`
- [ ] Run in the `ci` job next to the A3 step

## E2b. Layer rule via lint [ ]
Why: the architecture is enforced by the pipeline, not memory. Do after B1.

- [ ] `no-restricted-imports` (or `eslint-plugin-boundaries`): `app/ui/**` must not import `app/lib/repositories/**`; `app/lib/services/**` must not import `app/ui/**`
- [ ] Add a forbidden import on purpose; confirm `pnpm lint` fails

## E3. One form pattern [ ]
Why: one way to validate and show errors.

- [ ] Export the zod schema from `schemas.ts`, use in client and action
- [ ] Every form: `useActionState` returning `{ errors, message }`, `<FieldError>` under each field, `aria-describedby`
- [ ] Apply to the login form (currently returns a plain string)

## E4. Error, loading, not-found, empty states [ ]
Why: a failed query shows a recovery button, not a blank screen; common source of real bugs.

- [ ] `app/dashboard/error.tsx` (copy the invoices one, remove `console.error`; use the logger from B3 later)
- [ ] `loading.tsx` for `/dashboard` and `/dashboard/customers`, reusing `app/ui/skeletons.tsx`
- [ ] `app/not-found.tsx`
- [ ] Empty state in invoices and customers tables ("No invoices match your search")

## E5. Small hooks [ ]
Why: components stay about layout; logic is reusable and shareable via URL.

- [ ] `app/lib/hooks/useUrlParams.ts` for `?query=` and `?page=` (replaces duplicated `URLSearchParams` in `search.tsx` / `pagination.tsx`)
- [ ] Keep `use-debounce` in the search component
- [ ] No client data library; server components cover it

## E6. Typecheck and pre-commit [ ]
Why: errors caught on your laptop in seconds; prettier ends formatting noise.

- [ ] `"typecheck": "tsc --noEmit"`; use it in CI
- [ ] `"prebuild": "pnpm typecheck"`
- [ ] Prettier + `lint-staged`, or local hooks in `.pre-commit-config.yaml`
- [ ] Run `pre-commit install` once so hooks actually run

## E7. Telemetry helper (optional) [ ]
- [ ] `app/lib/track.ts`: `track(name, props)` writes a structured log line (B3 logger); call on invoice created / deleted / login failed
- Why: CloudWatch Logs Insights can count events, no paid tool.

## E8. Storybook (optional) [ ]
Only after E1. E2 gives more value; skip if short on time.

## E9. Caching and performance [ ]
Why: fast static files, immediate deploys, and real before/after numbers.

- [ ] Network tab: `/_next/static/*` has `cache-control: public, max-age=31536000, immutable`
- [ ] `/version` and `/health` never cached (`Cache-Control: no-store` or `export const dynamic = "force-dynamic"`); the pipeline version check depends on it
- [ ] `next/image` with width and height for pictures under `public/`
- [ ] Run Lighthouse in Chrome DevTools; record Performance, Accessibility, Best Practices; fix top two issues; re-run

## E10. Accessibility checks [ ]
Why: a missing label or alt text fails the build.

- [ ] `eslint-plugin-jsx-a11y` (check `pnpm lint` first; `eslint-config-next` includes some rules)
- [ ] `@axe-core/playwright` in the Playwright test: no violations on `/login` and `/dashboard`
- [ ] Tab through the invoice form and pagination by hand

## Skip on purpose
Module Federation, a shared design-system package, full i18n, generated API hooks. Be ready to explain why.
