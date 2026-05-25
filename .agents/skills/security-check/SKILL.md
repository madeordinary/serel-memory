---
name: security-check
description: "Lightweight OWASP Top 10 + STRIDE security pass on the current change. Use when the user asks for a security review, security check, threat model, or vulnerability scan of the current diff."
---

# Security Check

Review the current change for security issues. Be thorough but pragmatic — focus on real risks, not theoretical edge cases. Do not edit files.

## Workflow

1. Run `git diff main...HEAD` (or `git diff` for uncommitted) to see what changed.
2. Read modified files in full where context matters.
3. Check against OWASP Top 10 + STRIDE.

## OWASP Top 10 pass

For each, note: present / not applicable / concern.

1. **Broken access control** — anyone able to access something they shouldn't?
2. **Cryptographic failures** — sensitive data in the clear; weak algorithms; hardcoded keys?
3. **Injection** — SQL, command, LDAP, OS, prompt injection?
4. **Insecure design** — missing rate limits, no auth where needed, trust boundaries violated?
5. **Security misconfiguration** — overly permissive CORS, verbose errors, default creds?
6. **Vulnerable & outdated components** — new deps with known CVEs?
7. **Identification & authentication failures** — weak sessions, missing MFA, token leakage?
8. **Software & data integrity failures** — unsigned updates, deserialization, dependency tampering?
9. **Security logging & monitoring failures** — enough audit trail for what was added?
10. **Server-side request forgery** — user-controlled URLs fetched server-side?

## STRIDE pass

- **Spoofing** — can someone impersonate a user or service?
- **Tampering** — can data in transit or at rest be modified undetected?
- **Repudiation** — can a user deny doing something we'd need to prove?
- **Information disclosure** — anything leaked through errors, logs, response bodies?
- **Denial of service** — unbounded loops, unrate-limited endpoints, resource exhaustion?
- **Elevation of privilege** — can a low-privilege actor get higher access?

## Output

```text
SECURITY SUMMARY: [one line — overall risk read]

HIGH RISK (block merge):
- [file:line] [issue] → [fix]

MEDIUM RISK (fix before prod):
- [file:line] [issue] → [fix]

LOW / NIT (track for later):
- [file:line] [issue] → [fix]

CHECKED & CLEAN: [list of categories checked and clean — to show coverage]
```

## Rules

- Don't cry wolf. A theoretical attack with no realistic path doesn't belong in HIGH RISK.
- For each finding, the fix matters as much as the identification.
- If you didn't check something (e.g., infra not in scope), say so — don't claim coverage you don't have.
