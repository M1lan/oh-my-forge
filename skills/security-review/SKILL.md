---
name: security-review
description: OWASP Top 10 plus secrets and trust-boundary audit of a diff or module. Delegates to the security-reviewer agent for the full vulnerability scan, produces explicit severity and confidence per finding with file:line citations, applies a zero-noise bias (only reports findings with concrete exploitability evidence), and never prints secret values into output. Use when the user says "security review", "audit this for vulns", "check for secrets", "OWASP scan", or when a diff touches auth, input parsing, session handling, serialization, or privilege boundaries.
---

# Security Review

Zero-noise bias: only report what you can prove is exploitable.

## When to invoke

- User says "security review", "audit this", "check for vulns", "OWASP scan", "secrets check", "trust boundary review".
- A diff or module touches: auth, session tokens, JWT, input parsing from external sources, SQL or shell construction, serialization/deserialization, privilege checks, cryptographic operations.
- Before a release that includes new API endpoints or auth changes.

## Step 1 — define the scope

Determine the review target:

- **Working tree diff:** `shell` — `git diff HEAD`
- **Branch diff:** `shell` — `git diff $(git merge-base HEAD main)...HEAD`
- **Specific module or file:** read directly via `read`
- **Whole codebase path:** list with `fs_search`, then read the relevant files

Identify the attack surface: external inputs, trust boundaries, auth check locations, data flows from untrusted sources to sensitive sinks.

## Step 2 — delegate to security-reviewer

Use the `task` tool:

```text
task(
  agent="security-reviewer",
  prompt="SECURITY AUDIT

Scope: <diff or file list>
Attack surface: <trust boundaries identified in step 1>

Run your full scan:
- OWASP Top 10 (2021) — all 10 categories
- Secret exposure in the diff (keys, tokens, credentials)
- CORS misconfiguration
- Missing security headers
- Cryptographic misuse (ECB mode, static IVs, MD5/SHA1 for integrity, rand vs crypto.rand)
- Supply chain risks (unpinned deps, suspicious packages)
- Race conditions and TOCTOU patterns
- Deserialization of untrusted input

For each finding:
- Assign severity: Critical / High / Medium / Low
- Assign confidence: Confirmed / Likely / Possible
- Cite file:line
- Describe the concrete exploit scenario (not just the pattern)
- Provide specific remediation

IMPORTANT: do NOT print any secret values into the output.
Verify exploitability before elevating severity — pattern match alone is not evidence."
)
```

If the agent cannot be launched, report `security-reviewer agent unavailable` and stop. Do not self-substitute.

## Step 3 — apply the zero-noise filter

For each finding returned by the agent, assess before including it:

- **Confirmed:** there is a concrete, reproducible exploit path in the code as written. Include at full severity.
- **Likely:** the pattern is present and the exploit path is plausible but requires additional runtime conditions. Downgrade one severity level and note the condition.
- **Possible:** the pattern is present but the context makes exploitation unlikely (e.g., internal-only endpoint, value is already validated upstream). Include only at Low or as a note. Explain why it is lower confidence.

Discard findings where the agent flagged a pattern but the surrounding code already mitigates it. Explain the mitigation in the report.

## Step 4 — never print secrets

If the diff or codebase contains literal secret values (API keys, tokens, passwords):

- Reference the location (`file:line`) and the type ("hardcoded API key").
- Do NOT reproduce the value in any part of the output, including code snippets or PoC examples.
- Suggest remediation: move to environment variable / secret store, rotate the exposed value.

## Output format

```text
## Security Review: <scope>

### Summary
- Scanned: <files or components>
- Attack surface: <trust boundaries reviewed>
- Findings: N critical, N high, N medium, N low

### Critical
**<title>** — `path/to/file.ext:LL`
- Category: OWASP A## / CWE-###
- Confidence: Confirmed / Likely / Possible
- Impact: <what an attacker can do>
- Exploit scenario: <concrete steps, no secret values printed>
- Remediation: <specific code change>

### High / Medium / Low
...

### Secret exposure
- `path/to/file.ext:LL` — <type of secret, NOT the value> — rotate immediately

### Supply chain
- <dep>@<version> — <CVE or concern>, fix: <action>

### Missing controls
- [ ] <control that should be present but is not>

### Cleared patterns
- <pattern that was flagged but is already mitigated> — reason: <mitigation>

### Verdict
BLOCK / WATCH / CLEAR
```

Verdict definitions:

- **BLOCK** — one or more Critical or High findings with Confirmed or Likely confidence. Do not ship without addressing.
- **WATCH** — Medium findings or High findings at Possible confidence. Review before next release.
- **CLEAR** — no findings above Low confidence, or all findings are already mitigated.

## Rules

- Never report a finding without a file:line citation.
- Never inflate severity. Not every SQL query is injection; check whether the value is parameterized.
- Never print secret values under any circumstances.
- "It's behind a firewall" is not a mitigation. Document it as a compensating control, not a fix.
- Git history is permanent. Check whether secrets were present in earlier commits even if removed now.
- When using git to get the diff, use `shell` with `git diff` — reference the Lore commit protocol from AGENTS.md for any commit advice given to the user.
