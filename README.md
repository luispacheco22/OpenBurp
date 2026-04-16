# OpenBurp

Use Burp Suite Professional with `Claude Code`, `Codex`, or both from one setup flow.

Optionally pair it with a bundled Kali Linux Docker container so the AI agent can run recon, exploitation, and post-exploitation tooling (`nmap`, `sqlmap`, `impacket`, `evil-winrm`, etc.) in an isolated environment while Burp MCP handles web traffic analysis. See [CLAUDE.md](CLAUDE.md) for the full pentesting workflow.

## Quick start

Auto-detect the available client and configure it:

```bash
cd /path/to/OpenBurp
./setup.sh /your-workspace
```

Choose a specific client:

```bash
./setup.sh --client claude /your-workspace
./setup.sh --client codex /your-workspace
./setup.sh --client both /your-workspace
```

On Windows:

```powershell
.\setup.ps1 -Client codex -Workspace C:\path\to\your-workspace
.\setup.ps1 -Client both -Workspace C:\path\to\your-workspace
```

## What setup does

Common steps:

- Checks `node`, `npm`, and `npx`
- Detects Burp embedded Chromium
- Detects Burp Java
- Extracts `mcp-proxy-all.jar` from the installed Burp MCP extension when needed

If `Claude Code` is selected:

- Checks or installs `Claude Code`
- Checks or installs `chrome-devtools-mcp`
- Copies local permissions to `/your-workspace/.claude/settings.local.json`
- Registers Claude project MCPs: `burpsuite` + `chrome-devtools`

If `Codex` is selected:

- Detects Codex CLI
- Installs the reusable skill `openburp-codex` into `$CODEX_HOME/skills`
- Registers Codex global MCPs:
  - `burp` via the official PortSwigger stdio proxy
  - `burp-browser` via Playwright MCP using Burp's Chromium through `127.0.0.1:8080`

Why Codex is different:

- Claude can connect directly to Burp's SSE MCP endpoint for `burpsuite`
- Codex works more reliably with the official `mcp-proxy-all.jar`, which bridges Burp's SSE server into a local stdio MCP process

## Requirements

- Burp Suite Professional
- Burp extension `MCP Server` installed from the BApp Store
- Burp proxy listening on `127.0.0.1:8080`
- Burp MCP SSE listening on `127.0.0.1:9876`
- Node.js `>= 18`
- Docker (only if you want to use the Kali pentest container)

## Kali pentest container (optional)

Build the image and launch a persistent container with VPN support:

```bash
docker build -t kali-htb -f docker/Dockerfile.kali .
./docker/start-kali.sh /path/to/vpn.ovpn <target-ip>
```

The agent then runs tools inside the container via `docker exec kali-pentest <command>`. Reports and evidence are persisted to `./reports/` through a mounted volume. Full methodology, phase-by-phase tooling, and execution patterns are documented in [CLAUDE.md](CLAUDE.md).

## Verify

For Claude:

```bash
cd /your-workspace
claude mcp list
```

Expected project MCPs:

- `burpsuite`
- `chrome-devtools`

For Codex:

```bash
codex mcp list
curl -i --max-time 3 http://127.0.0.1:9876
```

Expected Codex MCPs:

- `burp`
- `burp-browser`

Expected SSE signal:

- `Content-Type: text/event-stream`

Note: `curl` can time out after printing the headers because SSE stays open by design. A visible `text/event-stream` header is healthy.

## Manual setup

Run the script without writing MCP config:

```bash
./setup.sh --manual-mcp --client codex /your-workspace
./setup.sh --manual-mcp --client claude /your-workspace
```

Claude project MCPs:

```bash
cd /your-workspace
claude mcp add -s project -t sse burpsuite http://localhost:9876/
claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath "/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated
```

Codex global MCPs:

```bash
codex mcp add burp -- "/Applications/Burp Suite Professional.app/Contents/Resources/jre.bundle/Contents/Home/bin/java" -jar "$HOME/.BurpSuite/mcp-proxy/mcp-proxy-all.jar" --sse-url http://127.0.0.1:9876
codex mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path "/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated
```

If you prefer editing Codex config directly, see [mcp-example.toml](mcp-example.toml).

## Included files

- [CLAUDE.md](CLAUDE.md) is the full pentesting framework reference for the AI agent
- [docker/Dockerfile.kali](docker/Dockerfile.kali) builds the Kali pentest image
- [docker/start-kali.sh](docker/start-kali.sh) launches the container with VPN and report volumes
- [.mcp.json](.mcp.json) is the Claude MCP example
- [settings.local.json](settings.local.json) is the Claude local permission template
- [mcp-example.toml](mcp-example.toml) is the Codex MCP example
- [skills/openburp-codex/SKILL.md](skills/openburp-codex/SKILL.md) is the Codex skill bundled with this repo
- [examples/xss-lab-walkthrough.md](examples/xss-lab-walkthrough.md) shows an example workflow

## Recommended Burp config

Import `burp-configs/scope-exclude-noise.json`:

1. Burp -> Project options -> Load from file
2. Select `burp-configs/scope-exclude-noise.json`

## Troubleshooting

- `burpsuite` disconnected in Claude: confirm Burp is open and the `MCP Server` tab is healthy
- `burp` disconnected in Codex: confirm Burp is open, the `MCP Server` tab is healthy, and `~/.BurpSuite/mcp-proxy/mcp-proxy-all.jar` exists
- `burp-browser` disconnected: run `npx -y @playwright/mcp@latest --help`
- Wrong Chromium path: rerun setup and provide the path manually
- New Codex tools not visible yet: restart Codex Desktop or start a new thread after `codex mcp add`
- Raw `burp` requests may not appear in `Proxy > HTTP history`; use `burp-browser` when you want traffic recorded by the proxy listener

## Safety

Use this repo only on systems, labs, staging environments, or domains you are explicitly authorized to test.
