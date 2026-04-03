# Docker Skill

> "Production-grade Docker configurations following official best practices."

## When to Use

Use when explicitly requested:
- User says "docker", "add docker", "dockerize", "containerize"
- User wants a Dockerfile or docker-compose.yml
- User wants to optimize an existing Docker setup

**Do NOT auto-trigger** - only use when user explicitly asks for Docker.

## Reference

Based on [Docker Official Best Practices](https://docs.docker.com/build/building/best-practices/).

---

## Dockerfile Best Practices

### 1. Choose Minimal Base Images

```dockerfile
# ✅ Good - minimal, security-focused
FROM node:20-alpine

# ❌ Bad - large, includes unnecessary stuff
FROM node:20
```

**Minimal images** (by size):
| Image | Size | Use Case |
|-------|------|----------|
| `scratch` | 0 | Static binaries only |
| `distroless` | ~2MB | Production apps (no shell) |
| `alpine` | ~3MB | Lightweight with package manager |
| `debian-slim` | ~30MB | When Alpine has compatibility issues |

### 2. Use Specific Version Tags

```dockerfile
# ✅ Good - reproducible
FROM node:20.11.0-alpine

# ❌ Bad - changes over time
FROM node:latest
FROM node:20
```

### 3. Combine RUN Commands (Layer Optimization)

```dockerfile
# ✅ Good - single layer, cache cleaned
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

# ❌ Bad - separate layers, bloated
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
```

### 4. Order Instructions (Most Static First)

```dockerfile
# ✅ Good - cache rebuilt only when code changes
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "index.js"]

# ❌ Bad - cache invalidated on any file change
COPY . .
RUN npm ci
CMD ["node", "index.js"]
```

### 5. Use COPY Over ADD

```dockerfile
# ✅ Good - explicit, no magic
COPY --chown=node:node . /app

# Use ADD only for:
# - Fetching from URLs
# - Extracting tar files
ADD https://example.com/bundle.tar.gz /app
```

### 6. Set User and Permissions

```dockerfile
# Create non-root user
RUN groupadd --gid 1000 node && \
    useradd --uid 1000 --gid node --shell /bin/sh --create-home node

# Switch to non-root user
USER node

# Or at build stage
COPY --chown=node:node dist/ /app
```

### 7. Use Multi-Stage Builds

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

### 8. Use .dockerignore

```gitignore
# Dependencies
node_modules
npm-debug.log

# Build outputs
dist
build

# Git
.git
.gitignore

# IDE
.vscode
.idea

# Environment
.env
.env.*

# Docs
README.md
LICENSE

# Docker
Dockerfile
docker-compose.yml
.dockerignore
```

### 9. Healthcheck

```dockerfile
# For Node.js
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# For Go
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
```

### 10. Labels

```dockerfile
LABEL org.opencontainers.image.title="My App"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Production application"
LABEL maintainer="dev@example.com"
```

---

## Docker Compose Best Practices

### 1. Use Version Specification

```yaml
version: "3.9"  # Always specify version
services:
  app:
    image: app:1.0.0
```

### 2. Separate Dev vs Production

```yaml
# docker-compose.yml (base)
services:
  app:
    build: .
    restart: unless-stopped

# docker-compose.override.yml (dev)
services:
  app:
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    ports:
      - "3000:3000"
```

### 3. Use Named Volumes

```yaml
services:
  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: user
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

volumes:
  postgres_data:
```

### 4. Use Secrets for Sensitive Data

```yaml
services:
  app:
    image: app:1.0.0
    secrets:
      - db_password
    environment:
      - DATABASE_PASSWORD=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### 5. Health Checks

```yaml
services:
  app:
    image: app:1.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s

  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### 6. Resource Limits

```yaml
services:
  app:
    image: app:1.0.0
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 256M
```

### 7. Networks

```yaml
services:
  frontend:
    image: frontend:1.0.0
    networks:
      - web
      - internal

  backend:
    image: backend:1.0.0
    networks:
      - internal
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:15-alpine
    networks:
      - internal
    volumes:
      - db_data:/var/lib/postgresql/data

networks:
  web:
    driver: bridge
  internal:
    driver: bridge
    internal: true

volumes:
  db_data:
```

---

## Security Checklist

- [ ] Use non-root user (`USER` directive)
- [ ] Use minimal base images (Alpine, distroless)
- [ ] No secrets in Dockerfile or image
- [ ] Use `COPY` instead of `ADD`
- [ ] Clean package manager caches
- [ ] Scan images for CVEs (`docker scout`)
- [ ] Use specific version tags
- [ ] Enable Docker BuildKit (`DOCKER_BUILDKIT=1`)
- [ ] Use `.dockerignore`
- [ ] Set resource limits in Compose

---

## Common Patterns

### Node.js Production

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
CMD ["node", "index.js"]
```

### Python (FastAPI)

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --no-cache -r requirements.txt

FROM python:3.12-slim AS production
WORKDIR /app
RUN adduser --system --no-create-home --disabled-login appuser
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .
ENV PATH=/home/appuser/.local/bin:$PATH
USER appuser
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go Binary

```dockerfile
# Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server

# Runtime (distroless - no shell)
FROM gcr.io/distroless/static-debian12 AS production
COPY --from=builder /app/server /
EXPOSE 8080
ENTRYPOINT ["/server"]
```

---

## Commands Reference

```bash
# Build with BuildKit (recommended)
DOCKER_BUILDKIT=1 docker build -t app:1.0.0 .

# Build multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t app:1.0.0 --push .

# Scan for vulnerabilities
docker scout cves app:1.0.0

# Prune unused resources
docker system prune -af
docker volume prune -f

# View image layers
docker history app:1.0.0

# Multi-stage cleanup
docker builder prune
```
