---
name: release
description: Prepare and execute a clean release. Bumps version, updates CHANGELOG.md, creates a signed tag, writes release notes from commits, and optionally drafts a GitHub release. Use when the user says "cut a release", "ship v1.2.3", "tag a release", or when a version bump is the next step after merging changes.
---

# Release

Turn a merged set of changes into a clean, tagged, documented release.

## When to invoke

- User says "cut a release", "tag v1.2.3", "ship a release", "prepare a release".
- A feature branch or milestone has been merged and needs to be shipped.
- A hotfix needs a patch version bump.

## Pre-flight checks (BLOCKING)

Stop and refuse to proceed if any of these fail:

1. **Clean working tree.** `git status --porcelain` must be empty. If not, tell the user and stop.
2. **On the release branch.** Usually `main` or `master`. If not, ask.
3. **Up to date.** `git fetch && git status -sb` shows no divergence from upstream.
4. **Tests pass.** Run the project's test command. If it fails, stop.
5. **Build succeeds.** Run the project's build/typecheck. If it fails, stop.
6. **Version scheme identified.** SemVer? CalVer? Read `package.json` / `Cargo.toml` / `pyproject.toml` / existing tags to infer.

## Workflow

1. **Determine the next version.** Based on the changes since the last tag:
   - Breaking changes -> major bump
   - New features -> minor bump
   - Bugfixes only -> patch bump
   - Ask the user to confirm.
2. **Generate release notes.** `git log <last-tag>..HEAD --oneline --no-merges` -- group into Features / Fixes / Chore / Breaking. Clean up commit messages for the changelog.
3. **Update `CHANGELOG.md`.** Prepend a new section:

   ```markdown
   ## [v1.2.3] -- YYYY-MM-DD

   ### Breaking changes

   - ...

   ### Features

   - ...

   ### Fixes

   - ...

   ### Chore

   - ...
   ```

4. **Bump the version** in the project manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, `VERSION`, etc.). Do it in every place the version appears -- grep to find them all.
5. **Commit.** `git commit -am "chore(release): v1.2.3"` -- do not use vague messages.
6. **Tag.** `git tag -s v1.2.3 -m "v1.2.3"` (signed, with annotated message). If no GPG key is configured, use `-a` instead and warn the user.
7. **Push.** `git push && git push --tags`.
8. **Draft GitHub release** (optional, only if `gh` CLI is available and user wants it): `gh release create v1.2.3 --notes-file /tmp/release-notes.md`.
9. **Report.**

## Rules

- NEVER tag if tests or build fail.
- NEVER tag from a dirty working tree.
- NEVER force-push a tag. If the tag is wrong, delete it and make a new version.
- ALWAYS update the CHANGELOG. An untracked release is a broken release.
- ALWAYS use annotated tags (`-a` or `-s`), never lightweight tags.
- ALWAYS bump the version in every manifest file -- out-of-sync version numbers are a common footgun.

## Output

```text
## Release: v1.2.3

### Pre-flight
- Working tree: clean
- Branch: main (up to date with origin/main)
- Tests: PASS
- Build: PASS

### Changes since v1.2.2
- Features: 3 (f1, f2, f3)
- Fixes: 2 (fix1, fix2)
- Breaking: 0

### Actions taken
- CHANGELOG.md: prepended v1.2.3 section
- package.json: 1.2.2 -> 1.2.3
- Committed as <sha> "chore(release): v1.2.3"
- Tagged v1.2.3 (signed)
- Pushed to origin
- GitHub release drafted: <url>

### Next step
Monitor CI for the release pipeline, then announce.
```
