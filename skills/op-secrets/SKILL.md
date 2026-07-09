---
name: op-secrets
description: Use when storing, retrieving, rotating, or wiring up ANY secret/token/API key/credential - all secrets live in 1Password via the op CLI; never plaintext files, never hardcoded
---

# Secrets via 1Password CLI (`op`)

All secrets on this machine live in 1Password. The `op` CLI is the only
sanctioned store/retrieve mechanism. Never write a secret to a plaintext
file, shell rc, `.env` committed anywhere, or hardcode it in source.

## Layout

| What | Where |
|------|-------|
| Personal account | `my.1password.eu` |
| Env-var secrets (the standard set) | vault `cli-secrets`, item `shell-env`, one field per var |
| Other personal credentials | own item in vault `cli-secrets` |
| Work (ista) secrets | account `istase.1password.eu` — ask the operator which vault |

The shell exports the `shell-env` fields as env vars at startup via a
login-Keychain cache (24 h TTL, one Touch ID per window). A STALE cache is
still exported everywhere (the TTL bounds keychain exposure, not token
validity); only interactive human shells refresh via `op` — agent and
non-interactive shells NEVER invoke `op` for the standard set. See
`~/.config/mein-zsh/snippets/op-secrets.zsh` for the mechanism and
`~/.config/mein-zsh/secrets.env.tpl` for the var list.

Touch ID: a direct `op` call (new secret, work account) may prompt once per
Claude Code session. This is expected — do not work around it. But for the
standard env-var set, never call `op` at all: the vars are already exported.

## Retrieving

1. **Check the env first** — the standard vars are usually already exported
   (`secrets-status` shows which). Don't call `op` for a var that's set.
2. Single value: `op read 'op://cli-secrets/shell-env/NAME' --account my.1password.eu`
3. Whole item: `op item get <item> --vault cli-secrets --format json` (add
   `--reveal` only when a value is genuinely needed).
4. Inject into one command without exporting:
   `op run --env-file=<tpl> -- <cmd>` or the shell's `with-secrets <cmd>`.

**Never print secret values** into the transcript, logs, or files. Verify
writes by listing field NAMES (`op item get shell-env --vault cli-secrets | head`),
not values.

## Storing a new secret

For a new env-var style secret (the common case):

```bash
# 1. store the value (read it into a var first; avoid retyping in argv twice)
op item edit shell-env --vault cli-secrets --account my.1password.eu \
  "NEW_NAME[password]=$VALUE"

# 2. register it in the template (TAB-separated, matches existing lines)
# append to ~/.config/mein-zsh/secrets.env.tpl:
# NEW_NAME<TAB>{{ op://cli-secrets/shell-env/NEW_NAME }}

# 3. refresh the keychain cache so shells pick it up
zsh -c 'source ~/.config/mein-zsh/snippets/op-secrets.zsh && secrets-refresh'
```

Caveat (op's own warning): assignment-statement values are briefly visible
in `ps` argv. Acceptable on this single-user machine for typical tokens.
For high-value secrets, use the JSON-template stdin path instead:
`op item template get Login | <edit> | op item create --vault cli-secrets -`.

For structured credentials (username+password, multi-field API creds),
create a dedicated item instead of stuffing `shell-env`:

```bash
op item create --category 'API Credential' --vault cli-secrets \
  --title '<descriptive-name>' "credential=$VALUE"
```

## Cache management (zsh functions)

- `secrets-status` — cache age/TTL, which vars are set (names only)
- `secrets-refresh` — force re-inject + re-cache (one Touch ID)
- `secrets-clear` — delete the keychain cache entry
- TTL override: `export MEIN_ZSH_SECRETS_TTL=<seconds>` (default 86400 = 24 h)

## When migrating found plaintext secrets

If you encounter a secret in a plaintext file or rc: store it in op (above),
replace the usage with the env var or an `op read`/`op run` reference, then
ask the operator before deleting the original and recommend rotating it.
