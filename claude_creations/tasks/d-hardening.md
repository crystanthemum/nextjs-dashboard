# Priority D: hardening and process

Back to [roadmap](../roadmap.md). Previous: [C](c-delivery.md). Next: [E UI](e-ui.md).

| ID | Task | Effort | Status |
|---|---|---|---|
| D1 | Least-privilege pipeline user | S | [ ] |
| D2 | Pin dependencies | S | [ ] |
| D3 | Housekeeping | S | [ ] |
| D5 | PR template | S | [ ] |
| D6 | Commit message lint | S | [ ] |
| D7 | Protect `main` | S | [ ] |
| D8 | Lighthouse CI | M | [ ] |
| D9 | `docs/` folder | M | [ ] |
| D10 | Comment tags | S | [ ] |
| D11 | Optional extras | M | [ ] |

## D1. Least privilege for the pipeline user [ ]
Why: if pipeline credentials leak, the damage is limited to deploying. Do this before writing "least privilege" on a CV.

- [ ] Remove SSM and execution-role policies (and any `AmazonSSMFullAccess`) from `github-actions-ecr`
- [ ] Keep only ECR push, ECS deploy, and `iam:PassRole` on the two ECS roles
- [ ] The execution role keeps only its narrow inline SSM read policy
- [ ] Run a deploy to confirm

## D2. Pin dependencies [ ]
Why: a deploy never changes because a new major version appeared overnight.

- [ ] Replace `"latest"` for `next`, `react`, `react-dom` with the exact installed versions (see `pnpm-lock.yaml`)
- [ ] Delete the stray `package-lock.json` (pnpm is the package manager)

## D3. Housekeeping [ ]
- [ ] Fix the `tailwind.config.ts` lint error
- [ ] Remove the leftover `black` hook from `.pre-commit-config.yaml` (Python)
- [ ] Pick one secrets scanner for pre-commit (detect-secrets or gitleaks)
- [ ] Do not commit `.vscode/settings.json` changes
- [ ] Test the version check failure path once (wrong expected SHA, confirm the step fails)
- [ ] Open a PR from `add-gitleaks` and confirm `scan` and `ci` both run
- [ ] Check Settings, Rules for the `main` push rejection (`commit_refs_rules`)

## D5. PR template [ ]
Why: every PR explains itself. About 2 minutes.

- [ ] `.github/pull_request_template.md` with Why, What, Impact, How I tested it (checkboxes: unit tests, ran locally, pipeline green), Screenshots

## D6. Commit message lint [ ]
Why: readable, searchable history; release notes can be generated later.

- [ ] Format: `type: description` (`feat|fix|docs|style|refactor|perf|test|chore`)
- [ ] `commitlint` with `@commitlint/config-conventional`, or pre-commit's `commit-msg` stage (`pre-commit install --hook-type commit-msg`)
- [ ] Test: `git commit --allow-empty -m "bad message"` is rejected

## D7. Protect `main` [ ]
Why: nothing reaches the deploy pipeline without passing checks.

- [ ] GitHub, Settings, Rules: require a PR, require checks `Gitleaks` and `Lint and typecheck`, block force pushes
- [ ] Local `no-commit-to-branch` hook with `args: [--branch, main]`
- [ ] Check whether a rule already exists: the earlier `commit_refs_rules` rejection may have been it working as intended

## D8. Lighthouse in CI [ ]
Why: performance regressions show on the PR, and you get before/after numbers.

- [ ] `@lhci/cli` or `treosh/lighthouse-ci-action`
- [ ] Point at the production URL after deploy (or `localhost:3000` after `pnpm start`)
- [ ] Start with `warn` assertions at 0.8, not failing the build

## D9. Docs folder and README [ ]
Why: shows you can explain a system, not just build one.

- [ ] `docs/architecture.md` (browser, ECS, SSM, database, Actions flow)
- [ ] `docs/deployment.md` (stages, rollback, version check)
- [ ] `docs/secrets.md` (SSM, execution role vs pipeline user, name matching)
- [ ] Rewrite the README (still the course starter text): diagram, run locally, pipeline stages; link the docs
- [ ] Strip account ID, URLs and parameter values before committing

## D10. Comment convention [ ]
Why: leftovers are easy to find.

- [ ] Use `TODO:`, `FIXME:`, `NOTE:` only, each with a reason (`// TODO: replace with migrations (C1)`)
- [ ] Grep for them before a release

## D11. Optional extras [ ]
- [ ] Simple feature flag: env var `FEATURE_X=on` read in one helper (skip a flag service)
- [ ] CloudWatch alarm on 5xx or unhealthy tasks (check the free-tier alarm limit)

## Skipped on purpose
Circuit breaker, Redis, object storage, mTLS: they solve problems this app does not have. Be ready to say you understood them, not that you built them.
