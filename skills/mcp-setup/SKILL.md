---
name: mcp-setup
description: Guided workflow for wiring MCP servers into ~/forge/.mcp.json (user-global) or ./.mcp.json (project-local). Includes a catalog of known-good server configs (emacs, mempalace, cortex, gitnexus, context7, github, fetch, filesystem) as ready-to-merge JSON snippets. Reads the current config, shows the proposed merge, writes strict JSON, validates with jq or python3, and reminds the user to restart forge. Use when adding, reviewing, or troubleshooting MCP server configuration.
---

# MCP Setup

Wire MCP servers into forge's JSON config with zero manual JSON surgery.

## When to invoke

- User says "set up MCP", "add an MCP server", "configure context7", "wire up emacs MCP", or similar.
- `forge mcp list` shows fewer servers than expected.
- A server is configured but tools are not appearing.
- Setting up a fresh forge install and wanting the standard server set.

## Background

Forge reads MCP config from two files, merged at startup:

| File | Scope |
|---|---|
| `~/forge/.mcp.json` | User-global — applies to every forge session |
| `./.mcp.json` (project root) | Project-local — applies only in this directory tree |

Both files must be **strict JSON** — no comments, no trailing commas. A parse error in either file silently prevents all MCP servers from loading.

## Workflow

### Step 1: Determine the target file

Ask the user (or infer from context):

- **Global** (`~/forge/.mcp.json`) — server should be available in every project.
- **Project-local** (`./.mcp.json`) — server is only needed here.

Default to global unless the user says otherwise.

### Step 2: Read the current config

Use the read tool on the target file. If it does not exist, treat the current content as:

```json
{
  "mcpServers": {}
}
```

Report which servers are already configured (names only).

### Step 3: Select servers to add

Present the catalog below. For each server the user wants to add, check whether it already exists in the file (by key name) and skip if so, reporting "already configured".

### Step 4: Resolve API keys

Some servers need credentials. Source them from 1Password via `op` — never hardcode a token value.

```bash
# retrieve a token from 1Password (shell tool)
op read "op://cli-secrets/shell-env/<FIELD_NAME>"
```

Replace the placeholder in the JSON snippet with the retrieved value, or use an `env` block that references an environment variable the user must have set. Remind the user: never commit credential values to version control.

If the user does not have `op` available, instruct them to set the relevant environment variable (`export GITHUB_PERSONAL_ACCESS_TOKEN=...`) and use the env-var form of the config.

### Step 5: Propose the merge

Show the user the exact JSON that will be written. Do not write yet — confirm the proposed change first.

### Step 6: Write the file

Use the write tool to produce the merged `.mcp.json`. The result must be valid strict JSON.

### Step 7: Validate

Run via the shell tool (use whichever is available):

```bash
# preferred
jq . < ~/forge/.mcp.json > /dev/null && printf 'OK: valid JSON\n' || printf 'FAIL: parse error\n'

# fallback
python3 -m json.tool ~/forge/.mcp.json > /dev/null && printf 'OK: valid JSON\n' || printf 'FAIL: parse error\n'
```

If validation fails, show the error and fix the file before declaring success.

### Step 8: Remind about restart

```text
MCP config changes take effect only after forge is restarted.
Run: forge mcp list   (after restart, to confirm the servers loaded)
```

---

## Server catalog

Copy the relevant block and merge it under `"mcpServers"` in the target file.

### emacs (Emacs MCP bridge — bidirectional editor integration)

```json
"emacs": {
  "command": "bash",
  "args": ["-lc", "exec $HOME/.emacs.d/bin/emacs-mcp-bridge.sh"]
}
```

Provides tools for opening files, getting diagnostics, reading buffer contents, running Emacs commands, and evaluating elisp. Requires the bridge script to be present at `~/.emacs.d/bin/emacs-mcp-bridge.sh`.

### mempalace (long-term memory store)

```json
"mempalace": {
  "command": "mempalace-mcp",
  "args": []
}
```

Provides persistent memory storage across sessions. Requires the `mempalace-mcp` binary to be on `$PATH`.

### cortex (structured cognition engine — beliefs, threads, goals)

```json
"cortex": {
  "command": "bash",
  "args": ["-lc", "cd $HOME/cortex-workspace && exec fnm exec --using 22.20.0 $HOME/Library/pnpm/bin/fozikio serve"]
}
```

Provides structured reasoning: beliefs that update with evidence, tracked threads, goals, and journals. Requires `fozikio` installed via pnpm and fnm with Node 22.20.0.

### gitnexus (multi-repo graph analysis)

```json
"gitnexus": {
  "command": "gitnexus",
  "args": ["mcp"]
}
```

Provides cross-repository impact analysis, dependency graphs, and change routing. Requires the `gitnexus` binary on `$PATH`.

### context7 (library documentation lookup)

```json
"context7": {
  "command": "bash",
  "args": ["-lc", "exec fnm exec --using 22.20.0 npx -y @upstash/context7-mcp"]
}
```

Fetches current documentation for any library, framework, or SDK. Zero-config; no API key required. Requires fnm with Node 22.20.0.

### github (GitHub API)

```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "<retrieve via op or env var — never hardcode>"
  }
}
```

Provides GitHub tools: search issues, create PRs, read repository content. Retrieve the token:

```bash
op read "op://cli-secrets/shell-env/GITHUB_PERSONAL_ACCESS_TOKEN"
```

### fetch (enhanced HTTP fetching)

```json
"fetch": {
  "command": "uvx",
  "args": ["mcp-server-fetch"]
}
```

Provides HTTP fetching with caching and structured output. Requires `uvx` (part of `uv`; install via `brew install uv`).

### filesystem (constrained filesystem access)

```json
"filesystem": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "/ABSOLUTE/PATH/TO/ALLOWED/ROOT"]
}
```

Grants forge read/write access to a directory tree outside the current workspace. Replace the path with the narrowest directory that satisfies the use case.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `forge mcp list` shows nothing after restart | Check that `~/forge/.mcp.json` exists and parses: `jq . < ~/forge/.mcp.json` |
| JSON parse error | Remove any comments (`//`, `#`) and trailing commas — JSON is strict |
| Server listed but tools not visible | Check `forge --log-level debug` for `mcp_*` errors in stderr |
| `command not found` at server startup | Use an absolute path, or ensure the binary is on `$PATH` in a login shell |
| `disable: true` not respected | Restart forge — config is read at startup, not on the fly |

## Security notes

- MCP servers run as subprocesses with your user privileges. Only install servers from sources you trust.
- API keys must come from 1Password (`op read`) or environment variables — never embed literal token values in the JSON file.
- Filesystem servers must be scoped to the narrowest directory necessary.
- Eval-style tools (e.g., `emacs/eval-elisp`) should be tested carefully; they execute arbitrary code in your editor process.
