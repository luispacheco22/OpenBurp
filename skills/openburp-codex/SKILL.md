---
name: openburp-codex
description: Configure and use Burp Suite Professional with Codex for authorized web security testing. Use when the user mentions Burp Suite, Burp MCP, proxy history, Repeater, scanner findings, Collaborator, or wants a Playwright browser session routed through Burp for an internal app, staging site, lab, localhost app, or any other target they explicitly control and are authorized to test.
---

# OpenBurp Codex

## Overview

Use this skill to set up or operate a Burp-driven workflow in Codex. Prefer Burp MCP for raw HTTP actions and use the Burp-proxied Playwright browser for page navigation, screenshots, and interaction confirmation.

## Core Rules

- Require explicit authorization. If the target is a public third-party site and the user has not clearly stated they have permission, stop and ask once or refuse.
- Start with the smallest useful action when the user is only validating setup. A single request or one page load is the default.
- Keep raw request fuzzing, replay, history review, scanner checks, and Collaborator activity inside Burp MCP.
- Keep page navigation, form interaction, screenshots, and browser verification inside the Burp-proxied Playwright browser.
- If the user just changed MCP configuration, warn that Codex may need a restart or a new thread before new tools appear.

## Workflow

1. Confirm the target and authorization status.
2. Check health if setup looks broken.
3. Use Burp MCP for request-level work.
4. Use the Burp-proxied browser for page-level work.
5. Summarize what was tested, what evidence was collected, and what should happen next.

## Tool Selection

- Use `burp` for:
  - replaying or crafting HTTP requests
  - reviewing proxy history
  - sending to Repeater or Intruder
  - checking scanner findings
  - generating or checking Collaborator payloads
- Use `burp-browser` for:
  - loading an authorized target through Burp's proxy
  - clicking, typing, and navigating as a user would
  - taking screenshots or snapshots for evidence
  - confirming browser-visible behavior after Burp-side testing
- If the user wants to see traffic in `Proxy > HTTP history`, prefer `burp-browser` because some raw `burp` requests use Burp's HTTP client and may not be logged by the proxy listener.

## Health Checks

If setup looks wrong, use the script in `scripts/check-health.sh`.

If you need the exact setup commands or MCP registration details, read [references/setup.md](references/setup.md).

If you need operating patterns, safe prompts, or recommended sequencing, read [references/workflow.md](references/workflow.md).

## Response Pattern

- State what target is in scope.
- State whether the step is only a setup check or an actual test action.
- Prefer one concrete action at a time when confirming integration.
- Report the request or browser action you used so the user can find it in Burp history.
