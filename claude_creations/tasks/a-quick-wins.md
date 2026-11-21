# Priority A: quick wins

Back to [roadmap](../roadmap.md). Next: [B layering](b-layering.md).

| ID | Task | Effort | Status |
|---|---|---|---|
| A1 | `/health` route | S | [ ] |
| A2 | Delete `/query`, remove delays, one DB connection | S | [x] |
| A3 | Vitest + CI test step | S | [ ] |
| A4 | hadolint + Dependabot | S | [ ] |

## A1. `/health` endpoint [ ]
Why: ECS can tell "up" from "stuck" and replace a broken container.

- [ ] Create `app/health/route.ts` returning `Response.json({ status: "ok" })`
- [ ] Add `health` to the `proxy.ts` matcher exclusion, next to `version`
- [ ] `curl localhost:3000/health`
- [ ] Optional: ECS container `healthCheck` (check the image has `curl`, or use `wget` / `node -e`)

Keep it dumb (no DB call). A separate `/ready` can check the DB later.
Note: `version|health` in the matcher also skips paths that *start* with those words. Fine for now.

## A2. Cleanup and one DB connection [x]
Why: removed a public data leak, and one pool instead of several.

- [x] Delete `app/query/route.ts`
- [x] Remove the `setTimeout` delays and their `console.log` lines
- [x] `app/lib/db.ts` holds the single `postgres(...)` call
- [ ] Check no other file still calls `postgres(` (`grep -rn "postgres(" app auth.ts`)
- [ ] Check `app/ui/invoices/page.tsx` (duplicate route, possibly public): open `/ui/invoices` logged out; if it loads, delete the file

## A3. Tests in CI [ ]
Why: CI only proves the code compiles and lints. A failing test blocks `deploy` (it `needs: ci`).

- [ ] `pnpm add -D vitest`
- [ ] Add `"test": "vitest run"` to `package.json`
- [ ] First test on a pure function in `app/lib/utils.ts` (`formatCurrency`, `formatDateToLocal`, `generatePagination`) in `app/lib/utils.test.ts`
- [ ] In `.github/workflows/ecs-run-container.yml`, `ci` job: replace the commented `# - run: npm test` with `- run: pnpm test`
- [ ] Later: one Playwright test (login with the seeded user, land on `/dashboard`)

Next: [G back-end tests](g-backend-tests.md).

## A4. hadolint and Dependabot [ ]
Why: catches Dockerfile mistakes before ECR, and keeps `next`, `next-auth` and the base image patched.

- [ ] Add `hadolint/hadolint-action` (check the current tag) with `dockerfile: Dockerfile`
- [ ] Create `.github/dependabot.yml`: `npm`, `docker`, optionally `github-actions`; `directory: "/"`, `interval: weekly`
- [ ] Remember Dependabot PRs run your `ci`, so tests are the safety net
