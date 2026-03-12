# Setup Reference

Use this reference when the user wants to configure Burp Suite for Codex or when the MCP servers are missing.

## Required MCP servers

Register these servers in Codex:

### Burp MCP

Use the packaged stdio proxy, not the raw Burp SSE URL, because Codex expects a stdio-compatible MCP process for this integration path.

```bash
codex mcp add burp -- "/Applications/Burp Suite Professional.app/Contents/Resources/jre.bundle/Contents/Home/bin/java" -jar "$HOME/.BurpSuite/mcp-proxy/mcp-proxy-all.jar" --sse-url http://127.0.0.1:9876
```

### Burp-proxied browser

Use Playwright MCP with Burp's embedded Chromium and Burp's proxy:

```bash
codex mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path "/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated
```

## Verify health

```bash
codex mcp list
curl -i --max-time 3 http://127.0.0.1:9876
lsof -nP -iTCP -sTCP:LISTEN | rg ':8080|:9876'
```

Signals to look for:

- `burp` present in `codex mcp list`
- `burp-browser` present in `codex mcp list`
- `text/event-stream` returned by the SSE endpoint
- Burp listening on `127.0.0.1:8080` and `127.0.0.1:9876`
- `mcp-proxy-all.jar` present at `~/.BurpSuite/mcp-proxy/mcp-proxy-all.jar`

`curl` can time out after printing the headers because SSE stays open. Treat a visible `text/event-stream` header as healthy.

## Important note

After changing MCP configuration, Codex Desktop may need a restart or a fresh thread before the new tools appear in the agent session.
