# Git Batch Operations

Safe patterns for automated git operations across repositories.

## Contents

- [Pre-mutation checklist](#pre-mutation-checklist)
- [Cleaning a repo safely](#cleaning-a-repo-safely)
- [Branch-based mutations](#branch-based-mutations)
- [Commit safety](#commit-safety)
- [Push safety](#push-safety)
- [stderr suppression rules](#stderr-suppression-rules)
- [Symlink handling in git](#symlink-handling-in-git)
- [Symlink repair pattern](#symlink-repair-pattern)
- [Pure Bash JSON for API responses](#pure-bash-json-for-api-responses)
- [glab CLI patterns](#glab-cli-patterns)
- [Batch processing template](#batch-processing-template)

## Pre-mutation checklist

Before touching any repo:

1. `[[ -d $repo_dir ]]` -- directory exists
2. Verify required files exist (abort entire run if critical)
3. `git -C "$dir" rev-parse --git-dir` -- valid git repo
4. `glab auth status >/dev/null 2>&1` -- authenticated (if using GitLab API)

## Cleaning a repo safely

Order matters. Stash BEFORE checkout, fetch BEFORE pull:

```bash
# 1. detect current state
current_branch=$(git -C "$dir" branch --show-current)
[[ -z $current_branch ]] && current_branch="DETACHED"

# 2. stash if dirty (staged + unstaged + untracked)
if [[ -n $(git -C "$dir" status --porcelain) ]]; then
  git -C "$dir" stash push -u \
    -m "auto-stash (was: ${current_branch})"
fi

# 3. switch to target branch
if [[ $current_branch != main ]]; then
  git -C "$dir" checkout main
fi

# 4. sync
git -C "$dir" fetch --all --prune --quiet
git -C "$dir" pull --ff-only origin main \
  || git -C "$dir" pull --rebase origin main
```

Safety rules:

- NEVER `git clean -fd` or `git checkout .` (destroys work)
- NEVER `git reset --hard` (destroys work)
- ALWAYS `stash push -u` (saves untracked too)
- ALWAYS include descriptive stash message with branch name
- Handle detached HEAD (empty string from `--show-current`)

## Branch-based mutations

```bash
# create or reuse
git -C "$dir" checkout -b "$branch" 2>/dev/null \
  || git -C "$dir" checkout "$branch"

# ... make changes ...

# merge back (ff preferred)
git -C "$dir" checkout main
if git -C "$dir" merge --ff-only "$branch"; then
  git -C "$dir" branch -d "$branch"
else
  err "merge failed, branch '$branch' preserved"
fi
```

NEVER delete a branch after failed merge. User needs it for recovery.

## Commit safety

- `--no-verify`: skip hooks for trivial changes (symlinks, config). Hooks cause
  false failures on non-code.
- NEVER `--amend` in batch ops (rewrites history on wrong commit)
- NEVER `-a` flag (stages unintended files)
- Stage specific files: `git add file1 file2`

## Push safety

- ALWAYS `--force-with-lease` never `--force`
- `--force-with-lease` fails if remote has unfetched commits
- Show stderr on push (auth errors, protected branch)

## stderr suppression rules

| Suppress stderr | Show stderr |
|----------------|-------------|
| `fetch --quiet` | checkout |
| branch creation fallback (`2>/dev/null`) | commit |
| `diff --cached --quiet` (exit code is signal) | push |
| `status --porcelain` (output is signal) | `pull --rebase` |

## Symlink handling in git

Git stores symlink target as file content. `CLAUDE.md -> AGENTS.md` stored as
string "AGENTS.md".

- Symlinks are safe to commit and push
- Cross-platform (git recreates on checkout)
- `git add symlink` stages target path, not target file
- `git diff --cached` shows mode 120000 for symlinks

Always use relative paths in committed symlinks:

```bash
ln -s AGENTS.md CLAUDE.md                          # same dir
ln -s ../AGENTS.md .github/copilot-instructions.md  # one level up
```

NEVER absolute paths in committed symlinks (breaks on other machines).

## Symlink repair pattern

```bash
if [[ -L "$path" ]]; then
  target=$(readlink "$path")
  if [[ $target != "$expected" ]]; then
    rm "$path"
    ln -s "$expected" "$path"
  fi
elif [[ -f "$path" ]]; then
  rm "$path"
  ln -s "$expected" "$path"
else
  ln -s "$expected" "$path"
fi
```

Check `-L` FIRST, then `-f`. (`-f` returns true for symlinks if target exists.)

## Pure Bash JSON for API responses

For simple key-value extraction without jq:

```bash
json_val() {
  local json=$1 key=$2
  if [[ $json =~ \"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "?"
  fi
}
```

Strings only, no escaped quotes, first occurrence. Use jq for complex JSON.

## glab CLI patterns

```bash
# auth check (run in preflight)
glab auth status >/dev/null 2>&1 || { err "not authenticated"; exit 1; }

# API queries (inside repo dir, :id resolves automatically)
info=$(cd "$repo_dir" && glab api projects/:id)
```

When to use glab vs git:

- glab: API queries (project info, MR status, pipelines, members)
- git: all local ops (checkout, fetch, pull, commit, push, stash)

glab wraps git for some ops but adds no value for local work.

## Batch processing template

Abstract pattern for "do X across N repos":

```bash
REPOS_DIR="${1:-$HOME/repos}"
REPOS=(repo-a repo-b repo-c)

# 1. preflight: tools exist, auth works, dirs exist
# 2. verify: required files present in all repos
# 3. for each repo: clean -> switch to main -> sync
# 4. for each repo: create branch -> make changes -> stage
# 5. summarize: show all changes, get user approval
# 6. for each repo: commit
# 7. for each repo: merge to main (keep branch on failure)
# 8. for each repo: push (with user approval)
# 9. report: changed / clean / failed counts
```

Principles:

- Verify everything before mutating anything
- Separate stage from commit (user reviews)
- Separate commit from push (user approves)
- Track failures, skip failed in later phases, report at end
- Every confirm gate is a safe exit point
