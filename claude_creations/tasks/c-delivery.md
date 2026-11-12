# Priority C: delivery process

Back to [roadmap](../roadmap.md). Previous: [B](b-layering.md). Next: [D hardening](d-hardening.md).

| ID | Task | Effort | Status |
|---|---|---|---|
| C1 | Migrations | M | [ ] |
| C2 | Taskfile / Makefile | S | [ ] |
| C3 | Trivy image scan | S | [ ] |
| C4 | Approval gate / staging | S / L | [ ] |

## C1. Real database migrations [ ]
Why: the DB was seeded by hand and caused a production issue. Repeatable setup fixes that, and schema changes get reviewed in PRs.

- [ ] Use `node-pg-migrate` (lightest fit for plain `postgres`; skip Drizzle / Prisma)
- [ ] Migration 001 creates `users`, `customers`, `invoices`, `revenue` to match `app/lib/definitions.ts`
- [ ] Seed data (`placeholder-data.ts`) in a separate dev-only script. Never auto-seed production with the demo password
- [ ] `pnpm migrate` script; try it on a throwaway database first
- [ ] Later: run it in the pipeline before deploy, DB URL from a GitHub secret

## C2. Taskfile or Makefile [ ]
Why: laptop and CI run identical commands.

- [ ] `Taskfile.yml` (`brew install go-task`) or `Makefile`
- [ ] Tasks: `lint`, `typecheck`, `test`, `build`, `scan` (gitleaks), `docker` (test VERSION)
- [ ] Workflow calls the same names

## C3. Trivy image scan [ ]
Why: finds known vulnerabilities inside the image, which gitleaks and hadolint do not see.

- [ ] In `deploy`, after build and **before** `docker push`: `aquasecurity/trivy-action` (check tag), `severity: CRITICAL,HIGH`, `exit-code: 1`
- [ ] First run will have findings: upgrade the base image, or ignore with a written reason

## C4. Approval gate and staging [ ]
Why: the gate alone proves you understand release control; staging lets you test migrations first.

Free version
- [ ] GitHub, Settings, Environments, `production`: add yourself as required reviewer

Full version (may cost money; check Fargate pricing, you want to stay free)
- [ ] Second ECS service (`staging`) and parameter set
- [ ] `deploy-staging` job, then `deploy-prod` with `needs: deploy-staging`
