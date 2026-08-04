# STAGE 1: Builder
FROM node:18-alpine3.21 AS builder

LABEL maintainer="teqiee"
LABEL description="Faraja frontend builder stage"
LABEL version="1.0.0"

WORKDIR /app

COPY package*.json ./

RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000

RUN npm ci

COPY . .

# Accept the API base URL at build time so it's baked into client-side JS
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL

RUN npm run build

# STAGE 2: Runner (Production)
FROM node:18-alpine3.21 AS runner

LABEL maintainer="teqiee"
LABEL description="Faraja frontend production image"
LABEL version="1.0.0"

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 -G nodejs nextjs

# Copy built app AND node_modules directly from builder (prevents 2nd npm ci hang)
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package*.json ./

USER nextjs

EXPOSE 3001

# Healthcheck targeted at port 3001 (matches "start": "next start -p 3001")
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3001 || exit 1

CMD ["npm", "start"]
