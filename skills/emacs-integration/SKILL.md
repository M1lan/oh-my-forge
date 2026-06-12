---
name: emacs-integration
description: "Integration with Emacs editor via MCP tools. Use when the user mentions Emacs, when working on Emacs Lisp files, or when IDE-aware operations are needed (diagnostics, buffer content, open files). Provides guidance on using emacs/* MCP tools for bidirectional editor integration."
---

# Emacs Integration Skill

This skill enables Forge agents to interact with a running Emacs instance via MCP tools registered on a Unix domain socket at `~/.local/state/emacs/mcp.sock`.

## Available MCP Tools

### File & Navigation

| Tool | Description | When to Use |
|------|-------------|-------------|
| `emacs/open-file` | Open a file at optional line:column | When you want to show the user a file in their editor |
| `emacs/jump-to-location` | Navigate to file:line:column | To direct the user to a specific code location |
| `emacs/list-files` | List project files | To discover files in the current Emacs project |

### Buffer Operations

| Tool | Description | When to Use |
|------|-------------|-------------|
| `emacs/get-buffer-content` | Get current buffer text | To read what the user is currently editing |
| `emacs/list-buffers` | List all open buffers | To understand what files are open in Emacs |
| `emacs/switch-buffer` | Switch to a named buffer | To bring a specific buffer to focus |
| `emacs/insert-text` | Insert text at cursor | For small insertions at the current point |
| `emacs/replace-region` | Replace text between positions | For targeted text replacements |

### Diagnostics & Code Quality

| Tool | Description | When to Use |
|------|-------------|-------------|
| `emacs/get-diagnostics` | Get Flymake/Flycheck errors | To understand compilation/lint errors the user sees |
| `emacs/show-diff` | Display diff in Emacs | To show proposed changes in a diff-mode buffer |
| `emacs/apply-patch` | Apply a patch to a file | To apply changes directly through Emacs |

### Execution

| Tool | Description | When to Use |
|------|-------------|-------------|
| `emacs/run-command` | Execute allowlisted M-x commands | For safe operations like save-buffer, revert-buffer |

## When to Prefer MCP Tools vs Direct File Access

**Use MCP tools when:**

- You need to know what the user is currently looking at (buffer content, cursor position)
- You want diagnostic information (Flymake/Flycheck errors visible in their editor)
- You want to open a file for the user to review (visual confirmation)
- You need to understand the user's editing context (open buffers, project)

**Use direct file access when:**

- You need to read/write files that aren't open in Emacs
- You need bulk file operations (searching across many files)
- Performance matters (direct file I/O is faster than MCP round-trips)
- The operation doesn't benefit from editor context

## Getting Current Editor Context

To understand what the user is working on:

1. Call `emacs/get-buffer-content` to read the current buffer
2. Call `emacs/get-diagnostics` to see any errors/warnings
3. Call `emacs/list-buffers` to see all open files

This gives you the same context the user sees in their editor.

## Opening Files for Review

After making changes, use `emacs/open-file` with the file path and optionally a line number to direct the user to the relevant change. This is more helpful than just describing the change.

## Emacs-Specific Conventions

- Emacs Lisp files use `;;; Commentary:` and `;;; Code:` section markers
- Packages use `(provide 'feature-name)` at the end
- Never byte-compile files in `~/.emacs.d/lisp/`
- The user's Emacs has lexical binding enabled globally
- Buffer names starting with `*` are special buffers (not file-visiting)
