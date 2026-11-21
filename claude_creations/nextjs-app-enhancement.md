# Next.js Dashboard: Enhancement To-Do List

Inspired by patterns from mature, layered production backends and web apps (layers, pipeline gates, versioned migrations, design-first APIs). Written from a re-read of this repo on 2026-11-06. Do these yourself, in order. Tick the boxes as you go.

Contains no secrets, account IDs or URLs.

---

## 0. What the repo looks like today

| Area | Current state | Gap vs a mature production setup |
|---|---|---|
| Routes | `app/dashboard/*`, `app/login`, `app/version/route.ts`, `app/query/route.ts` | No `/health` route |
| Data access | `app/lib/data.ts` (reads) and `app/lib/actions.ts` (writes) both run SQL directly | No separation of service and repository |
| DB client | `postgres(...)` is created **4 times**: `data.ts`, `actions.ts`, `auth.ts`, `app/query/route.ts` | Should be one shared connection |
| Validation | `zod` is already used in `actions.ts` and `auth.ts` | Good. Route handlers do not validate yet |
| Middleware | `proxy.ts` only does auth | No request ID, no structured logs |
| Tests | None (no test script, no test step in CI) | mature projects have unit, e2e and sanity suites |
| CI | `scan` (gitleaks) and `ci` (lint, tsc); `deploy` needs both; version check fails the run with `exit 1` | No tests, hadolint, image scan or Dependabot |
| Migrations | None. DB was seeded by hand | mature projects use versioned migrations |
| Data helpers | `fetchRevenue` and `fetchLatestInvoices` have `setTimeout` delays of 3 s and 5 s, left over from the course | Slows the live site on purpose |

### Two things to fix before anything else

1. **`app/query/route.ts` is probably public.** In `auth.config.ts`, a not-logged-in user on a non-dashboard path gets `return true`, and `proxy.ts` only excludes `api`, `_next`, `version` and `.png`. So `/query` is probably reachable without logging in, and it returns customer names. Test it in a private window against production. If it returns data, delete the route (it is a course exercise) and redeploy.
2. **Remove the artificial delays** in `data.ts` (lines with `setTimeout`). They were there to demo loading skeletons. In production they make the dashboard 5+ seconds slower for no reason.
-- DONE
---

## Priority A: small, high value (do first)

### A1. Add a `/health` endpoint
**What mature services do:** they expose health and version endpoints.

**Steps**
1. Create `app/health/route.ts` that returns `Response.json({ status: "ok" })`.
2. In `proxy.ts`, add `health` to the matcher exclusion list, next to `version`. Caveat: the pattern `version|health` also skips any path *starting with* those words. Fine for now.
3. Test locally: `curl localhost:3000/health`.
4. Optional: point an ECS container health check at it (task definition `healthCheck`, using `curl`; check the image has `curl`, or use `wget`/`node -e`).

**Why / benefits**
- ECS and load balancers can tell "process is up" from "process is stuck", so a broken container is replaced automatically.
- It is a cheap thing to monitor and a standard interview talking point.
- Keep it **dumb** (no DB call). If you later want readiness, add a separate `/ready` that checks the DB.

### A2. Delete `/query`, remove the delays, share one DB connection
**Steps**
1. Delete `app/query/route.ts`.
2. Delete the two `await new Promise(...setTimeout...)` lines and the `console.log` lines around them in `data.ts`.
3. Create `app/lib/db.ts` containing the one `postgres(process.env.POSTGRES_URL!, { ssl: "require" })` call and `export const sql`. Import it in `data.ts`, `actions.ts` and `auth.ts`.

**Why / benefits**
- Removes a possible public data leak.
- Each `postgres()` call opens its own connection pool. Four pools against a small free database can hit its connection limit.
- `db.ts` becomes the natural starting point for the repository layer (B1).

### A3. Add tests and a test step in CI
**What mature projects do:** unit tests, UI tests, and a sanity run before release.

**Steps**
1. `pnpm add -D vitest`
2. Add `"test": "vitest run"` to `package.json` scripts.
3. Write your first test for a pure function in `app/lib/utils.ts` (for example `formatCurrency`, `formatDateToLocal`, `generatePagination`). Create `app/lib/utils.test.ts`, import the function, and use `expect(...).toBe(...)`.
4. In `.github/workflows/ecs-run-container.yml`, in the `ci` job, replace the commented-out `# - run: npm test` with `- run: pnpm test`.
5. Later: add one Playwright test: open `/login`, enter the seeded user, expect to land on `/dashboard`.

**Why / benefits**
- CI currently proves only that the code compiles and lints. Tests prove it behaves.
- Starting with pure functions needs no database, so you get a green test in minutes.
- A failing test blocks `deploy` (because `deploy` needs `ci`), which is the whole point of a pipeline gate.
- Playwright is widely used for browser tests, so the skill transfers.

> After A3, continue with **Priority G** (back-end tests: auth, route handlers, server actions, real-database queries, authorization).

### A4. Add hadolint (Dockerfile linter) and Dependabot
**Steps**
1. Add a job (or a step in `ci`) using the hadolint action: `uses: hadolint/hadolint-action@v3.1.0` with `dockerfile: Dockerfile`. Check the current tag on the action's GitHub page first.
2. Create `.github/dependabot.yml` with two update entries: `package-ecosystem: npm` and `package-ecosystem: docker` (and optionally `github-actions`), each with `directory: "/"` and `schedule: interval: weekly`.
3. Remember Dependabot opens PRs; your `ci` job runs on them, so tests act as the safety net.

**Why / benefits**
- hadolint catches Dockerfile mistakes (unpinned versions, missing flags) before they reach ECR. Many teams run the same tool.
- Dependabot keeps `next`, `next-auth` and the base image patched. `next: "latest"` in `package.json` is a risk (see D2).

---

## Priority B: copy the layering

### B1. Split data code into repository and service
**The rule in layered backends:** a service never touches the database directly; it calls a repository.

**Target layout**
```
app/lib/
  db.ts                  # the one sql connection (from A2)
  repositories/
    invoices.ts          # ONLY SQL: select/insert/update/delete
    customers.ts
    revenue.ts
  services/
    invoices.ts          # rules: validate, convert dollars->cents, format
```

**Steps**
1. Move each SQL statement from `data.ts` and `actions.ts` into a small function in `repositories/*.ts` (for example `insertInvoice(customerId, amountInCents, status, date)`). It returns raw rows, nothing else.
2. Move the rules into `services/*.ts`: dollars-to-cents conversion, `formatCurrency` mapping, the status enum, and the "today's date" logic.
3. Keep the `"use server"` actions thin: parse the form (zod), call a service, handle `revalidatePath`/`redirect`.
4. Do one entity at a time (invoices first), and run the app after each move.

**Why / benefits**
- **Testable:** a service can be unit-tested by passing in a fake repository, with no database.
- **Changeable:** switching database or query style touches only `repositories/`.
- **Readable:** each file has one job, which is exactly what you would explain in an interview about layered architecture.

### B2. Validate input at every boundary
**The rule in layered backends:** the HTTP layer checks the shape of every request before it reaches the service.

**Steps**
1. Keep the existing zod schemas in `actions.ts`.
2. Add zod checks for what is not covered: the `id` in `updateInvoice` and `deleteInvoice` (`z.string().uuid()`), and the search `query` and `page` params in `app/dashboard/invoices/page.tsx` (`z.coerce.number().int().min(1)` for `page`).
3. Any new route handler (for example `/health`) validates query params the same way.

**Why / benefits**
- Bad input is rejected with a clear message instead of reaching SQL or crashing.
- Defence in depth: the SQL is parameterized already (good), but validation also stops nonsense like `page=-5`.

### B3. Request ID and structured logging
**Common practice:** a request-ID middleware stamps every request so all its log lines can be found together.

**Steps**
1. In `proxy.ts`, wrap the auth proxy: generate `crypto.randomUUID()`, set it as the `x-request-id` header on the request and response.
2. Create `app/lib/logger.ts` with a tiny `log(level, message, fields)` that writes `console.log(JSON.stringify({ level, message, requestId, ...fields }))`.
3. Replace the existing `console.error("Database Error:", error)` calls with the logger.
4. In CloudWatch Logs Insights, search for one request ID to see its whole story.

**Why / benefits**
- When a user reports an error, you can find every log line for that request in one search.
- JSON logs can be filtered by field (`level = "error"`), which plain text cannot.
- No new paid service: it uses the CloudWatch logs you already have.

### B4. One error-handling wrapper for route handlers
**Common practice:** error-handling middleware turns failures into clean 400/404/500 responses.

**Steps**
1. Create `app/lib/api.ts` with `withErrors(handler)` that calls the handler in `try/catch`, logs the error with the request ID, and returns `Response.json({ error: "Internal error" }, { status: 500 })`.
2. Use it in every `route.ts`. (After A2, you will have `/version` and `/health`.)
3. Make sure it never returns the raw error object to the client.

**Why / benefits**
- Users never see stack traces or database details.
- One place to change error format later.
- Note: the deleted `/query` route returned `{ error }` straight from the database, which is the exact thing this prevents.

---

## Priority C: copy the delivery process

### C1. Real database migrations
**Common practice:** a migration tool (goose, Flyway, node-pg-migrate) runs versioned, ordered schema changes.

**Why now:** you hit a production issue because the DB was seeded by hand. Repeatable setup avoids that.

**Steps**
1. Pick a small tool: `node-pg-migrate` is the lightest fit for plain `postgres`. (Drizzle or Prisma are bigger and change your data layer; skip them.)
2. Create migration 001 that creates `users`, `customers`, `invoices`, `revenue`, matching the shapes in `app/lib/definitions.ts`.
3. Put the seed data (from `placeholder-data.ts`) in a separate script, for dev only. Never auto-seed production with the demo password.
4. Add a `pnpm migrate` script and run it locally against a throwaway database first.
5. Later: run it as a pipeline step before the deploy step, with the DB URL from a GitHub secret.

**Why / benefits**
- A new environment (staging) can be created with one command.
- Schema changes are reviewed in PRs, like code.
- Fixes the "no production data" problem at the root.

### C2. Taskfile (or Makefile) for single-command tasks
**Common practice:** a Taskfile or Makefile wraps the common commands.

**Steps**
1. Add a `Taskfile.yml` (install `task` with `brew install go-task`) or a `Makefile` (already on your Mac).
2. Define: `lint`, `typecheck`, `test`, `build`, `scan` (gitleaks), `docker` (build image with a test VERSION).
3. Change the workflow to call the same names (`task lint`), so your laptop and CI run identical commands.

**Why / benefits**
- "Works on my machine" differences shrink, because CI and local run the same commands.
- New contributors only need to learn `task --list`.

### C3. Container image scanning with Trivy
**Steps**
1. In `deploy`, after the build and before the push, add a step using `aquasecurity/trivy-action` (check its current tag) with `image-ref` set to the built image and `severity: CRITICAL,HIGH` and `exit-code: 1`.
2. Expect some findings from the base image on the first run. Decide per finding: upgrade the base image, or add an ignore with a reason.

**Why / benefits**
- Catches known vulnerabilities in the OS packages and dependencies *inside* the image, which gitleaks and npm audit do not see.
- Completes the scanner set: gitleaks (secrets), hadolint (Dockerfile), Trivy (image).
- Run it **before** `docker push` so a bad image never lands in ECR.

### C4. Staging environment and manual approval
**Common practice:** staged rollout, for example QA, then UAT, then Prod.

**Cheapest version (free)**
1. In GitHub, Settings, Environments, open `production` and add a **required reviewer** (yourself). Every deploy then waits for your click.

**Full version (may cost money)**
1. Create a second ECS service (`staging`) and a second parameter set. Check Fargate pricing before doing this; you want to keep the free account.
2. Add a `deploy-staging` job that runs first, then `deploy-prod` with `needs: deploy-staging`.

**Why / benefits**
- The approval gate alone proves you understand release control.
- Staging lets you test migrations before production.

---

## Priority D: hardening and cleanup

### D1. Least privilege for the pipeline user
Remove SSM and execution-role policies (and any `AmazonSSMFullAccess`) from `github-actions-ecr`. Keep only ECR push and ECS deploy plus `iam:PassRole` on the two ECS roles. The execution role keeps only its narrow inline SSM read policy. Test with a deploy.

**Benefit:** if the pipeline credentials ever leak, the damage is limited to deploying. This must be done before you write "least privilege" on your CV.

### D2. Pin dependencies
`next`, `react` and `react-dom` are set to `"latest"`. Replace them with the exact installed versions (look in `pnpm-lock.yaml`). Delete the stray `package-lock.json`, since pnpm is your package manager.

**Benefit:** a deploy never changes because a new major version was published overnight. Dependabot (A4) then proposes upgrades deliberately.

### D3. Housekeeping
- Fix the `tailwind.config.ts` lint error.
- Remove the leftover `black` hook from `.pre-commit-config.yaml` (it is for Python).
- Decide on detect-secrets or gitleaks in pre-commit. Two scanners are noise.
- Do not commit `.vscode/settings.json` changes.
- Test the version check's failure path once: run the workflow with a wrong expected SHA and confirm the step fails.
- Open a pull request from `add-gitleaks` and confirm that both `scan` and `ci` run on it.
- Check Settings, Rules for the `main` push rejection (`commit_refs_rules`).

### D5. Pull request template
**Idea:** large teams use a PR template with: why we made the change, what the change is, impact, testing checklist, screenshots, feature flags.

**Steps**
1. Create `.github/pull_request_template.md` with the headings: Why, What, Impact, How I tested it (checkboxes: unit tests added, ran locally, pipeline green), Screenshots.
2. Drop their multi-microfrontend and feature-flag items; they don't apply.

**Why / benefits**
- Every PR explains itself, which is how teams write them.
- Reviewers (and recruiters browsing the repo) see a professional process.
- Takes about 2 minutes.

### D6. Commit message lint
**Idea:** teams enforce a commit format with a `commit-msg` hook. A common format is `<type>: [<TICKET>]: <description>`, with type one of `feat|fix|docs|style|refactor|perf|test|chore` and a max of 50 characters.

**Steps**
1. Choose a simpler format for yourself: `type: description` (no ticket ID, since you have none).
2. Add a commit-msg hook: `commitlint` with `@commitlint/config-conventional`, or a `pre-commit` hook using the `commit-msg` stage (`pre-commit install --hook-type commit-msg`).
3. Test it: `git commit --allow-empty -m "bad message"` should be rejected.

**Why / benefits**
- A readable, searchable history, and release notes can be generated from it later.
- Your recent messages ("command improvements") show why it helps.

### D7. Protect `main`, and block local commits to it
**Source:** the same `commit-msg` hook refuses commits on `master`, `develop` and `release/*`.

**Steps**
1. GitHub, Settings, Rules (rulesets), add a rule for `main`: require a pull request, require status checks `Gitleaks` and `Lint and typecheck` to pass, and block force pushes.
2. Add a local hook (`pre-commit` has a built-in `no-commit-to-branch` hook) with `args: [--branch, main]`.
3. This explains the `commit_refs_rules` rejection you saw: check whether a rule like this already exists. If so, the rejection was working as intended, not a bug.

**Why / benefits**
- Nothing reaches the deploy pipeline without passing the checks.
- A branch-and-PR workflow is standard professional practice.

### D8. Lighthouse in CI (extends E9)
**Idea:** some teams run Lighthouse from a script in CI.

**Steps**
1. Add `@lhci/cli` (Lighthouse CI) as a dev dependency, or use the `treosh/lighthouse-ci-action` in a workflow job.
2. Point it at the production URL after the deploy (or `http://localhost:3000` after `pnpm start` in a job).
3. Start with `warn` assertions (performance, accessibility, best practices at 0.8) rather than failing the build.

**Why / benefits**
- A performance regression shows up on the PR, not months later.
- Gives you the before/after numbers your CV is missing.

### D9. Architecture docs folder
**Idea:** keep one short note per concept in a `docs/` folder.

**Steps**
1. Create `docs/architecture.md` (diagram of browser, ECS service, SSM, database, GitHub Actions flow), `docs/deployment.md` (pipeline stages, how rollback and the version check work), `docs/secrets.md` (SSM, execution role vs pipeline user, name matching).
2. Link them from the README (which is still the course starter text).
3. Remove the account ID, URLs and parameter values before committing.

**Why / benefits**
- Shows you can explain a system, not just build one.
- Doubles as interview prep and as a checklist for "what did I actually build".

### D10. Comment convention
**Idea:** some teams require tagged comments: `TODO`, `FIXME`, `NOTE`, `REVIEW`, followed by a short specific message.

**Steps:** adopt `TODO:`, `FIXME:`, `NOTE:` only, and write them with a reason, for example `// TODO: replace with migrations (C1)`. Grep for them before a release.

**Why / benefits:** leftovers are easy to find, and you stop writing comments that restate the code.

### D11. Optional extras (only if you want them)
- **Simple feature flag:** an env var like `FEATURE_X=on` read in one helper. Skip a flag service.
- **CloudWatch alarm on 5xx errors or unhealthy tasks:** check the free-tier alarm limit first.
- **README rewrite (see D9):** the README is still the course starter text. Add an architecture diagram, how to run locally, and the pipeline stages. This is the first thing a recruiter opens.

### Skipped on purpose
Circuit breaker, Redis, object storage and mTLS solve problems this app does not have. Mention them in an interview as things you understood, not things you built.

---

## Priority E: UI (habits from large React codebases)

Large React codebases typically use a shared design system, generated API clients, schema-based forms, per-component tests with a coverage gate, and strict pre-commit hooks. Most of that tooling is too heavy for a small Next.js app, so below I copy the **habits**, not the tools.

### What large React codebases do, and the Next.js equivalent

| Common practice | Why they do it | Your Next.js version |
|---|---|---|
| Design-system components only (`<Button>`, `<Text>`, `<Layout>`), no raw `<button>`/`<div>` styling | Consistent look, one place to change | One `app/ui/` kit: `Button` exists already; add `Input`, `Select`, `Card`, `PageTitle` and use them everywhere |
| All user-facing text from one strings file | Translations and consistent wording | Optional: one `app/lib/strings.ts` object. Skip full i18n unless you want it |
| Generated API client hooks (never hand-edited) | The UI can't drift from the API | You use server actions, so the nearest thing is **typed return values + zod schemas shared by form and action** |
| One form library with schema validation | One way to do validation and errors | You have `useActionState` + zod, which is already the same idea. Make it consistent (E3) |
| Folder per component: `Card/index.tsx` (barrel), `Card.tsx`, a styles file, `__tests__/Card.test.tsx` | Predictable, testable | Same structure, with Tailwind instead of a styles file |
| `__tests__/` next to every component, a shared test wrapper, **85% coverage gate** in CI | Stops untested UI from merging | Vitest + React Testing Library, then a coverage gate (E2) |
| An app-level error boundary | One crash doesn't blank the page | Next.js `error.tsx` per route segment (E4) |
| One small hook per concern (permissions, flags, query params, polling) | Logic out of components | Small hooks for URL search params and debounce (E5) |
| Telemetry events registered in one place | Know which features are used | Optional: one `track(event)` helper (E7) |
| Storybook | Build and review components in isolation | Optional (E8) |
| Husky + lint-staged: lint, prettier and `tsc` on staged files; typecheck runs before build | Bad code never gets committed | You have pre-commit already; add prettier and a `tsc` hook (E6) |
| Frontend ships as its own image: build stage, then a tiny nginx runtime as non-root, with a health endpoint, long cache for hashed JS/CSS, `no-cache` for the entry file | Fast, cheap, safe serving | Your image is Node standalone, which is correct for SSR. Copy only the **caching and health** ideas (A1, E9) |

### What your UI looks like today (from the re-read)

- Components live in `app/ui/` (dashboard, invoices, customers, login). A shared `Button` exists, but forms use raw `<select>`, `<input>` and long Tailwind class strings, repeated in `create-form.tsx` and `edit-form.tsx`.
- `app/ui/invoices/page.tsx` and `app/dashboard/invoices/page.tsx` appear to be **duplicates** (both have the same `Suspense` code). Check which one is used and delete the other.
- `create-form.tsx` has `console.log("state", state)` in a client component, and `// required` is commented out on the customer `<select>`.
- Only `app/dashboard/invoices/error.tsx` exists. There is no `error.tsx` or `loading.tsx` for `/dashboard` or `/dashboard/customers`, and no global `not-found.tsx`.
- Skeletons and `Suspense` are used for the invoices table only.
- There are some accessibility attributes (`aria-describedby`, `htmlFor`, `alt`; about 26 matches in `app/ui`), but nothing checks them automatically.
- No UI tests of any kind.

### E1. Build a small component kit and stop repeating class strings
**Steps**
1. Create `app/ui/form/` with `TextInput.tsx`, `Select.tsx` and `FieldError.tsx` (you already have `form-error.tsx`; move it here). Each takes `label`, `name`, `error` and passes the rest to the native element.
2. Replace the duplicated markup in `create-form.tsx` and `edit-form.tsx` with these.
3. Follow the common folder rule: one component per folder, a named file, and an `index.tsx` that only re-exports.
4. Delete `console.log("state", state)`. Restore the `required` attribute if the server-side check is the only guard you want to keep, or leave it off on purpose and note why.

**Why / benefits**
- A style or accessibility fix is made once, not in four files.
- The create and edit forms stop drifting apart.
- It matches the common rule "never use a native element when a design-system equivalent exists", which is a good interview point.

### E2. Component tests plus a coverage gate
**Common practice:** one `__tests__` folder per component, and CI fails below a coverage threshold such as 85%.

**Steps**
1. `pnpm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom`
2. Add a `vitest.config.ts` with `environment: 'jsdom'`.
3. Write tests next to the components: `app/ui/invoices/status.tsx` (renders "Paid" vs "Pending"), `pagination.tsx`, your new form fields (shows the error text when `error` is passed), `login-form.tsx` (renders the inputs).
4. Add `"test:coverage": "vitest run --coverage"` and a threshold in the config. Start low (for example 30%) and raise it as you add tests. 85% is an end state, not a starting point.
5. Run it in the `ci` job next to the A3 test step.

**Why / benefits**
- UI regressions (a missing label, a broken status badge) fail the build, not production.
- A coverage threshold that only goes up stops the test suite from rotting.
- It extends A3 from "pure functions" to real components.

**Extra idea:** big projects count only real test files, exclude generated code, and report coverage per area. Do the same in the Vitest config: set `coverage.exclude` for config files, `*.d.ts` and `app/lib/placeholder-data.ts`, so the percentage reflects real code. SonarCloud (free for public repos) is optional.

### E2b. Enforce the layer rule with lint
**Idea:** a custom lint rule (with its own test) can stop a lower layer from importing a higher one.

**Steps**
1. After B1, add `no-restricted-imports` rules (or `eslint-plugin-boundaries`) in `eslint.config.mjs`: `app/ui/**` must not import `app/lib/repositories/**`, and `app/lib/services/**` must not import `app/ui/**`.
2. Test it by adding a forbidden import on purpose and confirming `pnpm lint` fails.

**Why / benefits**
- The architecture is enforced by the pipeline, not by memory.
- It is the lint version of the "services never touch the database" rule.

### E3. Use one form pattern everywhere
**Steps**
1. Share the zod schema between the client and the server action so the field names live in one place (export the schema from a `schemas.ts`, import it in both).
2. Make every form follow the same shape: `useActionState` returning `{ errors, message }`, with `<FieldError>` under each field and `aria-describedby` linking them.
3. Apply it to the login form too (it currently returns a plain string).

**Why / benefits**
- Same idea as "never bypass Formik": one way to do validation and error display.
- Fewer places for a field name typo to hide.

### E4. Error, loading and not-found states for every route
**Common practice:** an error boundary, plus loading and empty states on every list. Design the empty, loading and error states first.

**Steps**
1. Add `app/dashboard/error.tsx` (copy the invoices one, but also **remove** the `console.error`; use the logger from B3 when you have it).
2. Add `loading.tsx` for `/dashboard` and `/dashboard/customers`, reusing the skeletons in `app/ui/skeletons.tsx`.
3. Add `app/not-found.tsx` so unknown URLs get a friendly page.
4. Add an **empty state** to the invoices and customers tables ("No invoices match your search") instead of a blank table.

**Why / benefits**
- A failed query shows a recovery button instead of a blank screen or stack trace.
- Users see a skeleton while data loads, not a frozen page.
- It is a common source of real bugs, so it is an easy story to tell.

### E5. Small hooks for repeated UI logic
**Steps**
1. `app/lib/hooks/useUrlParams.ts`: reads and updates `?query=` and `?page=` (used by `search.tsx` and `pagination.tsx` today with duplicated `URLSearchParams` code).
2. Keep `use-debounce` (already installed) inside the search component.
3. Leave data fetching in server components. Do not add a client data library (React Query etc.), because server components already cover it.

**Why / benefits**
- Same reason big codebases have one hook per concern: components stay about layout, logic is reusable and testable.
- Storing sorting, filtering and pagination in the URL lets a link be shared.

### E6. Stronger pre-commit and a typecheck before build
**Common practice:** `lint-staged` runs eslint and prettier on staged files; `prebuild` runs a typecheck.

**Steps**
1. Add `"typecheck": "tsc --noEmit"` to `package.json` and use it in CI instead of `pnpm exec tsc`.
2. Add `"prebuild": "pnpm typecheck"`.
3. Add prettier plus `lint-staged`, or equivalent local hooks in `.pre-commit-config.yaml` (eslint on staged `.ts`/`.tsx`).
4. Run `pre-commit install` once, so the hooks actually run (this was the lesson from earlier).

**Why / benefits**
- Errors are caught on your laptop in seconds, not after a pipeline run.
- The formatting noise in `.vscode/settings.json` and diffs goes away because prettier decides.

### E7. Optional: a tiny telemetry helper
**Steps:** create `app/lib/track.ts` with `track(name, props)` that for now just writes a structured log line (same logger as B3). Call it on "invoice created", "invoice deleted", "login failed".

**Why / benefits**
- Follows the practice that every user action has a registered event name.
- CloudWatch Logs Insights can then count events with no paid analytics tool.

### E8. Optional: Storybook
Only if you want to see components in isolation. It is useful once E1 exists. Skip it if you are short on time; E2 gives more value for a hiring manager.

### E9. Web performance and caching (the nginx lessons)
**Common practice:** nginx caches hashed JS/CSS for 30 days (`immutable`) but never caches the entry file.

**Steps**
1. Next.js already adds long-lived headers to `/_next/static/*`, so check them in the browser's Network tab. Confirm `cache-control: public, max-age=31536000, immutable`.
2. Make sure `/version` and `/health` are **never** cached. Return `Cache-Control: no-store`, or add `export const dynamic = "force-dynamic"` to the route. This matters because your pipeline's version check relies on `/version` being fresh.
3. Use `next/image` for pictures (the customer images under `public/`), with width and height set.
4. Run Lighthouse once in Chrome DevTools and write down the Performance, Accessibility and Best Practices scores. Fix the top two issues and re-run.

**Why / benefits**
- Static files are fast and cheap to serve, and a deploy still takes effect immediately.
- A cached `/version` could make your verification step pass or fail wrongly.
- Gives you real before/after numbers for your CV.

### E10. Accessibility checks
**Steps**
1. Add `eslint-plugin-jsx-a11y` (`eslint-config-next` already includes some of its rules; check `pnpm lint` output first).
2. In the Playwright test (A3, step 5), add `@axe-core/playwright` and assert there are no violations on `/login` and `/dashboard`.
3. Check keyboard use manually: Tab through the invoice form and the pagination links.

**Why / benefits**
- A broken label or missing alt text fails the build, so accessibility is checked automatically instead of by eye.
- It gives you a concrete accessibility example to talk about.

### UI items to skip
Module Federation, a shared design-system package, full i18n and generated API hooks. They solve problems of a big multi-team product. Be ready to explain **why** you skipped them.

---

## Priority F: Product features (what the invoice dashboard could do)

The app today: log in, see dashboard cards, a revenue chart and latest invoices, then list, search, paginate, create, edit and delete invoices, and view a customers table. Customers are read-only.

Rules for this section:
- Features marked **(schema)** change the database. Do them after migrations (C1), or you will be altering production by hand.
- Add a test for each rule as you build it (A3, E2), for example "an invoice only shows as overdue while it is pending".
- Fix the `/query` leak (A2) before adding any export or API feature.

### Small (a few hours each)

**F1. Sort and filter invoices**
- Sort by amount, date or status. Filter by status (paid, pending) and by date range.
- Keep choices in the URL like `query` and `page`, so links are shareable.
- Validate the params with zod (B2).
- *Why:* the most visible improvement, and a very common real-world pattern.

**F2. Overdue status (schema)**
- Add a `due_date` column. Show "overdue" when an invoice is pending and past its due date.
- *Why:* your first real migration, and a small business rule that belongs in the service layer (B1) with a unit test.

**F3. Customer detail page**
- Click a customer to see their invoices, total paid and total owed.
- *Why:* uses a join, and exercises the repository/service split.

**F4. Safer delete (schema)**
- Replace the hard delete with a `deleted_at` column and an "undo" message, or at least a confirmation step.
- *Why:* today `deleteInvoice` removes the row permanently. "Why not hard delete?" is a good interview question.

### Medium (a weekend each)

**F5. Create, edit and delete customers**
- Customers are read-only today. Add the same CRUD flow, reusing the form components from E1.
- *Why:* proves your form pattern is reusable, and covers uniqueness checks (duplicate email).

**F6. Export to CSV**
- A route handler that streams the filtered invoices as a file.
- It must require login. Wrap it with the error handler (B4).
- *Why:* teaches streaming and auth on route handlers.

**F7. Printable invoice view**
- A page like `/dashboard/invoices/[id]/print` with print-only CSS. Use the browser's "Save as PDF" rather than adding a PDF library.
- *Why:* real user value for almost no code.

**F8. Revenue chart from real data**
- Compute monthly revenue from paid invoices instead of the separate `revenue` seed table, so the chart and the cards agree.
- *Why:* two numbers on one screen must come from the same rule. Great interview story.

**F9. Audit trail (schema)**
- An `audit_log` table recording who created, edited or deleted which invoice and when, plus a simple page to view it.
- Write entries in the service layer, not in the page.
- *Why:* audit trails are standard in business software. A strong CV point.

### Big (pick one as a showcase)

**F10. Roles and permissions (schema)**
- Add a `role` to `users` (admin, viewer). Viewers cannot create, edit or delete. Buttons are disabled with a reason, and the server checks again.
- *Why:* role-based access control is a common interview topic. Test both the UI state and the server check.

**F11. Sign-up and multiple accounts (schema)**
- Registration with password rules, and rate limiting on login.
- Each user sees only their own customers and invoices (add `user_id`).
- *Why:* turns the demo into a real multi-user app. Raises real security questions (authn vs authz).

**F12. Invoice email reminders**
- Send a reminder for overdue invoices using AWS SES.
- *Why:* a realistic integration. Check the cost, sandbox limits and domain verification first, because your goal is to stay on the free account.

**F13. REST API with an OpenAPI spec (schema-first with zod)**

What this copies: design-first development with code generation, as in Go's Goa framework, where a design file generates the OpenAPI spec, the server code and the client. You won't use Goa, so your zod schemas play the role of the design file.

| Goa world | Your stack |
|---|---|
| Goa design file | zod schemas for requests and responses |
| Goa writes `openapi3.json` | `@asteasolutions/zod-to-openapi` (or `zod-openapi`) writes `openapi.json` |
| A generator (such as `restful-react`) builds UI hooks from the spec | `openapi-typescript` generates types, `openapi-fetch` gives a typed client |
| Generated server validation | the same zod schemas, used in the route handler |
| "Never hand-edit generated files" | same rule, plus a CI check |

Steps
1. Create `app/lib/api/schemas.ts` with zod schemas: `InvoiceSchema`, `ListInvoicesQuery` (page, query, status), `CreateInvoiceBody`, `ErrorSchema`.
2. Create `app/api/invoices/route.ts` (`GET` list, `POST` create). Parse input with the schemas (B2), call the service (B1), wrap with the error handler (B4). Require login.
3. Register the routes and schemas with the zod-to-openapi library, and add a script `scripts/generate-openapi.ts` (you already have `tsx`) that writes `openapi.json`.
4. Generate types with `openapi-typescript openapi.json -o app/lib/api/generated.d.ts`, and add `pnpm api:generate` to run both steps.
5. Use `openapi-fetch` in a client component (for example a live-search invoices table) so the UI call is typed from the spec.
6. In CI, run `pnpm api:generate` and fail if `git diff --exit-code` shows a change, so the committed spec cannot drift from the code.
7. Contract test: in Vitest, call the route handler and validate the response with the response schema.
8. Check library versions first: you are on zod 3, and the OpenAPI libraries change between zod versions. Read the README of the one you pick before installing.

Limits to be aware of
- Server actions are not HTTP APIs, so they never appear in the spec. Only route handlers do. The UI uses the generated client only on screens you choose to move to those routes.
- zod is the source of truth, so the spec is generated from code (schema-first), not written by hand (spec-first).

*Why:* the UI and the server can't disagree about the API shape, which is the main benefit of a design-first workflow. It also gives you a spec to link in the README and in interviews.

### Suggested order for features

F1, then F8, then F2, then F10, then F9. That gives a visible UI win, consistent data, a migration, an RBAC story and an audit trail. Tell the stories only for what you have built and tested.

---

## Priority G: Back-end testing (the top 5)

These extend A3 (which only covers pure helpers). They are the tests that guard something that has already broken, or that would cost most if it broke. Do them in this order. All use Vitest (set up in A3).

**One-time setup for all five**
1. Add `vite-tsconfig-paths` as a dev dependency and use it in `vitest.config.ts`, so the `@/` imports in your code resolve in tests.
2. `auth.ts`, `actions.ts` and `data.ts` run `postgres(process.env.POSTGRES_URL!)` when imported. In unit tests, mock the module with `vi.mock("postgres")`, or import from the shared `db.ts` (A2) and mock that one file. Do A2 first; it makes this much easier.
3. Run the tests in CI in the `ci` job (`pnpm test`).

### G1. Auth tests
**What to test**
1. The `authorized` callback in `auth.config.ts`. Call `authConfig.callbacks.authorized({ auth, request: { nextUrl: new URL("http://x/dashboard") } })` and check:
   - logged out + `/dashboard` returns `false` (redirect to login)
   - logged in + `/dashboard` returns `true`
   - logged out + `/login` returns `true`
   - logged in + `/login` returns a redirect to `/dashboard`
2. `authorize()` in `auth.ts`: valid email and password returns the user; wrong password returns `null`; unknown email returns `null`; invalid email format or password under 6 characters returns `null` without touching the database. Mock `getUser`'s SQL result, and use a real `bcrypt.hash` for the stored password.
3. The `proxy.ts` matcher: confirm that `version` and `health` are excluded. The matcher is a path pattern, not a plain regex, so the most reliable check is a post-deploy or end-to-end request to `/version` with no cookie that expects JSON, not a redirect.

**Why / benefits**
- Login is the only protection for customer data.
- `/version` already broke once through this redirect; this is the test that would have caught it.

### G2. Route handler tests
**What to test**
1. `GET()` from `app/version/route.ts`: set `process.env.VERSION = "abc123"`, call `await GET()`, check `response.status === 200` and `await response.json()` equals `{ deployedVersion: "abc123" }`.
2. `GET()` from `app/health/route.ts` (A1): returns `{ status: "ok" }` with status 200.
3. Optional: assert the `Cache-Control: no-store` header (E9), so a cached version can't fool the deploy check.

**Why / benefits**
- The pipeline's verify step depends on `/version`. If it breaks, every deploy fails.
- No mocking needed; it is the easiest test to start with. Takes about 10 minutes.

### G3. Server action tests
**What to test** (`createInvoice` and `updateInvoice` in `app/lib/actions.ts`)
1. Build a `FormData` with `fd.set("customerId", "...")`, `fd.set("amount", "12.5")`, `fd.set("status", "pending")`.
2. Mock `next/cache` (`revalidatePath`), `next/navigation` (`redirect`), `@/auth` and the SQL client.
3. Cases:
   - amount `0` or negative returns `errors.amount`
   - missing customer returns `errors.customerId`
   - invalid status returns `errors.status`
   - valid input calls the SQL insert with the amount in **cents** (12.5 becomes 1250) and calls `redirect("/dashboard/invoices")`
   - a database error returns the message "issue creating invoice" instead of throwing
4. Same pattern for `updateInvoice` and `deleteInvoice` (the delete case: a database error throws).

**Why / benefits**
- This is the main write path and holds your only business rules.
- It locks in the dollars-to-cents rule, which is easy to break during the B1 refactor. These tests let you refactor safely.

### G4. Repository integration tests against a real Postgres
**What to test:** the real SQL for the invoice list (search by name, email, amount, date, status), pagination (page 1, last page, empty), counts, and the join between invoices and customers.

**Steps**
1. Make SSL configurable in `db.ts` (A2): for example `ssl: process.env.DB_SSL === "off" ? false : "require"`. A plain Postgres container does not support SSL, so the current hard-coded `ssl: "require"` would fail.
2. In the workflow, add a `services:` block to a test job: `postgres:16` image, `POSTGRES_PASSWORD`, `POSTGRES_DB`, port `5432`, and a health check (`pg_isready`).
3. Set `POSTGRES_URL` to the container and `DB_SSL=off` as job env vars.
4. Create the tables and seed a few rows in a `beforeAll` (use the migration files after C1, or a small SQL setup file until then).
5. Run these tests as a separate script (`pnpm test:integration`), so the quick unit tests stay quick.

**Why / benefits**
- Mocks cannot catch SQL mistakes (a wrong column, a bad join, an off-by-one in pagination). A real database can.
- The container is free and thrown away on every run.
- Also proves the schema in your setup scripts matches what the code expects.

### G5. Authorization tests (do these once the features exist)
**What to test**
1. **Export route (F6):** a request without a session returns 401.
2. **Roles (F10):** a viewer calling `createInvoice`, `updateInvoice` or `deleteInvoice` is rejected on the server, even if the button was hidden. An admin succeeds.
3. **Multi-user (F11):** user A cannot read or edit user B's invoices (expect "not found" or 403).
4. Test both layers: the UI state (the button is disabled with a reason) and the server check.

**Why / benefits**
- A hidden button is not security; the server check is.
- Until F6 or F10 exist there is nothing to test, so this stays on the list rather than being a first task.

### What to do next after G1–G5
Service tests (once B1 exists) and migration tests (once C1 exists) become essential then. Contract tests and extra security checks are lower priority; `pnpm audit` in CI is worth adding at any time.

---

## Suggested order

1. A2 (remove `/query`, delays, shared DB)
2. A1 (`/health`)
3. A3 (tests in CI)
4. A4 (hadolint, Dependabot)
5. D1 (least privilege)
6. B1 (repository and service split)
7. C1 (migrations)
8. B2, B3, B4
9. C2, C3, C4
10. D2, D3, D11
9b. Back-end tests: G2 and G1 first (about an hour, no database), then G3, then G4. G5 once F6 or F10 exist.
10b. Quick process wins (any time, 5-10 minutes each): D5 (PR template), D6 (commit lint), D7 (protect `main`), D10 (comment tags). Then D8 and D9.
11. UI: E1 and E4 first (visible, quick), then E2, E6, E9, E10, E3, E5. E7 and E8 are optional.

## What you can honestly put on your CV after each

| Done | CV line you can then claim |
|---|---|
| A3 | "Added unit tests as a required pipeline gate" |
| A4 + C3 | "Pipeline scans secrets, Dockerfile and image vulnerabilities before deploy" |
| B1 | "Separated data access (repository) from business rules (service) so logic is testable without a database" |
| B3 | "Structured JSON logging with per-request IDs, searchable in CloudWatch" |
| C1 | "Versioned database migrations run from the pipeline" |
| C4 | "Manual approval gate before production releases" |
| E1 + E2 | "Built a reusable form-component kit with component tests and a CI coverage threshold" |
| E4 | "Added error, loading, empty and not-found states across all routes" |
| E9 + E10 | "Measured and improved Lighthouse scores; automated accessibility checks in CI" (add the real numbers) |
| F10 | "Role-based access control enforced in the UI and on the server, with tests for both" |
| F9 | "Audit trail recording who changed which invoice" |
| F8 | "Fixed inconsistent figures by deriving chart and cards from the same source" |
| D1 | "Least-privilege IAM for the pipeline" (only after you have verified it) |

Only claim what you have built and seen working.
