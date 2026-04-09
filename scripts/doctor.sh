#!/usr/bin/env bash
# oh-my-forge doctor
#
# Checks the oh-my-forge installation and repo layout for common problems.
# Exit 0 if everything looks sane, non-zero otherwise.
#
# Usage:
#   ./scripts/doctor.sh [--global | --project DIR] [--repo]
#
# With --global, checks $HOME/forge.
# With --project DIR, checks DIR/.forge.
# With --repo (default when no target given), checks the repo source tree.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMF_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MODE="repo"   # repo | global | project
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)   MODE="global"; shift ;;
    --project)  MODE="project"; PROJECT_DIR="${2:-}"; shift 2 ;;
    --repo)     MODE="repo"; shift ;;
    -h|--help)
      sed -n '2,14p' "$0"; exit 0 ;;
    *) printf 'unknown arg: %s\n' "$1" >&2; exit 2 ;;
  esac
done

# ---------- tty colours ----------
if [[ -t 1 ]]; then
  R='\033[0m'; B='\033[1m'; G='\033[32m'; Y='\033[33m'; E='\033[31m'
else
  R=''; B=''; G=''; Y=''; E=''
fi

pass=0
warn=0
fail=0

check_pass() { printf '%bPASS%b %s\n' "$G$B" "$R" "$*";          pass=$((pass + 1)); }
check_warn() { printf '%bWARN%b %s\n' "$Y$B" "$R" "$*" >&2;       warn=$((warn + 1)); }
check_fail() { printf '%bFAIL%b %s\n' "$E$B" "$R" "$*" >&2;       fail=$((fail + 1)); }

section() { printf '\n%b== %s ==%b\n' "$B" "$*" "$R"; }

# ---------- Locate target ----------
case "$MODE" in
  repo)
    TARGET_ROOT="$OMF_DIR"
    ;;
  global)
    TARGET_ROOT="${HOME}/forge"
    ;;
  project)
    [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]] || { check_fail "project dir missing: $PROJECT_DIR"; exit 1; }
    TARGET_ROOT="$(cd -- "$PROJECT_DIR" && pwd)/.forge"
    ;;
esac

printf '%bdoctor%b: checking %b%s%b (%s mode)\n' "$B" "$R" "$B" "$TARGET_ROOT" "$R" "$MODE"

# ---------- Tools ----------
section "Tools"

if command -v forge >/dev/null 2>&1; then
  ver="$(forge --version 2>&1 | head -1 || true)"
  check_pass "forge binary: $ver"
else
  check_warn "forge binary not on PATH"
fi

for t in rsync find python3; do
  if command -v "$t" >/dev/null 2>&1; then
    check_pass "$t found"
  else
    check_fail "$t not found"
  fi
done

# ---------- Layout ----------
section "Layout"

if [[ "$MODE" == "repo" ]]; then
  AGENTS_DIR="$TARGET_ROOT/agents"
  SKILLS_DIR="$TARGET_ROOT/skills"
  COMMANDS_DIR="$TARGET_ROOT/commands"
else
  AGENTS_DIR="$TARGET_ROOT/agents"
  SKILLS_DIR="$TARGET_ROOT/skills"
  COMMANDS_DIR="$TARGET_ROOT/commands"
fi

if [[ -d "$AGENTS_DIR" ]]; then check_pass "agents directory exists: $AGENTS_DIR"; else check_fail "missing: $AGENTS_DIR"; fi
if [[ -d "$SKILLS_DIR" ]]; then check_pass "skills directory exists: $SKILLS_DIR"; else check_warn "missing: $SKILLS_DIR"; fi

# ---------- Agents (must be flat) ----------
section "Agents"

if [[ -d "$AGENTS_DIR" ]]; then
  nested_count=0
  while IFS= read -r -d '' _sub; do
    nested_count=$((nested_count + 1))
  done < <(find "$AGENTS_DIR" -mindepth 1 -type d -print0)

  if [[ $nested_count -gt 0 ]]; then
    check_fail "agents contains $nested_count subdirectory(ies) — forgecode does NOT recurse. Files under subdirectories are IGNORED."
  else
    check_pass "agents directory is flat"
  fi

  md_count=0
  while IFS= read -r -d '' _f; do
    md_count=$((md_count + 1))
  done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' -print0)
  check_pass "agents: $md_count *.md files at top level"

  # Frontmatter validation
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$AGENTS_DIR" <<'PY' >/tmp/.omf-doctor-agents.log 2>&1
import os, re, sys
try:
    import yaml
except Exception:
    sys.exit("yaml module not available; install pyyaml to enable deep validation")
base = sys.argv[1]
bad = 0
required = {"id", "title", "description", "tools"}
for fn in sorted(os.listdir(base)):
    if not fn.endswith(".md"): continue
    path = os.path.join(base, fn)
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        print(f"  {fn}: no frontmatter"); bad += 1; continue
    try:
        fm = yaml.safe_load(m.group(1))
    except Exception as e:
        print(f"  {fn}: yaml parse error: {e}"); bad += 1; continue
    miss = required - set(fm or {})
    if miss:
        print(f"  {fn}: missing keys: {sorted(miss)}"); bad += 1; continue
    if not isinstance(fm.get("tools"), list) or not fm["tools"]:
        print(f"  {fn}: tools must be a non-empty list"); bad += 1; continue
if bad:
    print(f"{bad} agent(s) failed validation"); sys.exit(1)
print("all agents validated")
PY
    then
      check_pass "$(head -1 /tmp/.omf-doctor-agents.log)"
    else
      check_fail "agent frontmatter validation failed:"
      while IFS= read -r line; do printf '  %s\n' "$line"; done < /tmp/.omf-doctor-agents.log
    fi
    rm -f /tmp/.omf-doctor-agents.log
  else
    check_warn "python3 not available; skipping deep agent validation"
  fi
fi

# ---------- Skills ----------
section "Skills"

if [[ -d "$SKILLS_DIR" ]]; then
  skill_count=0
  bad_skill=0
  for d in "$SKILLS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    skill_count=$((skill_count + 1))
    if [[ ! -f "$d/SKILL.md" ]]; then
      check_fail "skill missing SKILL.md: $(basename "$d")"
      bad_skill=$((bad_skill + 1))
    fi
  done
  if [[ $skill_count -eq 0 ]]; then
    check_warn "no skills found under $SKILLS_DIR"
  elif [[ $bad_skill -eq 0 ]]; then
    check_pass "skills: $skill_count skill dir(s), all have SKILL.md"
  fi
fi

# ---------- Commands (must be flat if present) ----------
section "Commands"

if [[ -d "$COMMANDS_DIR" ]]; then
  nested=0
  while IFS= read -r -d '' _sub; do
    nested=$((nested + 1))
  done < <(find "$COMMANDS_DIR" -mindepth 1 -type d -print0)
  if [[ $nested -gt 0 ]]; then
    check_fail "commands contains subdirectories — forgecode does NOT recurse"
  else
    cmd_count=0
    while IFS= read -r -d '' _f; do
      cmd_count=$((cmd_count + 1))
    done < <(find "$COMMANDS_DIR" -maxdepth 1 -type f -name '*.md' -print0)
    check_pass "commands: $cmd_count *.md files, flat"
  fi
else
  check_warn "no commands directory (optional)"
fi

# ---------- Config files ----------
section "Config files"

if [[ "$MODE" == "repo" ]]; then
  if [[ -f "$TARGET_ROOT/.forge.toml" ]]; then check_pass ".forge.toml present"; else check_warn ".forge.toml absent"; fi
  if [[ -f "$TARGET_ROOT/.mcp.json.example" ]]; then check_pass ".mcp.json.example present"; else check_warn ".mcp.json.example absent"; fi
  if [[ -f "$TARGET_ROOT/AGENTS.md" ]]; then check_pass "AGENTS.md present"; else check_warn "AGENTS.md absent"; fi

  if [[ -f "$TARGET_ROOT/.forge.toml" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      if python3 -c "import tomllib; tomllib.load(open('$TARGET_ROOT/.forge.toml','rb'))" 2>/dev/null; then
        check_pass ".forge.toml parses as TOML"
      else
        check_fail ".forge.toml fails to parse as TOML"
      fi
    fi
  fi

  if [[ -f "$TARGET_ROOT/.mcp.json.example" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      if python3 -c "import json; json.load(open('$TARGET_ROOT/.mcp.json.example'))" 2>/dev/null; then
        check_pass ".mcp.json.example parses as JSON"
      else
        check_fail ".mcp.json.example fails to parse as JSON"
      fi
    fi
  fi

  if [[ -f "$TARGET_ROOT/forge.yaml" ]]; then
    check_fail "forge.yaml is present — this format is obsolete; remove it and use .forge.toml"
  else
    check_pass "no legacy forge.yaml"
  fi
fi

# ---------- Forbidden strings sweep ----------
if [[ "$MODE" == "repo" ]]; then
  section "Forbidden strings sweep"
  forbidden=(
    "ralph_loop"
    "autopilot_mode"
    "turbo_mode"
    "max_walker_depth"
    "disallowedTools"
    'tier: standard'
    'tier: heavy'
    'tier: fast'
  )
  hits=0
  for token in "${forbidden[@]}"; do
    if grep -Rqs --include='*.md' --include='*.yaml' --include='*.yml' -F -- "$token" \
         "$TARGET_ROOT/agents" "$TARGET_ROOT/skills" "$TARGET_ROOT/commands" 2>/dev/null; then
      check_fail "forbidden string found: '$token'"
      hits=$((hits + 1))
    fi
  done
  [[ $hits -eq 0 ]] && check_pass "no forbidden strings in agents/skills/commands"
fi

# ---------- Summary ----------
section "Summary"
printf '  pass: %b%d%b\n' "$G$B" "$pass" "$R"
printf '  warn: %b%d%b\n' "$Y$B" "$warn" "$R"
printf '  fail: %b%d%b\n' "$E$B" "$fail" "$R"

if [[ $fail -gt 0 ]]; then
  exit 1
fi
exit 0
