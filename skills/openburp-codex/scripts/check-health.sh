#!/usr/bin/env bash

set -euo pipefail

status_ok() {
    printf '[OK] %s\n' "$1"
}

status_warn() {
    printf '[WARN] %s\n' "$1"
}

check_command() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        status_ok "$name found"
    else
        status_warn "$name missing"
    fi
}

check_command codex
check_command node
check_command npm
check_command npx

if [[ -x "/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium" ]]; then
    status_ok "Burp Chromium found"
else
    status_warn "Burp Chromium not found at the default macOS path"
fi

if [[ -x "/Applications/Burp Suite Professional.app/Contents/Resources/jre.bundle/Contents/Home/bin/java" ]]; then
    status_ok "Burp Java found"
else
    status_warn "Burp Java not found at the default macOS path"
fi

if [[ -f "$HOME/.BurpSuite/mcp-proxy/mcp-proxy-all.jar" ]]; then
    status_ok "Burp MCP proxy jar found"
else
    status_warn "Burp MCP proxy jar missing"
fi

if command -v curl >/dev/null 2>&1; then
    RESPONSE="$(curl -is --max-time 3 http://127.0.0.1:9876 2>/dev/null || true)"
    if printf '%s' "$RESPONSE" | grep -qi "text/event-stream"; then
        status_ok "Burp MCP SSE responds on 127.0.0.1:9876"
    else
        status_warn "Burp MCP SSE does not respond on 127.0.0.1:9876"
    fi
fi

if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -q "127.0.0.1:8080"; then
        status_ok "Burp proxy listens on 127.0.0.1:8080"
    else
        status_warn "Burp proxy is not listening on 127.0.0.1:8080"
    fi
fi

if command -v codex >/dev/null 2>&1; then
    MCP_JSON="$(codex mcp list --json 2>/dev/null || true)"
    if printf '%s' "$MCP_JSON" | rg -q '"name": "burp"'; then
        status_ok "Codex MCP entry 'burp' is present"
    else
        status_warn "Codex MCP entry 'burp' is missing"
    fi

    if printf '%s' "$MCP_JSON" | rg -q '"name": "burp-browser"'; then
        status_ok "Codex MCP entry 'burp-browser' is present"
    else
        status_warn "Codex MCP entry 'burp-browser' is missing"
    fi
fi
