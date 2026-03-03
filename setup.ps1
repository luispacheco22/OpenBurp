# =============================================================================
# OpenBurp Windows Setup - Claude Code + Burp Suite Pro + Chrome DevTools MCP
# Adapted from https://github.com/luispacheco22/OpenBurp
# =============================================================================

param(
    [string]$Workspace = "",
    [switch]$ManualMCP
)

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$msg) Write-Host "  [X] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host "  OpenBurp Windows Setup"
Write-Host "  Claude Code + Burp Suite Pro + Chrome DevTools MCP"
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host ""

# --- Resolve workspace ---
if (-not $Workspace) {
    $Workspace = $PSScriptRoot
}
$Workspace = (Resolve-Path $Workspace -ErrorAction SilentlyContinue) ?? $Workspace
if (-not (Test-Path $Workspace)) {
    New-Item -ItemType Directory -Path $Workspace -Force | Out-Null
}
Write-Step "Workspace: $Workspace"

# --- Check Node.js ---
Write-Step "Checking Node.js..."
try {
    $nodeVersion = (node --version 2>$null)
    $major = [int]($nodeVersion -replace '^v','').Split('.')[0]
    if ($major -lt 18) {
        Write-Err "Node.js >= 18 required (found $nodeVersion). Please upgrade."
        exit 1
    }
    Write-Ok "Node.js $nodeVersion"
} catch {
    Write-Err "Node.js not found. Install from https://nodejs.org (>= v18)"
    exit 1
}

# --- Check npm ---
Write-Step "Checking npm..."
try {
    $npmVersion = (npm --version 2>$null)
    Write-Ok "npm $npmVersion"
} catch {
    Write-Err "npm not found."
    exit 1
}

# --- Check Claude Code ---
Write-Step "Checking Claude Code..."
$claudePath = (Get-Command claude -ErrorAction SilentlyContinue)
if ($claudePath) {
    Write-Ok "Claude Code found at $($claudePath.Source)"
} else {
    Write-Warn "Claude Code not found. Installing via npm..."
    npm install -g @anthropic-ai/claude-code
    $claudePath = (Get-Command claude -ErrorAction SilentlyContinue)
    if ($claudePath) {
        Write-Ok "Claude Code installed"
    } else {
        Write-Err "Failed to install Claude Code. Install manually: npm install -g @anthropic-ai/claude-code"
        exit 1
    }
}

# --- Install chrome-devtools-mcp ---
Write-Step "Checking chrome-devtools-mcp..."
$cdtMcp = (Get-Command chrome-devtools-mcp -ErrorAction SilentlyContinue)
if ($cdtMcp) {
    Write-Ok "chrome-devtools-mcp found at $($cdtMcp.Source)"
} else {
    Write-Warn "Installing chrome-devtools-mcp globally..."
    npm install -g chrome-devtools-mcp
    $cdtMcp = (Get-Command chrome-devtools-mcp -ErrorAction SilentlyContinue)
    if ($cdtMcp) {
        Write-Ok "chrome-devtools-mcp installed"
    } else {
        Write-Err "Failed to install chrome-devtools-mcp."
        exit 1
    }
}

# --- Detect Burp Suite Chromium ---
Write-Step "Detecting Burp Suite embedded Chromium..."
$burpChromium = $null

# Common Windows paths for Burp Suite Pro's embedded Chromium
$searchPaths = @(
    "$env:LOCALAPPDATA\BurpSuitePro\burpbrowser",
    "$env:LOCALAPPDATA\BurpSuiteProfessional\burpbrowser",
    "$env:ProgramFiles\BurpSuitePro\burpbrowser",
    "${env:ProgramFiles(x86)}\BurpSuitePro\burpbrowser",
    "D:\Users\$env:USERNAME\AppData\Local\BurpSuitePro\burpbrowser"
)

foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        $chromeExe = Get-ChildItem -Path $basePath -Recurse -Filter "chrome.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($chromeExe) {
            $burpChromium = $chromeExe.FullName
            break
        }
    }
}

if (-not $burpChromium) {
    Write-Warn "Could not auto-detect Burp Chromium."
    $burpChromium = Read-Host "Enter the full path to Burp's chrome.exe"
}

if (-not (Test-Path $burpChromium)) {
    Write-Err "Chromium not found at: $burpChromium"
    exit 1
}
Write-Ok "Burp Chromium: $burpChromium"

# --- Setup .claude directory and permissions ---
Write-Step "Setting up workspace permissions..."
$claudeDir = Join-Path $Workspace ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

$settingsPath = Join-Path $claudeDir "settings.local.json"
$settingsContent = @'
{
  "permissions": {
    "allow": [
      "mcp__burpsuite__send_http1_request",
      "mcp__burpsuite__send_http2_request",
      "mcp__burpsuite__create_repeater_tab",
      "mcp__burpsuite__send_to_intruder",
      "mcp__burpsuite__url_encode",
      "mcp__burpsuite__url_decode",
      "mcp__burpsuite__base64_encode",
      "mcp__burpsuite__base64_decode",
      "mcp__burpsuite__generate_random_string",
      "mcp__burpsuite__output_project_options",
      "mcp__burpsuite__get_proxy_http_history",
      "mcp__burpsuite__get_proxy_http_history_regex",
      "mcp__burpsuite__get_proxy_websocket_history",
      "mcp__burpsuite__get_proxy_websocket_history_regex",
      "mcp__burpsuite__get_scanner_issues",
      "mcp__burpsuite__generate_collaborator_payload",
      "mcp__burpsuite__get_collaborator_interactions",
      "mcp__chrome-devtools__navigate_page",
      "mcp__chrome-devtools__take_screenshot",
      "mcp__chrome-devtools__take_snapshot",
      "mcp__chrome-devtools__click",
      "mcp__chrome-devtools__hover",
      "mcp__chrome-devtools__fill",
      "mcp__chrome-devtools__fill_form",
      "mcp__chrome-devtools__press_key",
      "mcp__chrome-devtools__wait_for",
      "mcp__chrome-devtools__evaluate_script",
      "mcp__chrome-devtools__list_pages",
      "mcp__chrome-devtools__select_page",
      "mcp__chrome-devtools__new_page",
      "mcp__chrome-devtools__close_page",
      "mcp__chrome-devtools__handle_dialog",
      "mcp__chrome-devtools__list_network_requests",
      "mcp__chrome-devtools__get_network_request",
      "mcp__chrome-devtools__list_console_messages",
      "WebFetch(domain:portswigger.net)",
      "WebFetch(domain:github.com)",
      "WebSearch",
      "Bash(node --version:*)",
      "Bash(npm --version:*)",
      "Bash(npx:*)",
      "Bash(python3:*)",
      "Bash(python:*)"
    ]
  }
}
'@
$settingsContent | Out-File -FilePath $settingsPath -Encoding utf8
Write-Ok "Permissions written to $settingsPath"

# --- Setup .mcp.json ---
Write-Step "Configuring MCP servers..."
$mcpPath = Join-Path $Workspace ".mcp.json"

# Escape backslashes for JSON
$chromiumEscaped = $burpChromium -replace '\\', '\\\\'

$mcpContent = @"
{
  "mcpServers": {
    "burpsuite": {
      "type": "sse",
      "url": "http://localhost:9876/"
    },
    "chrome-devtools": {
      "type": "stdio",
      "command": "chrome-devtools-mcp",
      "args": [
        "--executablePath",
        "$chromiumEscaped",
        "--proxyServer",
        "http://127.0.0.1:8080",
        "--acceptInsecureCerts",
        "--isolated"
      ],
      "env": {}
    }
  }
}
"@
$mcpContent | Out-File -FilePath $mcpPath -Encoding utf8
Write-Ok "MCP config written to $mcpPath"

# --- Verify ---
Write-Step "Verifying setup..."
Push-Location $Workspace
try {
    claude mcp list
} catch {
    Write-Warn "Could not run 'claude mcp list'. Verify manually."
}
Pop-Location

# --- Final checklist ---
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pre-flight checklist:" -ForegroundColor Yellow
Write-Host "  1. Open Burp Suite Professional"
Write-Host "  2. Install 'MCP Server' extension from BApp Store"
Write-Host "  3. Confirm Burp proxy on 127.0.0.1:8080"
Write-Host "  4. Check MCP Server tab is healthy in Burp"
Write-Host "  5. (Optional) Import burp-configs/scope-exclude-noise.json"
Write-Host ""
Write-Host "To start pentesting:" -ForegroundColor Cyan
Write-Host "  cd $Workspace"
Write-Host "  claude"
Write-Host ""

if ($ManualMCP) {
    Write-Host "Manual MCP registration commands:" -ForegroundColor Yellow
    Write-Host "  cd $Workspace"
    Write-Host "  claude mcp add -s project -t sse burpsuite http://localhost:9876/"
    Write-Host "  claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath `"$burpChromium`" --proxyServer http://127.0.0.1:8080 --acceptInsecureCerts --isolated"
    Write-Host ""
}
