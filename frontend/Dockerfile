# syntax=docker/dockerfile:1.7
# check=error=true

# STAGE 1: Dependencies
FROM node:18-alpine3.21 AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm ci

# STAGE 2: builder 
FROM node:18-alpine3.21 AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_API_BASE_URL=/api
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_TELEMETRY_DISABLED=1

# runs setup commands
RUN npm run build

# removes build-only tools (package.json unchanged)
RUN rm -rf \
      node_modules/typescript \
      node_modules/eslint \
      node_modules/eslint-config-next \
      node_modules/tailwindcss \
      node_modules/postcss \
      node_modules/autoprefixer \
      node_modules/@types \
      node_modules/.bin/tsc \
      node_modules/.bin/eslint \
      node_modules/.bin/tailwindcss
      
# STAGE 3: Runner (Production)
FROM node:18-alpine3.21 AS runner

LABEL org.opencontainers.image.title="faraja-frontend"
LABEL org.opencontainers.image.description="Faraja Next.js frontend"
LABEL org.opencontainers.image.source="https://github.com/Abdirahman-Maalim/faraja"

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3001

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 -G nodejs nextjs

# Copy built app AND node_modules directly from builder 
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules     ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json     ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/next.config.mjs  ./next.config.mjs

USER nextjs

EXPOSE 3001

# Healthcheck targeted at port 3001 (matches "start": "next start -p 3001")
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3001 || exit 1

CMD ["npm", "start"]
