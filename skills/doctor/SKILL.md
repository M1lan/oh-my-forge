---
name: doctor
description: Diagnose the local oh-my-forge installation. Checks that `forge` is installed, the correct version, that `~/forge/` and `.forge/` are structured correctly, that agents/skills/commands have valid frontmatter, that `.forge.toml` parses, that `.mcp.json` is valid if present, and that all installed agents and skills match the catalog-manifest. Use when "forge list" shows nothing, when a skill or agent fails to load, or when verifying a fresh install.
---

# Doctor

Diagnose why forge is not behaving the way oh-my-forge says it should.

## When to invoke

- User says "forge doctor", "check my install", "something is broken".
- `forge list agent` or `forge list skill` shows fewer items than expected.
- A skill or agent fails to load or is missing.
- After a fresh install to verify correctness.
- Before reporting a bug to the oh-my-forge maintainers.

## Workflow

This skill is the documentation counterpart to `scripts/doctor.sh`. When invoked, first check whether the script is present in the repo being diagnosed:

1. **If `scripts/doctor.sh` exists**, run it:
   ```bash
   scripts/doctor.sh --user
   scripts/doctor.sh --project .
   scripts/doctor.sh --repo    # if diagnosing the oh-my-forge source repo itself
   ```
   The script performs all checks automatically and reports a concrete PASS/FAIL table plus a non-zero exit code if any check fails.

2. **If `scripts/doctor.sh` does NOT exist** (user is running forge against a non-oh-my-forge project), fall back to manual checks below.

## Manual checks (fallback)

Run each and report the result.

### Binary and version

```bash
command -v forge                  # expect: path to forge binary
forge --version                   # expect: forge 2.x.y
```

### Paths

```bash
ls -la ~/forge/                   # expect: .forge.toml, agents/, skills/, commands/, snapshots/, .forge.db, .mcp.json
ls -la ~/forge/agents/ | wc -l    # expect: N > 0 (flat layout, no subdirs)
find ~/forge/agents/ -type d      # expect: just ~/forge/agents itself; no nested dirs
ls -la ~/forge/skills/            # expect: one directory per skill
```

### Configuration

```bash
python3 -c "import tomllib; tomllib.load(open('$HOME/forge/.forge.toml','rb')); print('OK')"
```

### MCP (if present)

```bash
if [ -f "$HOME/forge/.mcp.json" ]; then
  jq . < "$HOME/forge/.mcp.json" > /dev/null && echo "OK: .mcp.json parses"
fi
```

### Agent frontmatter

For each `~/forge/agents/*.md`, confirm the file has a YAML frontmatter block with at least `id`, `title`, `description`, and `tools` (non-empty list).

### Skill frontmatter

For each `~/forge/skills/*/SKILL.md`, confirm the file has YAML frontmatter with exactly two fields: `name` and `description`.

### Live listing

```bash
forge list agent | head -20       # expect: all agents loaded
forge list skill | head -20       # expect: all skills loaded
```

## Common failures and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `forge list agent` shows only `forge/muse/sage` | agents in subdirectories | flatten to `~/forge/agents/*.md` (no subdirs) |
| Skill not listed | missing `SKILL.md` or bad frontmatter | ensure `skills/<name>/SKILL.md` exists with valid `name`/`description` frontmatter only |
| `.forge.toml` parse error | invalid TOML | re-copy from oh-my-forge repo and merge customizations |
| `.mcp.json` parse error | malformed JSON (comments, trailing commas) | JSON is strict -- remove comments, validate with `jq` |
| Agent body not rendering | missing closing `---` on frontmatter | ensure frontmatter is terminated correctly |
| Custom tool name in agent | old tool names (e.g. `edit` instead of `patch`) | see `docs/REFERENCE.md` for the valid tool catalog |

## Output format

```
## Doctor Report

### Binary
- forge: /usr/local/bin/forge -- 2.8.0  [PASS]

### Paths
- ~/forge/.forge.toml                    [PASS]
- ~/forge/agents/ (flat, 31 files)       [PASS]
- ~/forge/skills/ (29 dirs)              [PASS]

### Configuration
- .forge.toml parses                     [PASS]
- .mcp.json parses                       [PASS]

### Frontmatter
- 31 agents validated                    [PASS]
- 29 skills validated                    [FAIL -- tailwind-v4 missing SKILL.md]

### Live listing
- forge list agent: 31 shown             [PASS]
- forge list skill: 28 shown             [FAIL -- tailwind-v4 not loaded]

### Summary
PASS: 8 / 10
FAIL: 2 / 10

### Next steps
1. Create skills/tailwind-v4/SKILL.md with valid frontmatter.
2. Re-run: forge list skill
```

## Anti-patterns

- Fixing symptoms without running the script / checks first.
- Silently "adapting" layout differences instead of reporting them.
- Declaring PASS without running the actual check.
