# Contributing to oh-my-forge

Thanks for your interest. oh-my-forge is a content pack for ForgeCode (`forge`) -- we only ship markdown, JSON, TOML, and shell scripts. No Rust, no TypeScript, no framework to learn.

---

## Prerequisites

- `forge >= 2.5.2` (2.8.0 recommended)
- `bash >= 5`
- `python3` (for validation scripts)
- `jq` (for JSON validation)
- `rsync` (for the installer)
- `shellcheck` (recommended)

---

## Repository layout

```text
oh-my-forge/
├── README.md
├── AGENTS.md                  # User-facing project rules (auto-loaded by forge)
├── .forge.toml                # Baseline .forge.toml that users can copy
├── .mcp.json.example          # Example MCP config
├── .editorconfig
├── .gitattributes
├── CHANGELOG.md
├── catalog-manifest.json      # Single source of truth for install/doctor
├── catalog-manifest.schema.json
├── agents/                    # FLAT layout (no subdirs)
│   ├── architect.md
│   ├── executor.md
│   └── ...
├── skills/                    # Each skill is a subdirectory
│   ├── plan/
│   │   └── SKILL.md
│   └── ...
├── commands/                  # Slash commands (FLAT layout)
│   └── ...
├── templates/                 # Template overrides for forge's built-ins
│   └── ...
├── scripts/
│   ├── install.sh
│   ├── doctor.sh
│   ├── uninstall.sh
│   ├── migrate-from-v1.sh
│   └── omf-update.sh
├── docs/
│   ├── AGENTS.md              # Contributor docs for the agent model
│   ├── REFERENCE.md           # Skills / commands / templates / tools
│   ├── CONFIGURATION.md       # .forge.toml reference
│   ├── MCP.md                 # MCP setup
│   ├── CONTRIBUTING.md        # This file
│   └── FORGE_KEYWORDS.md      # Keyword routing cheat sheet
├── plans/
│   └── README.md
└── examples/
    └── laravel-vue/
```

---

## Adding a new agent

See [`docs/AGENTS.md`](./AGENTS.md) for the full agent schema. Short version:

1. Create `agents/<name>.md` with frontmatter + XML-tagged body.
2. `id` must match the filename (kebab case).
3. `tools` must only contain names from the canonical tool catalog (see [`REFERENCE.md#tools`](./REFERENCE.md#tools)).
4. Add an entry to `catalog-manifest.json`.
5. Run `scripts/doctor.sh --repo` to validate.
6. Optionally add a row to `docs/FORGE_KEYWORDS.md` if the agent has natural-language triggers.

---

## Adding a new skill

See [`docs/REFERENCE.md#skills`](./REFERENCE.md#skills). Short version:

1. Create `skills/<name>/SKILL.md`.
2. Frontmatter must have **only** `name` and `description`. Extras are rejected.
3. Description must be 50-500 chars and include both WHAT the skill does AND WHEN to invoke it.
4. Body uses the `When to invoke / Workflow / Rules / Output` sections.
5. Add bundled resources under `skills/<name>/` if needed.
6. Add an entry to `catalog-manifest.json`.
7. Run `scripts/doctor.sh --repo`.

---

## Adding a new command

1. Create `commands/<name>.md` with frontmatter (`name`, `description`) and a prompt body.
2. Use `{{parameters}}` for user arguments (NOT `{{args}}`).
3. Add an entry to `catalog-manifest.json`.
4. Run `scripts/doctor.sh --repo`.

---

## Adding a template override

1. Create `templates/<template-name>.md`. Name must match the forge built-in being overridden.
2. Start with a comment explaining it is an override.
3. Use marker-bounded sections for customizable regions:

   ```text
   <!-- OMF:TEMPLATE:DOOM_LOOP:START -->
   Your content here
   <!-- OMF:TEMPLATE:DOOM_LOOP:END -->
   ```

4. Add an entry to `catalog-manifest.json` under `templates`.

---

## Running the doctor

Before every PR:

```bash
scripts/doctor.sh --repo
```

Expected: `pass: N, warn: *, fail: 0`.

---

## Running shellcheck

```bash
shellcheck scripts/*.sh
```

Zero warnings is the bar.

---

## Cutting a release

Use the `release` skill from within a forge session, or manually:

1. Update `CHANGELOG.md` with the new version section.
2. Bump `catalogVersion` in `catalog-manifest.json` to today's date (CalVer).
3. Commit: `git commit -am "chore(release): 2026.04.09"`.
4. Tag: `git tag -s 2026.04.09 -m "2026.04.09"`.
5. Push: `git push && git push --tags`.
6. Draft GitHub release (optional): `gh release create 2026.04.09 --notes-file CHANGELOG.md`.

---

## Coding / writing style

- **No emoji in ships.** Only use emoji if the user explicitly requests them.
- **No AI slop.** No "It is important to note", "In today's fast-paced world", "delve into the complexities", em-dash spam. See the `ai-slop-cleaner` skill.
- **Cite code with `path:line`**. `src/auth.ts:42-58`.
- **Imperative voice in rules.** "Do X", "Never Y".
- **Concrete examples** over abstract descriptions.
- **Bash 5.3+** for shell scripts.

---

## Reporting issues

Before filing an issue, run:

```bash
scripts/doctor.sh --user       # or --project .
forge --version
```

Include the full doctor output and the forge version in the issue.

---

## Philosophy

- **Content-only.** We ship markdown, JSON, TOML, and bash. No forge fork.
- **Verified against source.** Every frontmatter field, every tool name, every config key in oh-my-forge is checked against forgecode source, not inferred.
- **Doctor-first.** If the doctor fails, we fix it before shipping. No broken state allowed.
- **Flat layouts.** forge's loader is non-recursive -- flat directories only.
- **Description-as-trigger.** Skills and commands use their `description` field as the routing signal. Write descriptions that include both capability AND trigger phrases.
- **No launcher wrappers.** `scripts/install.sh` is enough.

---

## License

By contributing, you agree your contributions are licensed under the MIT License.
