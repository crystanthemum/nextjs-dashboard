# How Your Next.js App Is Organised (App Router), Explained

A visual guide to your `nextjs-dashboard` repo. Written from a read of the repo on 2026-11-12. No secrets or URLs in it.

**Caveat:** the repo is changing (you just moved the SQL into `app/lib/db.ts`). If a file name below no longer matches, trust the repo, not this note.

---

## 1. The one rule that explains everything

> Inside `app/`, **a folder only becomes a web page if it contains a special file** such as `page.tsx` or `route.ts`. The folder name becomes the URL.

Everything else in `app/` is just storage for code.

| Special file | What it does | Example in your repo |
|---|---|---|
| `page.tsx` | The page at that URL | `app/dashboard/invoices/page.tsx` is `/dashboard/invoices` |
| `layout.tsx` | A frame wrapped around every page below it | `app/dashboard/layout.tsx` adds the side nav |
| `route.ts` | An API endpoint with no screen | `app/version/route.ts` is `/version` |
| `error.tsx` | Shown when something below it crashes | `app/dashboard/invoices/error.tsx` |
| `not-found.tsx` | Shown for a missing item | `app/dashboard/invoices/[id]/edit/not-found.tsx` |
| `loading.tsx` | Shown while the page is loading | (you have none yet; see E4 in the enhancement doc) |
| `[id]` folder | A variable part of the URL | `/dashboard/invoices/123/edit` |

Folders **without** those files (`app/ui`, `app/lib`) are not pages. They are shelves for shared code.

---

## 2. Your folder tree, with a job for each part

```
nextjs-dashboard/
├── proxy.ts                  ← runs BEFORE every request (login check)
├── auth.ts / auth.config.ts  ← who may log in, and which URLs need login
├── next.config.ts            ← build settings (output: "standalone" for Docker)
├── Dockerfile                ← packages the built app into an image
│
└── app/
    ├── layout.tsx            ← ROOT frame: <html>, <body>, fonts, global CSS
    ├── page.tsx              ← "/"            (landing page)
    │
    ├── login/page.tsx        ← "/login"
    ├── version/route.ts      ← "/version"     (JSON, no screen)
    │
    ├── dashboard/            ← everything under "/dashboard" (needs login)
    │   ├── layout.tsx        ← frame: side nav on the left, page on the right
    │   ├── page.tsx          ← "/dashboard"
    │   ├── customers/page.tsx          ← "/dashboard/customers"
    │   ├── version/page.tsx            ← "/dashboard/version"
    │   └── invoices/
    │       ├── page.tsx                ← "/dashboard/invoices"
    │       ├── error.tsx               ← error screen for this section
    │       ├── create/page.tsx         ← "/dashboard/invoices/create"
    │       └── [id]/edit/
    │           ├── page.tsx            ← "/dashboard/invoices/123/edit"
    │           └── not-found.tsx
    │
    ├── lib/                  ← NOT pages: logic and data
    │   ├── db.ts             ← the database connection and queries
    │   ├── actions.ts        ← server actions (create/update/delete)
    │   ├── definitions.ts    ← TypeScript types
    │   ├── utils.ts          ← helpers (formatCurrency, pagination)
    │   └── placeholder-data.ts   ← demo data for seeding
    │
    └── ui/                   ← NOT pages: visual building blocks
        ├── global.css, fonts.ts, skeletons.tsx
        ├── button.tsx, search.tsx, login-form.tsx, acme-logo.tsx
        ├── dashboard/        ← cards, revenue chart, latest invoices, side nav
        ├── invoices/         ← table, forms, pagination, buttons, status badge
        └── customers/        ← customers table
```

### `app/ui` vs `app/lib` vs `app/dashboard`

| Folder | What lives there | Think of it as |
|---|---|---|
| `app/dashboard` (and `login`, `version`) | **Routes**: what URL shows what | The map of the site |
| `app/ui` | **Components**: buttons, tables, forms (the look) | Lego bricks |
| `app/lib` | **Logic and data**: database, rules, helpers | The back office |

A page in `app/dashboard` is mostly *assembly*: it fetches data from `lib`, then arranges bricks from `ui`.

Example, `app/dashboard/invoices/page.tsx`:
```
reads ?query=&page= from the URL
   → asks lib/db.ts for the page count
   → renders <Search> <CreateInvoice> <Table> <Pagination> (all from ui/)
```

> **Watch out:** `app/ui/invoices/page.tsx` exists and is almost a copy of `app/dashboard/invoices/page.tsx`. Because it is named `page.tsx`, Next.js treats it as a **route** at `/ui/invoices`, outside `/dashboard`. Your login rule only protects `/dashboard`, so a logged-out visitor may be able to open it and see the invoices table. Test `/ui/invoices` in a private window. If it loads, delete that file. Shared components must never be called `page.tsx`.

---

## 3. What happens when someone opens a page

Example: a logged-in user opens `/dashboard/invoices?query=acme&page=2`.

```
Browser
  │  GET /dashboard/invoices?query=acme&page=2
  ▼
proxy.ts  ── checks the login cookie (auth.config.ts "authorized")
  │             not logged in → redirect to /login
  ▼
app/layout.tsx                  (root frame: <html>, fonts, CSS)
  ▼
app/dashboard/layout.tsx        (side nav + content area)
  ▼
app/dashboard/invoices/page.tsx (runs ON THE SERVER)
  │   ├─ lib/db.ts  → SQL → Neon Postgres
  │   └─ builds HTML using components from app/ui/
  ▼
HTML sent to the browser  (+ a little JavaScript for the interactive parts)
```

Layouts nest like boxes: root layout → dashboard layout → page. Moving between dashboard pages keeps the side nav in place and swaps only the inner part.

If the page throws, the nearest `error.tsx` above it is shown. If data is still loading, a `Suspense` fallback (your skeletons) shows meanwhile.

---

## 4. Server components vs client components

By default every component runs **only on the server**. It can talk to the database and is never sent to the browser as code. A file starting with `"use client";` runs **in the browser too**, which is needed for clicks, typing and state.

```
                SERVER (default)                    BROWSER ("use client")
                ─────────────────                   ──────────────────────
 can do:        read the database, use secrets      onClick, useState, useEffect
 cannot:        react to clicks                     touch the database or secrets
 in your app:   pages, layouts, tables, cards       search.tsx, pagination.tsx,
                                                    create-form.tsx, edit-form.tsx,
                                                    login-form.tsx, form-error.tsx,
                                                    nav-links.tsx, error.tsx
```

**Why it matters for security:** code that touches the database stays on the server, so the database URL and `AUTH_SECRET` never reach the browser. The exception is any variable starting with `NEXT_PUBLIC_`, which is copied into the browser code. Never put a secret in one.

**Rule of thumb:** keep `"use client"` files small and at the edge (a form, a search box). Keep data fetching in server components.

---

## 5. What happens when someone submits a form

Example: creating an invoice.

```
create-form.tsx  ("use client", has the <form>)
  │  submit → calls createInvoice (a SERVER ACTION)
  ▼
app/lib/actions.ts  ("use server")
  │  1. validate the fields with zod
  │  2. error?  → return { errors, message } → form shows them
  │  3. INSERT into invoices (amount converted to cents)
  │  4. revalidatePath("/dashboard/invoices")  → refresh cached list
  │  5. redirect("/dashboard/invoices")
  ▼
Browser lands on the list, which now shows the new invoice
```

A server action is a function that runs on the server but that a form can call directly. It has **no URL of its own**, which is why it is not part of an OpenAPI spec (see F13 in the enhancement doc). A `route.ts`, like `/version`, does have a URL.

---

## 6. Static vs dynamic pages

When you run `pnpm build`, Next.js decides per route:

| Symbol | Meaning | Yours |
|---|---|---|
| `○` static | Built once at build time, same HTML for everyone | `/`, `/login` |
| `ƒ` dynamic | Built on every request | `/dashboard/*`, `/version` |

Your `dashboard/layout.tsx` sets `export const dynamic = "force-dynamic"` because those pages query the database and sit behind login. Without it, the build would try to read the database while building and could fail or freeze old data into the page.

A static page's text is fixed at build time. That is why `/version` must be dynamic: it reads `process.env.VERSION` when the container runs.

---

## 7. How the code becomes a running container

```
source code ──pnpm build──▶ .next/standalone  (a small self-contained server)
                               │
Dockerfile (multi-stage):      │
  stage 1  install dependencies
  stage 2  run the build  ◀── ARG VERSION is available only at build
  stage 3  "runner": copy standalone output, run as non-root user
                               │
                               ▼
                    image in ECR (tagged with the commit SHA)
                               │
              ECS starts a container: `node server.js`
              + injects secrets from SSM as environment variables
```

- `output: "standalone"` in `next.config.ts` is what makes the output small enough for a slim image.
- `ENV VERSION=$VERSION` in the Dockerfile is why `process.env.VERSION` works at runtime.
- Secrets are **not** in the image. They arrive when the container starts.

---

## 8. Quick lookup: "where do I change X?"

| I want to… | Edit |
|---|---|
| Add a new page, e.g. `/dashboard/reports` | `app/dashboard/reports/page.tsx` |
| Change the side nav links | `app/ui/dashboard/nav-links.tsx` |
| Change the frame around dashboard pages | `app/dashboard/layout.tsx` |
| Change `<html>`, fonts, global CSS | `app/layout.tsx`, `app/ui/global.css` |
| Add a reusable button, card or table | a new file in `app/ui/…` (never named `page.tsx`) |
| Change a SQL query | `app/lib/db.ts` |
| Change validation of the invoice form | `app/lib/actions.ts` (zod schema) |
| Make a URL public or protected | `auth.config.ts` and the `matcher` in `proxy.ts` |
| Add a JSON endpoint | `app/<name>/route.ts` |
| Show something when a page crashes | `error.tsx` in that folder |
| Show a skeleton while loading | `loading.tsx` in that folder, or `<Suspense>` |

---

## 9. One-paragraph interview summary

"It's a Next.js App Router app. Folders under `app/` map to URLs, and nested `layout.tsx` files wrap the pages. Pages are server components that fetch from Postgres, and small client components handle interactivity. Writes go through server actions with zod validation. A proxy protects the dashboard routes. I package it with a multi-stage Dockerfile, so the secrets stay outside the image and are injected at runtime from Parameter Store."
