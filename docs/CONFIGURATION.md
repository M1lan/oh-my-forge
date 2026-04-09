# `.forge.toml` Configuration Reference

The `.forge.toml` file configures a forge session. It can live at:

- `~/forge/.forge.toml` (user-global, loaded always)
- `<project>/.forge.toml` (project-local, overrides user-global fields)

oh-my-forge ships a baseline at the repo root that users can copy to `~/forge/.forge.toml` and customize.

---

## Top-level structure

```toml
# Comments are allowed
# Top-level keys group related settings into sections

[session]
provider = "claude_code"
model = "claude-opus-4-6"

[reasoning]
enabled = true
effort = "high"

[updates]
frequency = "daily"
auto_update = false

[compact]
# ...

[retry]
# ...

[[commands]]
# Inline commands -- rarely needed, prefer file-based commands/ dir
```

---

## `[session]`

Controls which model and provider forge uses.

| Key | Type | Default | Description |
|---|---|---|---|
| `provider` | string | -- | Provider id. oh-my-forge baseline uses `claude_code`. Other values depend on forge build (see `forge list provider`). |
| `model` | string | -- | Model id for the chosen provider. oh-my-forge baseline: `claude-opus-4-6`. |

---

## `[reasoning]`

Controls extended thinking / reasoning budget for agents that have `reasoning.enabled = true` in their frontmatter.

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `false` | Master switch. When false, all agent `reasoning` settings are ignored. |
| `effort` | string | `medium` | One of `low`, `medium`, `high`. Controls reasoning token budget. |
| `summary` | string | `auto` | One of `auto`, `detailed`, `none`. Controls how reasoning output is summarized. |

oh-my-forge baseline: `enabled = true`, `effort = "high"`, `summary = "detailed"`.

---

## `[updates]`

Controls how forge checks for and applies its own updates.

| Key | Type | Default | Description |
|---|---|---|---|
| `frequency` | string | `daily` | One of `daily`, `weekly`, `always`. **NOT** `never` or `monthly` -- those are not valid and will cause a parse error. |
| `auto_update` | bool | `false` | When true, forge will update itself automatically when a new release is detected. oh-my-forge baseline ships `false` as the safer default -- a surprise auto-update in the middle of a session is not fun. |

---

## `[compact]`

Controls context compaction behavior.

| Key | Type | Default | Description |
|---|---|---|---|
| `threshold` | number | -- | Token threshold at which forge compacts the conversation. |
| `model` | string | -- | Optional override model for the compaction pass. |
| `prompt` | string | -- | Optional override prompt for compaction. |

See your live `~/forge/.forge.toml` for the exact defaults and ranges. oh-my-forge's baseline mirrors the live install's values.

---

## `[retry]`

Controls HTTP retry behavior for the provider.

| Key | Type | Default | Description |
|---|---|---|---|
| `max_attempts` | int | -- | Max retry count on retriable errors. |
| `initial_delay_ms` | int | -- | Initial backoff delay. |
| `max_delay_ms` | int | -- | Cap on backoff delay. |

---

## `[[commands]]`

Inline command definitions. **Prefer file-based commands** in `commands/*.md` -- they are more discoverable, easier to version-control, and easier to share.

If you do use inline commands:

```toml
[[commands]]
name = "feature"
description = "Plan and implement a new feature"
prompt = """
Plan and implement a feature based on the description:
{{parameters}}
"""
```

Note: the body variable is `{{parameters}}`, not `{{args}}`. There is no `value` field.

---

## Precedence

1. Project `.forge.toml` (highest)
2. User `~/forge/.forge.toml`
3. Forge built-in defaults (lowest)

Keys in the project file override keys in the user file, which override built-in defaults.

---

## Common pitfalls

| Pitfall | Fix |
|---|---|
| `frequency = "never"` or `"monthly"` | Use `daily`, `weekly`, or `always` -- those are the only valid values. |
| Using `effort = "max"` | Use `low`, `medium`, or `high`. |
| Forgetting to wrap strings in quotes | TOML requires quotes around string values. |
| Declaring `[[commands]]` more than once with the same name | The last one wins; there is no merge. |
| Using YAML syntax | `.forge.toml` is **TOML**, not YAML. `foo: bar` is wrong; `foo = "bar"` is right. |

---

## Migration from `forge.yaml`

If you have an old `forge.yaml`, run:

```bash
scripts/migrate-from-v1.sh ~/forge
```

This converts the YAML to TOML, preserves your custom settings, and backs up the original.

---

## Validating

```bash
python3 -c "import tomllib; tomllib.load(open('$HOME/forge/.forge.toml','rb')); print('OK')"
```

Or run the doctor:

```bash
scripts/doctor.sh --user
```
