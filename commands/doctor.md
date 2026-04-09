---
name: doctor
description: Diagnose oh-my-forge installation health. Runs the doctor skill and scripts/doctor.sh.
---

Run the installation diagnostic.

Load the `doctor` skill. Then run `scripts/doctor.sh` if available. Collect:

1. `forge --version`
2. `~/forge/` contents + permissions
3. `.forge.toml` validity
4. Every agent file's frontmatter (required fields present, no forbidden fields)
5. Every skill directory's `SKILL.md` validity
6. MCP socket reachability (if `.mcp.json` exists)
7. Which built-in and user agents `forge list agent` sees
8. Which skills `forge list skill` sees

Output a diagnostic report with pass/warn/fail per check and a clear "NEXT STEPS" section if anything failed.

{{parameters}}
