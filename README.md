# Claude Code + Burp Suite - AI-Powered Pentesting Setup

A complete setup to integrate **Claude Code** (Anthropic's CLI) with **Burp Suite Professional** and **Chrome DevTools** via MCP (Model Context Protocol), allowing AI to control the browser and Burp Suite for AI-assisted security testing.

## What does this setup do?

- Claude Code can **send HTTP requests** through Burp Suite (Repeater, Intruder)
- Claude Code can **control a Chromium browser** (navigate, click, fill forms, take screenshots)
- The browser is **proxied through Burp Suite**, so all traffic flows through Burp
- Claude Code can **read the proxy history**, analyze responses, and use Burp Collaborator
- Ideal for: web pentesting, PortSwigger labs, bug bounty, CTFs

## Architecture

```
+------------------+       MCP (stdio)       +--------------------+
|                  | <---------------------> |  Chrome DevTools   |
|   Claude Code    |                         |  MCP Server        |
|   (Terminal)     |       MCP (SSE)         +--------+-----------+
|                  | <---------------------> |        |
+------------------+     localhost:9876      | Chromium Browser
                         |                  | (Burp Embedded)
                   +-----+------+           |        |
                   | Burp Suite |           |        |
                   | Professional| <--------+--------+
                   | :8080      |    Proxy HTTP/S
                   +------------+
```

## Prerequisites

| Requirement | Version | Link |
|-------------|---------|------|
| **Claude Code** | >= 2.x | Included with Claude Pro/Max subscription |
| **Burp Suite Professional** | >= 2024.x | https://portswigger.net/burp/pro |
| **Node.js** | >= 18 | https://nodejs.org |
| **npm** | >= 9 | Included with Node.js |

> **Note:** Burp Suite Community Edition does NOT include the MCP API. **Burp Suite Professional** is required.

## Installation

### One-command setup (recommended)

```bash
cd /path/to/claude-burp-pentest-setup
./setup.sh /your-workspace
```

By default, the script now:
- Installs Claude Code if missing
- Installs `chrome-devtools-mcp` if missing
- Detects Burp's Chromium path
- Copies `.claude/settings.local.json` to your target workspace
- Adds MCP servers automatically in **project scope** (`burpsuite` and `chrome-devtools`)

If you want manual MCP setup, run:

```bash
./setup.sh --manual-mcp /your-workspace
```

### Step 1: Install Claude Code

```bash
# If you don't have Claude Code installed yet
npm install -g @anthropic-ai/claude-code
```

### Step 2: Install Chrome DevTools MCP Server

```bash
npm install -g @anthropic-ai/chrome-devtools-mcp
```

Verify the installation:

```bash
chrome-devtools-mcp --help
```

### Step 3: Enable the MCP Server in Burp Suite

1. Open **Burp Suite Professional**
2. Go to **Extensions > BApp Store**
3. Search for **"MCP Server"** (by PortSwigger)
4. Click **Install**
5. Verify the MCP server is running in the **Extensions > MCP Server** tab
6. By default it listens on `http://localhost:9876/`

### Step 4: Configure Claude Code

> If you used `./setup.sh`, this step is automatic by default. Use it only if you ran with `--manual-mcp` or if auto-configuration failed.

Navigate to your working directory and launch Claude Code:

```bash
cd ~/your-pentesting-workspace
claude
```

Inside Claude Code, run the following command to register the MCP servers:

```
/mcp
```

Then add each server:

#### Add Burp Suite MCP (SSE):

Select "Add MCP server" and configure:
- **Name:** `burpsuite`
- **Type:** `sse`
- **URL:** `http://localhost:9876/`

#### Add Chrome DevTools MCP (stdio):

Select "Add MCP server" and configure:
- **Name:** `chrome-devtools`
- **Type:** `stdio`
- **Command:** `chrome-devtools-mcp`

**Args** (one per line):

```
--executablePath
/Applications/Burp Suite Professional.app/Contents/Resources/app/burpbrowser/145.0.7632.46/Chromium.app/Contents/MacOS/Chromium
--proxy-server=http://127.0.0.1:8080
--accept-insecure-certs
--isolated
```

> **Important:** The `--executablePath` depends on your Burp version. Verify the correct path on your system.

##### Finding Burp's Chromium path

**macOS:**
```bash
find "/Applications/Burp Suite Professional.app" -name "Chromium" -type f 2>/dev/null
```

**Linux:**
```bash
find /opt/BurpSuitePro -name "chromium" -o -name "chrome" 2>/dev/null
```

**Windows:**
```powershell
Get-ChildItem -Path "C:\Program Files\BurpSuitePro" -Recurse -Filter "chrome.exe" | Select-Object FullName
```

### Step 5: Verify the connection

Restart Claude Code and verify that the MCP servers are connected:

```
/mcp
```

You should see both servers (`burpsuite` and `chrome-devtools`) with a **connected** status.

## Recommended Permission Settings

Copy the `settings.local.json` file included in this repo to your workspace:

```bash
mkdir -p /your-workspace/.claude
cp settings.local.json /your-workspace/.claude/settings.local.json
```

This pre-authorizes the most commonly used MCP tools to avoid repetitive confirmation prompts during pentesting.

## Recommended Burp Suite Configuration

The `burp-configs/scope-exclude-noise.json` file contains a Burp scope configuration that excludes noisy domains (analytics, social media, CDNs, etc.) and filters static file extensions from the proxy history.

To import in Burp:
1. Go to **Project > Project options > Load from file**
2. Select `burp-configs/scope-exclude-noise.json`

## Usage

Once configured, open Claude Code in your working directory:

```bash
cd ~/your-pentesting-workspace
claude
```

### Example Prompts

**Basic reconnaissance:**
```
Navigate to https://target.com and do an initial recon.
Take a snapshot of the page, check forms and links.
```

**Send request via Burp:**
```
Send a GET request to https://target.com/api/users via Burp
and analyze the response.
```

**XSS testing:**
```
Test reflected XSS on the search parameter at https://target.com/?search=test
using different payloads and analyze the WAF responses.
```

**Review proxy history:**
```
Show the last 20 requests from Burp's proxy history
that contain "api" in the URL.
```

**Burp Collaborator (OOB testing):**
```
Generate a Burp Collaborator payload and inject it into the
X-Forwarded-Host header to detect SSRF.
```

## Repository Structure

```
claude-burp-pentest-setup/
├── README.md                           # This file
├── setup.sh                            # Automated installation script
├── settings.local.json                 # Recommended permissions for Claude Code
├── burp-configs/
│   └── scope-exclude-noise.json        # Scope/filter config for Burp
└── examples/
    └── xss-lab-walkthrough.md          # Real lab solved with this setup
```

## Troubleshooting

### Burp MCP won't connect
- Verify that Burp Suite is open and the MCP Server extension is installed
- Check that port 9876 is free: `lsof -i :9876`
- Check the Extensions tab in Burp for errors

### Chrome DevTools won't open the browser
- Verify the Chromium executable path
- Make sure no other Chromium instance is running with the same profile
- The `--isolated` flag prevents profile conflicts

### Traffic is not going through Burp
- Verify that the `--proxy-server=http://127.0.0.1:8080` flag is configured
- Check that Burp is listening on port 8080
- The `--accept-insecure-certs` flag is required for HTTPS interception

### Claude Code doesn't show MCP tools
- Run `/mcp` inside Claude Code to check the status
- If a server is disconnected, restart Claude Code
- Verify that `chrome-devtools-mcp` is in your PATH: `which chrome-devtools-mcp`

## License

This project is for educational and authorized security testing purposes only.
Use it responsibly and ethically, always with explicit authorization from the target system owner.
