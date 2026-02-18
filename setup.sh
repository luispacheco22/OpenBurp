#!/bin/bash
# ============================================================
# Claude Code + Burp Suite - Automated Setup Script
# ============================================================
# This script installs and configures everything needed to use
# Claude Code with Burp Suite Professional for pentesting.
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AUTO_MCP=1
WORKSPACE_ARG=""

usage() {
    echo "Usage: $0 [--manual-mcp] [workspace_path]"
    echo ""
    echo "Options:"
    echo "  --manual-mcp   Skip automatic 'claude mcp add' and only print manual steps"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manual-mcp)
            AUTO_MCP=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [ -z "$WORKSPACE_ARG" ]; then
                WORKSPACE_ARG="$1"
                shift
            else
                echo "Error: Unexpected argument: $1"
                usage
                exit 1
            fi
            ;;
    esac
done

print_banner() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  Claude Code + Burp Suite - AI-Powered Pentesting Setup${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[x]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# ---- Pre-flight checks ----

print_banner

echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_step "Node.js found: $NODE_VERSION"
else
    print_error "Node.js not found. Install Node.js >= 18 from https://nodejs.org"
    exit 1
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_step "npm found: $NPM_VERSION"

    NPM_PREFIX=$(npm config get prefix 2>/dev/null || true)
    if [ -n "$NPM_PREFIX" ] && [ -d "$NPM_PREFIX/bin" ]; then
        export PATH="$NPM_PREFIX/bin:$PATH"
    fi
else
    print_error "npm not found."
    exit 1
fi

# Check Claude Code
if command -v claude &> /dev/null; then
    print_step "Claude Code found: $(claude --version 2>/dev/null || echo 'installed')"
else
    print_warn "Claude Code not found. Installing..."
    npm install -g @anthropic-ai/claude-code
    if command -v claude &> /dev/null; then
        print_step "Claude Code installed successfully."
    else
        print_error "Could not install Claude Code. Try manually: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
fi

# ---- Install Chrome DevTools MCP ----

echo ""
echo -e "${YELLOW}Installing Chrome DevTools MCP Server...${NC}"

if command -v chrome-devtools-mcp &> /dev/null; then
    print_step "chrome-devtools-mcp is already installed."
else
    npm install -g @anthropic-ai/chrome-devtools-mcp
    if command -v chrome-devtools-mcp &> /dev/null; then
        print_step "chrome-devtools-mcp installed successfully."
    else
        print_error "Could not install chrome-devtools-mcp."
        exit 1
    fi
fi

# ---- Detect Burp Chromium path ----

echo ""
echo -e "${YELLOW}Looking for Burp Suite's Chromium...${NC}"

CHROMIUM_PATH=""

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CHROMIUM_PATH=$(find "/Applications/Burp Suite Professional.app" -name "Chromium" -path "*/MacOS/*" -type f 2>/dev/null | head -1)
    if [ -z "$CHROMIUM_PATH" ]; then
        CHROMIUM_PATH=$(find "/Applications" -name "Chromium" -path "*burp*" -type f 2>/dev/null | head -1)
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    CHROMIUM_PATH=$(find /opt -name "chromium" -o -name "chrome" 2>/dev/null | grep -i burp | head -1)
fi

if [ -n "$CHROMIUM_PATH" ]; then
    print_step "Burp's Chromium found: $CHROMIUM_PATH"
else
    print_warn "Could not auto-detect Burp's Chromium."
    print_info "You can use any Chromium/Chrome. Enter the path manually:"
    read -rp "Path to Chromium executable: " CHROMIUM_PATH
    if [ ! -f "$CHROMIUM_PATH" ]; then
        print_error "File does not exist: $CHROMIUM_PATH"
        exit 1
    fi
fi

# ---- Setup workspace ----

echo ""
echo -e "${YELLOW}Setting up workspace...${NC}"

WORKSPACE="${WORKSPACE_ARG:-$(pwd)}"
print_info "Workspace: $WORKSPACE"

# Create .claude directory
mkdir -p "$WORKSPACE/.claude"

# Copy settings.local.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/settings.local.json" ]; then
    cp "$SCRIPT_DIR/settings.local.json" "$WORKSPACE/.claude/settings.local.json"
    print_step "Permissions copied to .claude/settings.local.json"
fi

# ---- Configure MCP servers automatically ----

MCP_AUTO_CONFIGURED=0

if [ "$AUTO_MCP" -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Configuring MCP servers automatically (project scope)...${NC}"

    if (
        cd "$WORKSPACE" && \
        claude mcp remove -s project burpsuite >/dev/null 2>&1 || true
    ) && (
        cd "$WORKSPACE" && \
        claude mcp remove -s project chrome-devtools >/dev/null 2>&1 || true
    ) && (
        cd "$WORKSPACE" && \
        claude mcp remove -s project demo-local-only >/dev/null 2>&1 || true
    ) && (
        cd "$WORKSPACE" && \
        claude mcp add -s project -t sse burpsuite http://localhost:9876/ >/dev/null
    ) && (
        cd "$WORKSPACE" && \
        claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath "$CHROMIUM_PATH" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated >/dev/null
    ); then
        MCP_AUTO_CONFIGURED=1
        print_step "MCP servers added automatically for: $WORKSPACE"
    else
        print_warn "Could not auto-configure MCP servers. Falling back to manual instructions."
    fi
fi

# ---- Print MCP configuration instructions if needed ----

if [ "$MCP_AUTO_CONFIGURED" -ne 1 ]; then
    echo ""
    echo -e "${YELLOW}============================================================${NC}"
    echo -e "${YELLOW}  MANUAL CONFIGURATION REQUIRED${NC}"
    echo -e "${YELLOW}============================================================${NC}"
    echo ""
    echo -e "Open Claude Code in your workspace and run ${GREEN}/mcp${NC} to add the servers:"
    echo ""
    echo -e "${BLUE}--- Server 1: Burp Suite ---${NC}"
    echo "  Name:  burpsuite"
    echo "  Type:  sse"
    echo "  URL:   http://localhost:9876/"
    echo ""
    echo -e "${BLUE}--- Server 2: Chrome DevTools ---${NC}"
    echo "  Name:    chrome-devtools"
    echo "  Type:    stdio"
    echo "  Command: chrome-devtools-mcp"
    echo "  Args:"
    echo "    --executablePath"
    echo "    $CHROMIUM_PATH"
    echo "    --proxy-server=http://127.0.0.1:8080"
    echo "    --accept-insecure-certs"
    echo "    --isolated"
    echo ""
    echo -e "${YELLOW}============================================================${NC}"
    echo ""
fi

# ---- Checklist ----

echo -e "${GREEN}Pre-flight checklist:${NC}"
echo "  [ ] Burp Suite Professional is open"
echo "  [ ] 'MCP Server' extension installed in Burp (BApp Store)"
echo "  [ ] Burp proxy listening on 127.0.0.1:8080"
echo "  [ ] Claude Code authenticated (claude login)"
if [ "$MCP_AUTO_CONFIGURED" -eq 1 ]; then
    echo "  [x] MCP servers added automatically (project scope)"
else
    echo "  [ ] MCP servers added via /mcp in Claude Code"
fi
echo ""
print_step "Setup complete. Run 'claude' in $WORKSPACE to get started."
