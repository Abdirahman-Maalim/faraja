# STAGE 1: Builder
FROM node:18-alpine3.21 AS builder

LABEL maintainer="teqiee"
LABEL description="Faraja frontend builder stage"
LABEL version="1.0.0"

WORKDIR /app

# Copy package files first (for caching)
COPY package*.json ./

# Install dependencies with cache optimization
RUN npm ci --no-cache

# Copy source code
COPY . .

# Build the application
RUN npm run build

# STAGE 2: Runner (Production)
FROM node:18-alpine3.21 AS runner

LABEL maintainer="teqiee"
LABEL description="Faraja frontend production image"
LABEL version="1.0.0"

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

# Set environment variables
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user (Alpine uses -G for group)
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 -G nodejs nextjs

# Copy built assets from builder
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev --no-cache

# Switch to non-root user
USER nextjs

# Expose port (Next.js default port)
EXPOSE 3000

# Healthcheck using curl (more reliable)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

# Start the application
CMD ["npm", "start"]