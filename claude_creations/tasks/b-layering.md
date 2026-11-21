# Priority B: layering

Back to [roadmap](../roadmap.md). Previous: [A](a-quick-wins.md). Next: [C delivery](c-delivery.md).

| ID | Task | Effort | Status |
|---|---|---|---|
| B1 | Repository / service split | M | [ ] |
| B2 | zod at every boundary | S | [ ] |
| B3 | Request ID + JSON logs | M | [ ] |
| B4 | Error wrapper for route handlers | S | [ ] |

## B1. Repository and service split [ ]
Why: a service can be unit-tested with a fake repository, and only `repositories/` knows about SQL.

Rule: a service never touches the database; it calls a repository.

```
app/lib/
  db.ts              # the one sql connection
  repositories/      # ONLY SQL, returns raw rows
    invoices.ts  customers.ts  revenue.ts
  services/          # rules: validate, dollars -> cents, format
    invoices.ts
```

- [ ] Move each SQL statement into a small function in `repositories/*.ts` (e.g. `insertInvoice(customerId, amountInCents, status, date)`)
- [ ] Move rules into `services/*.ts` (dollars to cents, `formatCurrency` mapping, status enum, "today" logic)
- [ ] Keep `"use server"` actions thin: parse the form (zod), call a service, `revalidatePath` / `redirect`
- [ ] Do one entity at a time (invoices first) and run the app after each move

## B2. Validate input at every boundary [ ]
Why: bad input gets a clear message instead of reaching SQL (SQL is already parameterized; this stops `page=-5`).

- [ ] Keep the existing zod schemas in `actions.ts`
- [ ] Validate `id` in `updateInvoice` / `deleteInvoice` (`z.string().uuid()`)
- [ ] Validate `query` and `page` in `app/dashboard/invoices/page.tsx` (`z.coerce.number().int().min(1)`)
- [ ] Any new route handler validates its query params the same way

## B3. Request ID and structured logs [ ]
Why: find every log line for one request, and filter JSON logs by field in CloudWatch. No new paid service.

- [ ] In `proxy.ts`, set `x-request-id` (`crypto.randomUUID()`) on request and response
- [ ] `app/lib/logger.ts`: `log(level, message, fields)` writing `console.log(JSON.stringify({ level, message, requestId, ...fields }))`
- [ ] Replace `console.error("Database Error:", ...)` with the logger
- [ ] Search one request ID in CloudWatch Logs Insights

## B4. Error wrapper for route handlers [ ]
Why: users never see stack traces or DB details (the deleted `/query` returned raw DB errors).

- [ ] `app/lib/api.ts`: `withErrors(handler)` with `try/catch`, logs with the request ID, returns `Response.json({ error: "Internal error" }, { status: 500 })`
- [ ] Use it in every `route.ts` (`/version`, `/health`)
- [ ] Never return the raw error object
