# specify the node base image with your desired version node:<version>
FROM node:22-alpine AS base
RUN corepack enable
# goes to the app directory, like a cd terminal command
WORKDIR /app


# Dependencies
FROM base AS deps 
RUN apk add --no-cache libc6-compat

COPY package*.json pnpm-lock.yaml ./

# ci (clean install) used instead of install bc it is faster, more reliable, strictly follows package log json
# downloading dependency first before we get our code -copied the package.json and install those app dependencies
RUN pnpm install

# Builder

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules

# copy our code into the image but without ^node_modules dir and file because it's really big^
COPY . .

RUN pnpm build

# Runner 
FROM base AS runner
ENV NODE_ENV=production

# Secuirty

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Runner - ensures docker exposes app to the outside world
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
