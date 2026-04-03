---
name: docker
description: Production-grade Docker configurations (Dockerfile, Compose, best practices)
argument-hint: "<dockerization request>"
level: 2
---

# Docker Skill

Use this skill when user explicitly requests Docker configurations.

## When to Use

- User says: "dockerize", "add docker", "create a Dockerfile", "docker-compose"
- User wants to containerize an application
- User asks about Docker best practices

**Trigger**: `docker:` prefix or explicit Docker request

## What This Skill Provides

Based on [Docker Official Best Practices](https://docs.docker.com/build/building/best-practices/).

### Files to Create

| File | When |
|------|------|
| `Dockerfile` | Application containerization |
| `.dockerignore` | Exclude unnecessary files |
| `docker-compose.yml` | Multi-container orchestration |
| `docker-compose.override.yml` | Dev-specific overrides |
| `compose.yaml` | Compose v2 format |

### Common Deliverables

1. **Multi-stage Dockerfile** with build/production stages
2. **.dockerignore** to reduce image size
3. **docker-compose.yml** with:
   - Health checks
   - Resource limits
   - Named volumes
   - Networks
   - Secrets (for sensitive data)
4. **Security best practices**:
   - Non-root user
   - Minimal base images
   - No secrets in image

## Steps

1. **Analyze Requirements**
   - Language/runtime of the application
   - Dependencies and ports
   - Environment variables needed
   - Persistent data requirements
   - Health check endpoint available?

2. **Create Dockerfile**
   - Choose appropriate base image
   - Multi-stage build pattern
   - Non-root user
   - Healthcheck directive
   - Labels for metadata

3. **Create .dockerignore**
   - Dependencies (node_modules, etc.)
   - Build outputs
   - Git and IDE files
   - Environment files

4. **Create docker-compose.yml**
   - Service definitions
   - Volume mounts
   - Network configuration
   - Resource limits
   - Health checks

5. **Verify**
   - `docker build` succeeds
   - `docker compose up` works
   - Health checks pass
   - No security warnings

## Examples

<Good>
User: "dockerize this Node.js API"
Why good: Clear request with specific tech stack
</Good>

<Good>
User: "add Docker support for the frontend app"
Why good: Explicit Docker request
</Good>

<Bad>
User: "fix the login bug"
Why bad: No Docker involved
</Bad>

<Bad>
User: "build me a web app" (without Docker mention)
Why bad: Docker not explicitly requested
</Bad>

## Related Skills

| Skill | Use When |
|-------|----------|
| `@deploy-engineer` | Full deployment with Docker |
| `@infra-planner` | Infrastructure design |
| `@dep-auditor` | Check for vulnerabilities |

## Documentation

See `skills/docker/DOCKERFILE.md` for:
- Complete Dockerfile patterns
- Docker Compose best practices
- Security checklist
- Multi-stage build examples
- Commands reference
