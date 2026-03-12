#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AUTO_MCP=1
CLIENT_MODE="auto"
WORKSPACE_ARG=""
TARGET_CODEX=0
TARGET_CLAUDE=0

CODEX_CMD=""
CLAUDE_CMD=""
CHROMIUM_PATH=""
BURP_JAVA=""
PROXY_JAR=""

usage() {
    echo "Usage: $0 [--manual-mcp] [--client auto|claude|codex|both] [workspace_path]"
    echo ""
    echo "Options:"
    echo "  --manual-mcp   Skip automatic MCP registration and print manual commands"
    echo "  --client       Select which client to configure (default: auto)"
}

print_banner() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  OpenBurp - Burp Suite setup for Claude Code and Codex${NC}"
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manual-mcp)
            AUTO_MCP=0
            shift
            ;;
        --client)
            CLIENT_MODE="${2:-}"
            if [[ -z "$CLIENT_MODE" ]]; then
                print_error "--client requires a value"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$WORKSPACE_ARG" ]]; then
                WORKSPACE_ARG="$1"
                shift
            else
                print_error "Unexpected argument: $1"
                usage
                exit 1
            fi
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE_ARG:-$(pwd)}"

resolve_codex() {
    if command -v codex >/dev/null 2>&1; then
        CODEX_CMD="$(command -v codex)"
        return 0
    fi

    if [[ -x "/Applications/Codex.app/Contents/Resources/codex" ]]; then
        CODEX_CMD="/Applications/Codex.app/Contents/Resources/codex"
        return 0
    fi

    return 1
}

resolve_clients() {
    local codex_available=0
    local claude_available=0

    if resolve_codex; then
        codex_available=1
    fi

    if command -v claude >/dev/null 2>&1; then
        claude_available=1
        CLAUDE_CMD="$(command -v claude)"
    fi

    case "$CLIENT_MODE" in
        codex)
            TARGET_CODEX=1
            ;;
        claude)
            TARGET_CLAUDE=1
            ;;
        both)
            TARGET_CODEX=1
            TARGET_CLAUDE=1
            ;;
        auto)
            if [[ "$codex_available" -eq 1 ]]; then
                TARGET_CODEX=1
            fi
            if [[ "$claude_available" -eq 1 ]]; then
                TARGET_CLAUDE=1
            fi
            if [[ "$TARGET_CODEX" -eq 0 && "$TARGET_CLAUDE" -eq 0 ]]; then
                print_error "No supported client detected. Install Codex Desktop/CLI or use --client claude to let setup install Claude Code."
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported --client value: $CLIENT_MODE"
            usage
            exit 1
            ;;
    esac
}

detect_burp_chromium() {
    local detected=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        detected="$(find "/Applications/Burp Suite Professional.app" -path "*Chromium.app/Contents/MacOS/Chromium" -type f 2>/dev/null | head -n 1)"
        if [[ -z "$detected" ]]; then
            detected="$(find "/Applications" -path "*Burp*Chromium.app/Contents/MacOS/Chromium" -type f 2>/dev/null | head -n 1)"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detected="$(find /opt /usr/local -type f \( -name chromium -o -name chrome \) 2>/dev/null | grep -i burp | head -n 1 || true)"
    fi

    if [[ -n "$detected" ]]; then
        CHROMIUM_PATH="$detected"
        print_step "Burp Chromium found: $CHROMIUM_PATH"
        return
    fi

    print_warn "Could not auto-detect Burp Chromium."
    read -r -p "Path to Burp Chromium executable: " CHROMIUM_PATH
    if [[ ! -f "$CHROMIUM_PATH" ]]; then
        print_error "File does not exist: $CHROMIUM_PATH"
        exit 1
    fi
}

detect_burp_java() {
    local detected=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        detected="/Applications/Burp Suite Professional.app/Contents/Resources/jre.bundle/Contents/Home/bin/java"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detected="$(find /opt /usr/local -path "*burp*bin/java" -type f 2>/dev/null | head -n 1 || true)"
    fi

    if [[ -n "$detected" && -x "$detected" ]]; then
        BURP_JAVA="$detected"
        print_step "Burp Java found: $BURP_JAVA"
        return
    fi

    if command -v java >/dev/null 2>&1; then
        BURP_JAVA="$(command -v java)"
        print_warn "Using system Java: $BURP_JAVA"
        return
    fi

    print_error "Could not find Java for the Burp MCP proxy."
    exit 1
}

ensure_proxy_jar() {
    local extension_jar

    PROXY_JAR="${HOME}/.BurpSuite/mcp-proxy/mcp-proxy-all.jar"
    extension_jar="${HOME}/.BurpSuite/bapps/9952290f04ed4f628e624d0aa9dccebc/burp-mcp-all.jar"

    if [[ -f "$PROXY_JAR" ]]; then
        print_step "Burp MCP proxy jar found: $PROXY_JAR"
        return
    fi

    if [[ ! -f "$extension_jar" ]]; then
        print_error "Could not find Burp MCP extension jar to extract the proxy from."
        exit 1
    fi

    mkdir -p "$(dirname "$PROXY_JAR")"

    python3 - <<'PY'
import os
import pathlib
import sys
import zipfile

extension_jar = pathlib.Path(os.path.expanduser("~/.BurpSuite/bapps/9952290f04ed4f628e624d0aa9dccebc/burp-mcp-all.jar"))
proxy_jar = pathlib.Path(os.path.expanduser("~/.BurpSuite/mcp-proxy/mcp-proxy-all.jar"))

with zipfile.ZipFile(extension_jar) as zf:
    target = next((name for name in zf.namelist() if name.endswith("mcp-proxy-all.jar")), None)
    if not target:
        print("Proxy jar not found inside Burp MCP extension.", file=sys.stderr)
        sys.exit(1)
    proxy_jar.write_bytes(zf.read(target))
PY

    if [[ -f "$PROXY_JAR" ]]; then
        print_step "Extracted Burp MCP proxy jar: $PROXY_JAR"
    else
        print_error "Failed to extract Burp MCP proxy jar."
        exit 1
    fi
}

check_runtime_health() {
    local response=""

    if command -v curl >/dev/null 2>&1; then
        response="$(curl -is --max-time 3 http://127.0.0.1:9876 2>/dev/null || true)"
        if printf '%s' "$response" | grep -qi "text/event-stream"; then
            print_step "Burp MCP SSE responds on http://127.0.0.1:9876"
        else
            print_warn "Burp MCP SSE did not respond on http://127.0.0.1:9876"
        fi
    fi

    if command -v lsof >/dev/null 2>&1; then
        if lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -q "127.0.0.1:8080"; then
            print_step "Burp proxy is listening on 127.0.0.1:8080"
        else
            print_warn "Burp proxy is not listening on 127.0.0.1:8080"
        fi
    fi
}

setup_claude() {
    if command -v claude >/dev/null 2>&1; then
        CLAUDE_CMD="$(command -v claude)"
        print_step "Claude Code found: $("$CLAUDE_CMD" --version 2>/dev/null || echo installed)"
    else
        print_warn "Claude Code not found. Installing..."
        npm install -g @anthropic-ai/claude-code
        CLAUDE_CMD="$(command -v claude || true)"
        if [[ -z "$CLAUDE_CMD" ]]; then
            print_error "Could not install Claude Code."
            exit 1
        fi
        print_step "Claude Code installed successfully."
    fi

    if command -v chrome-devtools-mcp >/dev/null 2>&1; then
        print_step "chrome-devtools-mcp is already installed."
    else
        npm install -g chrome-devtools-mcp
        if ! command -v chrome-devtools-mcp >/dev/null 2>&1; then
            print_error "Could not install chrome-devtools-mcp."
            exit 1
        fi
        print_step "chrome-devtools-mcp installed successfully."
    fi

    mkdir -p "$WORKSPACE/.claude"
    cp "$SCRIPT_DIR/settings.local.json" "$WORKSPACE/.claude/settings.local.json"
    print_step "Claude permissions copied to $WORKSPACE/.claude/settings.local.json"

    if [[ "$AUTO_MCP" -eq 1 ]]; then
        if (
            cd "$WORKSPACE" && \
            "$CLAUDE_CMD" mcp remove -s project burpsuite >/dev/null 2>&1 || true
        ) && (
            cd "$WORKSPACE" && \
            "$CLAUDE_CMD" mcp remove -s project chrome-devtools >/dev/null 2>&1 || true
        ) && (
            cd "$WORKSPACE" && \
            "$CLAUDE_CMD" mcp add -s project -t sse burpsuite http://localhost:9876/ >/dev/null
        ) && (
            cd "$WORKSPACE" && \
            "$CLAUDE_CMD" mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath "$CHROMIUM_PATH" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated >/dev/null
        ); then
            print_step "Claude MCP servers configured for $WORKSPACE"
        else
            print_warn "Could not auto-configure Claude MCPs."
            print_info "Manual Claude commands:"
            echo "  cd \"$WORKSPACE\""
            echo "  claude mcp add -s project -t sse burpsuite http://localhost:9876/"
            echo "  claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath \"$CHROMIUM_PATH\" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated"
        fi
    else
        print_info "Manual Claude commands:"
        echo "  cd \"$WORKSPACE\""
        echo "  claude mcp add -s project -t sse burpsuite http://localhost:9876/"
        echo "  claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath \"$CHROMIUM_PATH\" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated"
    fi
}

install_codex_skill() {
    local codex_home skill_target

    codex_home="${CODEX_HOME:-$HOME/.codex}"
    skill_target="$codex_home/skills/openburp-codex"

    mkdir -p "$skill_target"
    cp -R "$SCRIPT_DIR/skills/openburp-codex/." "$skill_target/"
    print_step "Codex skill installed at $skill_target"
}

setup_codex() {
    if ! resolve_codex; then
        print_error "Codex CLI not found. Install Codex Desktop/CLI first."
        exit 1
    fi

    print_step "Codex found: $("$CODEX_CMD" --version)"
    install_codex_skill

    if [[ "$AUTO_MCP" -eq 1 ]]; then
        if (
            "$CODEX_CMD" mcp remove burp >/dev/null 2>&1 || true
        ) && (
            "$CODEX_CMD" mcp remove burp-browser >/dev/null 2>&1 || true
        ) && (
            "$CODEX_CMD" mcp add burp -- "$BURP_JAVA" -jar "$PROXY_JAR" --sse-url http://127.0.0.1:9876 >/dev/null
        ) && (
            "$CODEX_CMD" mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path "$CHROMIUM_PATH" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated >/dev/null
        ); then
            print_step "Codex MCP servers configured"
        else
            print_warn "Could not auto-configure Codex MCPs."
            print_info "Manual Codex commands:"
            echo "  $CODEX_CMD mcp add burp -- \"$BURP_JAVA\" -jar \"$PROXY_JAR\" --sse-url http://127.0.0.1:9876"
            echo "  $CODEX_CMD mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path \"$CHROMIUM_PATH\" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated"
        fi
    else
        print_info "Manual Codex commands:"
        echo "  $CODEX_CMD mcp add burp -- \"$BURP_JAVA\" -jar \"$PROXY_JAR\" --sse-url http://127.0.0.1:9876"
        echo "  $CODEX_CMD mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path \"$CHROMIUM_PATH\" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated"
    fi
}

print_banner
print_info "Workspace: $WORKSPACE"
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

if command -v node >/dev/null 2>&1; then
    print_step "Node.js found: $(node --version)"
else
    print_error "Node.js not found. Install Node.js >= 18."
    exit 1
fi

if command -v npm >/dev/null 2>&1; then
    print_step "npm found: $(npm --version)"
else
    print_error "npm not found."
    exit 1
fi

if command -v npx >/dev/null 2>&1; then
    print_step "npx found"
else
    print_error "npx not found."
    exit 1
fi

resolve_clients

print_info "Client selection:"
[[ "$TARGET_CLAUDE" -eq 1 ]] && echo "  - Claude Code"
[[ "$TARGET_CODEX" -eq 1 ]] && echo "  - Codex"

echo ""
echo -e "${YELLOW}Looking for Burp Suite runtime...${NC}"
detect_burp_chromium
detect_burp_java
ensure_proxy_jar
check_runtime_health

if [[ "$TARGET_CLAUDE" -eq 1 ]]; then
    echo ""
    echo -e "${YELLOW}Configuring Claude Code...${NC}"
    setup_claude
fi

if [[ "$TARGET_CODEX" -eq 1 ]]; then
    echo ""
    echo -e "${YELLOW}Configuring Codex...${NC}"
    setup_codex
fi

echo ""
echo -e "${GREEN}Pre-flight checklist:${NC}"
echo "  [ ] Burp Suite Professional is open"
echo "  [ ] Burp BApp 'MCP Server' is installed and healthy"
echo "  [ ] Burp proxy listens on 127.0.0.1:8080"
echo "  [ ] Burp MCP SSE responds on 127.0.0.1:9876"
[[ "$TARGET_CLAUDE" -eq 1 ]] && echo "  [ ] Claude Code authenticated if needed"
[[ "$TARGET_CODEX" -eq 1 ]] && echo "  [ ] Restart Codex Desktop or open a new thread after setup"
echo ""
print_step "Setup complete."
