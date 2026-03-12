param(
    [string]$Workspace = "",
    [ValidateSet("auto", "claude", "codex", "both")]
    [string]$Client = "auto",
    [switch]$ManualMCP
)

$ErrorActionPreference = "Stop"

$script:TargetClaude = $false
$script:TargetCodex = $false
$script:CodexCmd = $null
$script:ClaudeCmd = $null
$script:BurpChromium = $null
$script:BurpJava = $null
$script:ProxyJar = $null
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Msg) Write-Host "`n[+] $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "  [X] $Msg" -ForegroundColor Red }
function Write-Info { param([string]$Msg) Write-Host "  [i] $Msg" -ForegroundColor Blue }

function Resolve-Codex {
    $cmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $searchRoots = @(
        "$env:LOCALAPPDATA\Programs",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $searchRoots) {
        $candidate = Get-ChildItem -Path $root -Filter "codex.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    return $null
}

function Resolve-Clients {
    $codexCandidate = Resolve-Codex
    $claudeCandidate = (Get-Command claude -ErrorAction SilentlyContinue)

    switch ($Client) {
        "auto" {
            if ($codexCandidate) {
                $script:TargetCodex = $true
                $script:CodexCmd = $codexCandidate
            }
            if ($claudeCandidate) {
                $script:TargetClaude = $true
                $script:ClaudeCmd = $claudeCandidate.Source
            }
            if (-not $script:TargetCodex -and -not $script:TargetClaude) {
                Write-Err "No supported client detected. Install Codex or rerun with -Client claude to let setup install Claude Code."
                exit 1
            }
        }
        "codex" {
            $script:TargetCodex = $true
            $script:CodexCmd = $codexCandidate
        }
        "claude" {
            $script:TargetClaude = $true
            if ($claudeCandidate) {
                $script:ClaudeCmd = $claudeCandidate.Source
            }
        }
        "both" {
            $script:TargetClaude = $true
            $script:TargetCodex = $true
            $script:CodexCmd = $codexCandidate
            if ($claudeCandidate) {
                $script:ClaudeCmd = $claudeCandidate.Source
            }
        }
    }
}

function Test-CommandVersion {
    param(
        [string]$Name,
        [string]$Command,
        [switch]$Required
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        if ($Required) {
            Write-Err "$Name not found."
            exit 1
        }
        return $null
    }

    $version = & $cmd.Source --version 2>$null
    if ($version) {
        Write-Ok "$Name $version"
    } else {
        Write-Ok "$Name found"
    }
    return $cmd.Source
}

function Detect-BurpChromium {
    Write-Step "Detecting Burp Chromium..."

    $searchRoots = @(
        "$env:LOCALAPPDATA\BurpSuitePro\burpbrowser",
        "$env:LOCALAPPDATA\BurpSuiteProfessional\burpbrowser",
        "$env:ProgramFiles\Burp Suite Professional\burpbrowser",
        "${env:ProgramFiles(x86)}\Burp Suite Professional\burpbrowser"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $searchRoots) {
        $candidate = Get-ChildItem -Path $root -Recurse -Filter "chrome.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            $script:BurpChromium = $candidate.FullName
            break
        }
    }

    if (-not $script:BurpChromium) {
        Write-Warn "Could not auto-detect Burp Chromium."
        $script:BurpChromium = Read-Host "Path to Burp chromium executable"
    }

    if (-not (Test-Path $script:BurpChromium)) {
        Write-Err "Chromium not found at: $script:BurpChromium"
        exit 1
    }

    Write-Ok "Burp Chromium: $script:BurpChromium"
}

function Detect-BurpJava {
    Write-Step "Detecting Burp Java..."

    $candidates = @(
        "$env:ProgramFiles\Burp Suite Professional\jre\bin\java.exe",
        "${env:ProgramFiles(x86)}\Burp Suite Professional\jre\bin\java.exe",
        "$env:LOCALAPPDATA\Programs\BurpSuiteProfessional\jre\bin\java.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            $script:BurpJava = $candidate
            break
        }
    }

    if (-not $script:BurpJava) {
        $javaCmd = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCmd) {
            $script:BurpJava = $javaCmd.Source
            Write-Warn "Using system Java: $script:BurpJava"
        }
    }

    if (-not $script:BurpJava) {
        Write-Err "Could not find Java for the Burp MCP proxy."
        exit 1
    }

    Write-Ok "Java: $script:BurpJava"
}

function Ensure-ProxyJar {
    Write-Step "Ensuring Burp MCP proxy jar exists..."

    $proxyDir = Join-Path $HOME ".BurpSuite\mcp-proxy"
    $script:ProxyJar = Join-Path $proxyDir "mcp-proxy-all.jar"
    $extensionJar = Join-Path $HOME ".BurpSuite\bapps\9952290f04ed4f628e624d0aa9dccebc\burp-mcp-all.jar"

    if (Test-Path $script:ProxyJar) {
        Write-Ok "Proxy jar: $script:ProxyJar"
        return
    }

    if (-not (Test-Path $extensionJar)) {
        Write-Err "Could not find the Burp MCP extension jar to extract the proxy."
        exit 1
    }

    New-Item -ItemType Directory -Path $proxyDir -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead($extensionJar)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -like "*mcp-proxy-all.jar" } | Select-Object -First 1
        if (-not $entry) {
            Write-Err "Proxy jar was not found inside the Burp extension jar."
            exit 1
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $script:ProxyJar, $true)
    } finally {
        $zip.Dispose()
    }

    Write-Ok "Proxy jar: $script:ProxyJar"
}

function Check-RuntimeHealth {
    Write-Step "Checking Burp runtime health..."

    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCmd) {
        $response = & $curlCmd.Source -is --max-time 3 http://127.0.0.1:9876 2>$null
        if ($response -match "text/event-stream") {
            Write-Ok "Burp MCP SSE responds on 127.0.0.1:9876"
        } else {
            Write-Warn "Burp MCP SSE did not return a text/event-stream header"
        }
    }

    $netstat = & netstat -ano 2>$null
    if ($netstat -match "127\.0\.0\.1:8080\s+.*LISTENING" -or $netstat -match "0\.0\.0\.0:8080\s+.*LISTENING") {
        Write-Ok "Burp proxy is listening on 127.0.0.1:8080"
    } else {
        Write-Warn "Burp proxy is not listening on 127.0.0.1:8080"
    }

    if ($netstat -match "127\.0\.0\.1:9876\s+.*LISTENING" -or $netstat -match "0\.0\.0\.0:9876\s+.*LISTENING") {
        Write-Ok "Burp MCP port is listening on 127.0.0.1:9876"
    } else {
        Write-Warn "Burp MCP port is not listening on 127.0.0.1:9876"
    }
}

function Setup-Claude {
    Write-Step "Configuring Claude Code..."

    if (-not $script:ClaudeCmd) {
        Write-Warn "Claude Code not found. Installing..."
        npm install -g @anthropic-ai/claude-code
        $claudeCandidate = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $claudeCandidate) {
            Write-Err "Failed to install Claude Code."
            exit 1
        }
        $script:ClaudeCmd = $claudeCandidate.Source
    }

    Write-Ok "Claude Code: $script:ClaudeCmd"

    $chromeDevtools = Get-Command chrome-devtools-mcp -ErrorAction SilentlyContinue
    if (-not $chromeDevtools) {
        Write-Warn "Installing chrome-devtools-mcp..."
        npm install -g @anthropic-ai/chrome-devtools-mcp
        $chromeDevtools = Get-Command chrome-devtools-mcp -ErrorAction SilentlyContinue
        if (-not $chromeDevtools) {
            Write-Err "Failed to install chrome-devtools-mcp."
            exit 1
        }
    }

    Write-Ok "chrome-devtools-mcp: $($chromeDevtools.Source)"

    $claudeDir = Join-Path $Workspace ".claude"
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Copy-Item -Path (Join-Path $script:ScriptDir "settings.local.json") -Destination (Join-Path $claudeDir "settings.local.json") -Force
    Write-Ok "Claude permissions copied to $claudeDir"

    if ($ManualMCP) {
        Write-Info "Manual Claude commands:"
        Write-Host "  cd `"$Workspace`""
        Write-Host "  claude mcp add -s project -t sse burpsuite http://localhost:9876/"
        Write-Host "  claude mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath `"$script:BurpChromium`" --proxy-server=http://127.0.0.1:8080 --accept-insecure-certs --isolated"
        return
    }

    Push-Location $Workspace
    try {
        try { & $script:ClaudeCmd mcp remove -s project burpsuite *> $null } catch {}
        try { & $script:ClaudeCmd mcp remove -s project chrome-devtools *> $null } catch {}

        & $script:ClaudeCmd mcp add -s project -t sse burpsuite http://localhost:9876/ | Out-Null
        & $script:ClaudeCmd mcp add -s project -t stdio chrome-devtools -- chrome-devtools-mcp --executablePath $script:BurpChromium '--proxy-server=http://127.0.0.1:8080' --accept-insecure-certs --isolated | Out-Null
    } finally {
        Pop-Location
    }

    Write-Ok "Claude MCP servers configured for $Workspace"
}

function Install-CodexSkill {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
    $skillSource = Join-Path $script:ScriptDir "skills\openburp-codex"
    $skillTarget = Join-Path $codexHome "skills\openburp-codex"

    if (-not (Test-Path $skillSource)) {
        Write-Err "Missing bundled skill at $skillSource"
        exit 1
    }

    New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null
    Copy-Item -Path (Join-Path $skillSource "*") -Destination $skillTarget -Recurse -Force
    Write-Ok "Codex skill installed at $skillTarget"
}

function Setup-Codex {
    Write-Step "Configuring Codex..."

    if (-not $script:CodexCmd) {
        $script:CodexCmd = Resolve-Codex
    }

    if (-not $script:CodexCmd) {
        Write-Err "Codex CLI not found. Install Codex Desktop or CLI first."
        exit 1
    }

    $codexVersion = & $script:CodexCmd --version 2>$null
    if ($codexVersion) {
        Write-Ok "Codex $codexVersion"
    } else {
        Write-Ok "Codex: $script:CodexCmd"
    }

    Install-CodexSkill

    if ($ManualMCP) {
        Write-Info "Manual Codex commands:"
        Write-Host "  `"$script:CodexCmd`" mcp add burp -- `"$script:BurpJava`" -jar `"$script:ProxyJar`" --sse-url http://127.0.0.1:9876"
        Write-Host "  `"$script:CodexCmd`" mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path `"$script:BurpChromium`" --proxy-server=http://127.0.0.1:8080 --ignore-https-errors --isolated"
        return
    }

    try { & $script:CodexCmd mcp remove burp *> $null } catch {}
    try { & $script:CodexCmd mcp remove burp-browser *> $null } catch {}

    & $script:CodexCmd mcp add burp -- $script:BurpJava -jar $script:ProxyJar --sse-url http://127.0.0.1:9876 | Out-Null
    & $script:CodexCmd mcp add burp-browser -- npx -y @playwright/mcp@latest --executable-path $script:BurpChromium '--proxy-server=http://127.0.0.1:8080' --ignore-https-errors --isolated | Out-Null

    Write-Ok "Codex MCP servers configured"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host "  OpenBurp Windows Setup"
Write-Host "  Burp Suite Pro for Claude Code and Codex"
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host ""

if (-not $Workspace) {
    $Workspace = $PSScriptRoot
}

if (-not (Test-Path $Workspace)) {
    New-Item -ItemType Directory -Path $Workspace -Force | Out-Null
}

$Workspace = (Resolve-Path $Workspace).Path
Write-Step "Workspace: $Workspace"

Write-Step "Checking Node.js..."
$nodePath = Test-CommandVersion -Name "Node.js" -Command "node" -Required
$nodeVersion = node --version
$major = [int](($nodeVersion -replace '^v', '').Split('.')[0])
if ($major -lt 18) {
    Write-Err "Node.js >= 18 required (found $nodeVersion)."
    exit 1
}

Write-Step "Checking npm and npx..."
[void](Test-CommandVersion -Name "npm" -Command "npm" -Required)
$npxPath = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npxPath) {
    Write-Err "npx not found."
    exit 1
}
Write-Ok "npx found"

Resolve-Clients

Write-Step "Client selection"
if ($script:TargetClaude) { Write-Info "Claude Code" }
if ($script:TargetCodex) { Write-Info "Codex" }

Detect-BurpChromium
Detect-BurpJava
Ensure-ProxyJar
Check-RuntimeHealth

if ($script:TargetClaude) {
    Setup-Claude
}

if ($script:TargetCodex) {
    Setup-Codex
}

Write-Host ""
Write-Host "Pre-flight checklist:" -ForegroundColor Yellow
Write-Host "  [ ] Burp Suite Professional is open"
Write-Host "  [ ] Burp BApp 'MCP Server' is installed and healthy"
Write-Host "  [ ] Burp proxy listens on 127.0.0.1:8080"
Write-Host "  [ ] Burp MCP SSE responds on 127.0.0.1:9876"
if ($script:TargetClaude) {
    Write-Host "  [ ] Claude Code authenticated if needed"
}
if ($script:TargetCodex) {
    Write-Host "  [ ] Restart Codex Desktop or open a new thread after setup"
}
Write-Host ""
Write-Host "Recommended Codex prompt:" -ForegroundColor Cyan
Write-Host "  Use `$openburp-codex to verify a target I explicitly control. Start with one request through Burp."
Write-Host ""
