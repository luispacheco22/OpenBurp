# Claude Code + Burp Suite - AI-Powered Pentesting Setup

Use Claude Code with Burp Suite Professional + Chrome DevTools MCP in minutes.

## Quick Start (1 command)

```bash
cd /path/to/claude-burp-pentest-setup
./setup.sh /your-workspace
```

## What this command does automatically

- Checks/install Claude Code if missing
- Installs `chrome-devtools-mcp` if missing
- Detects Burp embedded Chromium path
- Copies local permissions to `/your-workspace/.claude/settings.local.json`
- Registers MCP servers in **project scope** (`burpsuite` + `chrome-devtools`)

## Requirements

- Burp Suite **Professional** (Community edition is not enough)
- Burp extension **MCP Server** installed (BApp Store)
- Burp proxy listening on `127.0.0.1:8080`
- Node.js >= 18

## Verify in 30 seconds

```bash
cd /your-workspace
claude mcp list
```

Expected in project MCPs:
- `burpsuite` (SSE: `http://localhost:9876/`)
- `chrome-devtools` (stdio: `chrome-devtools-mcp`)

## If you prefer manual MCP setup

Run setup without auto-registration:

```bash
./setup.sh --manual-mcp /your-workspace
```

Then add manually (project scope):

```bash
cd /your-workspace
claude mcp add -s project -t sse burpsuite http://localhost:9876/
claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath "/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated
```

## Recommended Burp config

Import `burp-configs/scope-exclude-noise.json`:

1. Burp → Project → Project options → Load from file
2. Select `burp-configs/scope-exclude-noise.json`

## Troubleshooting

- `burpsuite` disconnected: confirm Burp is open and `MCP Server` tab is healthy
- `chrome-devtools` disconnected: run `which chrome-devtools-mcp`
- Wrong Chromium path: rerun setup and provide manual path when prompted

## License

Educational and authorized security testing only.
