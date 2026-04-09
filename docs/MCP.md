# MCP Setup

Forge supports the Model Context Protocol (MCP) for connecting to external servers that provide additional tools (databases, APIs, editors, filesystem providers, browser automation, etc.).

---

## Config file location

MCP config lives at `~/forge/.mcp.json` (user-global) or `<project>/.mcp.json` (project-local).

oh-my-forge ships `.mcp.json.example` at the repo root as a template. Copy it and customize:

```bash
cp .mcp.json.example ~/forge/.mcp.json
# then edit the file to enable and configure the servers you want
```

---

## File format

Strict JSON. **No comments, no trailing commas.** If `jq .` fails on your file, forge will also fail.

```json
{
  "mcpServers": {
    "server-name": {
      "command": "path/to/binary",
      "args": ["--arg1", "value1"],
      "env": {
        "API_KEY": "..."
      },
      "disable": false
    }
  }
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `command` | string | yes | Path to the executable (or command on PATH). |
| `args` | string[] | no | Arguments passed to the command. |
| `env` | object | no | Environment variables set for the process. |
| `disable` | bool | no | When true, the server is loaded but not started. Default false. |

Unknown fields are rejected (`#[serde(deny_unknown_fields)]`).

---

## Common servers to configure

### emacs (local Unix socket bridge)

```json
{
  "emacs": {
    "command": "socat",
    "args": ["-", "UNIX-CONNECT:/Users/YOU/.local/state/emacs/mcp.sock"],
    "disable": false
  }
}
```

Provides 16+ tools under `emacs/*` (open-file, get-diagnostics, get-buffer-content, etc.) for bidirectional editor integration.

### github (official MCP server)

```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
    },
    "disable": false
  }
}
```

Provides GitHub API tools: search issues, create PRs, read code, etc.

### filesystem

```json
{
  "filesystem": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/YOU/workspace"],
    "disable": false
  }
}
```

Provides constrained filesystem access outside the current workspace.

### fetch (HTTP fetching)

```json
{
  "fetch": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-fetch"],
    "disable": false
  }
}
```

Provides enhanced HTTP fetching with caching and structured output.

---

## Forge MCP subcommands

| Command | Purpose |
|---|---|
| `forge mcp list` | List configured servers |
| `forge mcp show <name>` | Show details for one server |
| `forge mcp import <file>` | Import server config from a JSON file |
| `forge mcp remove <name>` | Remove a server |
| `forge mcp reload` | Reload config without restarting forge |
| `forge mcp login <name>` | OAuth login flow (if server supports it) |
| `forge mcp logout <name>` | OAuth logout |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `forge mcp list` shows nothing | `ls -la ~/forge/.mcp.json` -- does the file exist? |
| JSON parse error | `jq . < ~/forge/.mcp.json` -- the error message points to the offending line. |
| Server starts but tools not visible | Check the server's stderr: `forge --log-level debug` and look for `mcp_*` errors. |
| `disable: true` ignored | Restart forge -- config changes require a reload. |
| `command not found` | Use an absolute path or ensure the command is on `$PATH`. |

---

## Security notes

- MCP servers run as subprocesses with your user privileges. Only install servers from sources you trust.
- Eval-style tools (`emacs/eval-elisp`, `emacs/eval-shell`) should be left disabled unless you explicitly need them.
- API keys in `env` are stored in plaintext -- prefer a password manager / keychain integration if possible.
- Filesystem servers should be scoped to the narrowest directory necessary.
