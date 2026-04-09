# Changelog

All notable changes to oh-my-forge are documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses CalVer (`YYYY.MM.DD`) for releases.

---

## [2026.04.09] -- 2026-04-09

**This is a full v2 rewrite.** Every agent, skill, and script was rebuilt against the verified forgecode source. If you used a previous version of oh-my-forge, treat this as a new install and run `scripts/migrate-from-v1.sh` to carry over your customizations.

### Breaking changes

- **Removed `forge.yaml`.** Replaced with `.forge.toml` at the repo root as the canonical baseline. The old YAML config file was never loaded by forge -- it was a v1 planning mistake. `scripts/migrate-from-v1.sh` converts existing `forge.yaml` installs to TOML.
- **Flattened the `agents/` directory.** Agents previously lived under `agents/core/`, `agents/backend/`, etc. Forge's loader is non-recursive and silently ignored everything in subdirectories. All 40 agents now live flat in `agents/*.md`. Categorization lives in `catalog-manifest.json`.
- **Removed the `tier` field from agent frontmatter.** It was never a real field -- forge ignored it. Use `reasoning.enabled` + `reasoning.effort` to indicate "heavier" agents instead.
- **Removed the `level` field from skill frontmatter.** Skills accept only `name` and `description`. Extra fields cause the skill to fail to load.
- **Removed the `argument-hint` field from skill frontmatter.** Not a real field.
- **Renamed tool references in agent bodies.** Old names like `edit`, `bash`, `grep`, `glob` are replaced with the canonical `patch`, `shell`, `fs_search`. Using old names causes the agent to fail to load.
- **`.mcp.json.example` is now strict JSON.** No comments, no trailing commas. The file validates with `jq` and can be copied directly to `~/forge/.mcp.json`.
- **Installer split into purpose-specific scripts.** `scripts/install-global.sh` is removed. The single `scripts/install.sh` handles user-global, project-local, dry-run, and selective-install modes through flags.

### Added

- **9 new agents**: `critic`, `analyst`, `verifier`, `explorer`, `tracer`, `qa-tester`, `code-simplifier`, `document-specialist`, `git-master`. Total: 40 agents.
- **17 new skills**: `critic`, `verify`, `plan`, `ralplan`, `ai-slop-cleaner`, `cancel`, `explore`, `tracer`, `note`, `recall`, `visual-verdict`, `deep-dive`, `wiki`, `remember`, `skillify`, `release`, `doctor`. Total: 30 skills.
- **`catalog-manifest.json`** at repo root -- single source of truth for the install, doctor, and uninstall scripts, with a companion JSON Schema at `catalog-manifest.schema.json`.
- **`scripts/doctor.sh`** -- validates a user install, a project install, or the oh-my-forge source tree itself.
- **`scripts/uninstall.sh`** -- safely removes oh-my-forge content, preserving user data.
- **`scripts/migrate-from-v1.sh`** -- converts old `forge.yaml` installs to the v2 layout.
- **`scripts/omf-update.sh`** -- updates an existing install in place while preserving marker-bounded customizations.
- **`AGENTS.md` at repo root** -- user-facing project rules auto-loaded by forge. Includes the keyword routing table and commit trailer protocol.
- **`docs/REFERENCE.md`** -- consolidated reference for skills, commands, templates, and tools.
- **`docs/CONFIGURATION.md`** -- `.forge.toml` reference.
- **`docs/MCP.md`** -- MCP server setup guide.
- **`docs/AGENTS.md`** -- contributor documentation for the agent model.
- **`docs/CONTRIBUTING.md`** -- contributing guide.
- **`docs/FORGE_KEYWORDS.md`** -- keyword routing cheat sheet.
- **`plans/README.md`** -- conventions for plan files.
- **`.editorconfig` and `.gitattributes`** for consistent line endings and whitespace.

### Changed

- **Rewrote all 31 existing agents** with verified frontmatter and XML-tagged bodies. Consistent `Purpose / When_To_Use / Method / Rules / Output_Format` structure.
- **Rewrote existing skills** to strip forbidden frontmatter fields. Fixed missing SKILL.md files for `eco`, `turbo`, and `tailwind-v4`.
- **Rewrote `README.md`** from scratch. Target information architecture: TL;DR, install, quick start, catalogs, configuration, commit trailers, keyword routing, doctor, migration, troubleshooting.
- **Rewrote `scripts/install.sh`** with bash 5.3+ style, dry-run support, project-local and user-global install modes, backup of existing config files, explicit `--overwrite` flag.

### Fixed

- Silent broken install where nested agent directories (`agents/core/*.md`) were never loaded by forge.
- Tool name mismatches (`edit`, `bash`, `grep`) that caused agents to fail silently.
- Invalid frontmatter fields on skills that prevented the skill loader from registering them.
- Install script that assumed `~/.forge/` (wrong path -- forge uses `~/forge/`).

### Removed

- `forge.yaml` (wasn't loaded; replaced by `.forge.toml`).
- `scripts/install-global.sh` (merged into `scripts/install.sh --user`).
- Nested agent directory structure (flattened).

### Migration

If you were using a previous version:

```bash
# 1. Back up your customizations
cp ~/forge/.forge.toml ~/forge/.forge.toml.backup 2>/dev/null || true

# 2. Run the migration
git pull origin main
scripts/migrate-from-v1.sh ~/forge

# 3. Verify
scripts/doctor.sh --user
```

The migrate script moves the old `forge.yaml` aside, writes a new `.forge.toml` with sensible defaults, and flattens the agents directory.

---

## [1.x] -- historical

Earlier versions of oh-my-forge shipped `forge.yaml` as the canonical configuration file and organized agents into nested subdirectories. These assumptions did not match the actual forgecode loader behavior and resulted in silently broken installs. The v2 rewrite fixes both issues.

No detailed 1.x changelog is preserved -- treat v2 as a fresh start.
