# OpenBurp — AI-Assisted Pentesting Framework

## Project Overview

OpenBurp integrates Claude Code with professional security tools for autonomous and semi-autonomous penetration testing. The framework uses a **Dockerized Kali Linux** container as an isolated attack environment that Claude controls via `docker exec`, combined with Burp Suite MCP and Chrome DevTools MCP for web application analysis.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Claude Code (Host - macOS/Linux/Windows)            │
│  ├── Burp Suite MCP  (web proxy + scanner)           │
│  ├── Chrome DevTools MCP (browser automation)        │
│  └── docker exec ──► Kali Linux Container            │
│                      ├── VPN (OpenVPN / WireGuard)   │
│                      ├── Recon tools (nmap, gobuster)│
│                      ├── Exploit tools (sqlmap, etc) │
│                      ├── Post-exploit (evil-winrm)   │
│                      └── /workspace/report (mounted) │
└─────────────────────────────────────────────────────┘
```

Claude orchestrates everything from the host:
- Runs pentesting commands inside the Kali container via `docker exec kali-pentest <command>`
- Analyzes HTTP traffic through Burp Suite MCP
- Automates browser interactions via Chrome DevTools MCP
- Writes reports and evidence to the mounted `/workspace/report` volume

---

## Kali Docker Setup

### Building the Image

```bash
cd /path/to/OpenBurp
docker build -t kali-htb -f docker/Dockerfile.kali .
```

### Running the Container

```bash
docker run -d \
  --name kali-pentest \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -v /path/to/vpn-config.ovpn:/workspace/vpn.ovpn:ro \
  -v /path/to/reports:/workspace/report \
  kali-htb \
  sleep infinity
```

Key flags:
- `--cap-add=NET_ADMIN` — required for VPN tunnel creation
- `--device=/dev/net/tun` — exposes the TUN device for OpenVPN
- `-v vpn.ovpn:/workspace/vpn.ovpn:ro` — mounts VPN config read-only
- `-v reports:/workspace/report` — shared volume for evidence and reports
- `sleep infinity` — keeps the container running as a persistent shell

### Connecting VPN Inside the Container

```bash
docker exec kali-pentest bash -c \
  "mkdir -p /dev/net && mknod /dev/net/tun c 10 200 2>/dev/null; \
   openvpn --config /workspace/vpn.ovpn --daemon --log /tmp/vpn.log"
```

Verify connectivity:
```bash
docker exec kali-pentest ping -c 2 <TARGET_IP>
```

---

## Pentesting Methodology (How Claude Uses the Tools)

### Phase 1 — Reconnaissance

| Tool | Purpose | Example |
|------|---------|---------|
| `nmap` | Port scanning, service/version detection | `nmap -sC -sV -p- --min-rate 5000 <IP>` |
| `gobuster` | Directory and vhost enumeration | `gobuster dir -u http://target/ -w /usr/share/seclists/Discovery/Web-Content/common.txt` |
| `whatweb` | Web technology fingerprinting | `whatweb http://target/` |
| `nikto` | Web vulnerability scanning | `nikto -h http://target/` |
| `curl` | Manual HTTP requests, header inspection | `curl -s -I http://target/` |
| Burp MCP | Passive proxy history analysis | `mcp__burpsuite__get_proxy_http_history` |

### Phase 2 — Enumeration

| Tool | Purpose | Example |
|------|---------|---------|
| `enum4linux` | SMB/NetBIOS enumeration | `enum4linux -a <IP>` |
| `smbclient` | SMB share listing | `smbclient -L //<IP>/ -N` |
| `crackmapexec` | Multi-protocol credential testing | `crackmapexec smb <IP> -u users.txt -p pass.txt` |
| `python3 requests` | Custom API/OAuth enumeration scripts | Inline Python via `docker exec` |
| Chrome DevTools MCP | Interactive browser automation | `mcp__chrome-devtools__navigate_page` |

### Phase 3 — Exploitation

| Tool | Purpose | Example |
|------|---------|---------|
| `sqlmap` | SQL injection exploitation | `sqlmap -u "http://target/?id=1" --batch` |
| `hydra` | Online password brute forcing | `hydra -l admin -P rockyou.txt http-post-form "..."` |
| `python3` | Custom exploit scripts (OAuth CSRF, SSTI, etc.) | Inline scripts written on-the-fly |
| Burp MCP | Request replay, parameter tampering | `mcp__burpsuite__send_http1_request` |
| `john` / `hashcat` | Offline hash cracking | `john --wordlist=rockyou.txt hashes.txt` |

### Phase 4 — Post-Exploitation

| Tool | Purpose | Example |
|------|---------|---------|
| `evil-winrm` | Windows Remote Management shell | `evil-winrm -i <IP> -u user -p pass` |
| `ssh` / `sshpass` | Linux remote shell | `sshpass -p 'pass' ssh user@<IP>` |
| `python3 pywinrm` | Programmatic WinRM access | `winrm.Session(IP, auth=(u,p))` |
| `netcat` | Reverse shells, file transfer | `nc -lvnp 4444` |

### Phase 5 — Privilege Escalation

| Tool | Purpose |
|------|---------|
| `winPEAS` / `linPEAS` | Automated privesc enumeration |
| Manual enumeration | Check sudo, SUID, cron, services |
| Token impersonation | SeImpersonatePrivilege exploitation |

---

## Claude Execution Patterns

### Running Commands in the Container

Claude always uses `docker exec` to interact with the Kali container:

```python
# Simple command
docker exec kali-pentest nmap -sC -sV <IP>

# Complex script (write to file, then execute)
docker cp script.py kali-pentest:/tmp/script.py
docker exec kali-pentest python3 /tmp/script.py

# Background long-running tasks
docker exec -d kali-pentest python3 -c "import http.server; ..."
```

### Writing Custom Exploits

For complex attacks (OAuth CSRF, SSTI, etc.), Claude:
1. Writes a Python script to the host filesystem
2. Copies it into the container with `docker cp`
3. Executes it with `docker exec kali-pentest python3 /tmp/script.py`

This avoids shell escaping issues with heredocs and inline code.

### Parallel Operations

Claude runs independent tasks in parallel:
- Background nmap scans while enumerating web apps
- Password cracking while exploring other attack vectors
- Listening for callbacks while triggering exploits

---

## Report Structure

Reports are organized per-target under `reports/`:

```
reports/
└── htb-<IP>/
    ├── Dockerfile          # Kali image definition used
    ├── scans/              # nmap, gobuster, nikto output
    │   ├── full_scan.txt
    │   ├── quick_scan.txt
    │   └── gobuster_common.txt
    ├── evidence/           # Screenshots, captured data
    ├── notes/              # Attack scripts, custom exploits
    │   ├── oauth_bruteforce.py
    │   └── exploit.py
    └── REPORT.md           # Final step-by-step writeup
```

---

## Permissions (settings.local.json)

The following permissions auto-approve common pentesting commands:

```json
{
  "permissions": {
    "allow": [
      "Bash(docker:*)",
      "Bash(ping:*)",
      "Bash(curl:*)",
      "Bash(python3:*)",
      "Bash(ls:*)",
      "Bash(mkdir:*)",
      "WebSearch"
    ]
  }
}
```

This lets Claude operate autonomously without requiring approval for each `docker exec`.

---

## Adding New Tools to the Kali Image

Edit `docker/Dockerfile.kali` and rebuild:

```bash
docker build -t kali-htb -f docker/Dockerfile.kali .
docker rm -f kali-pentest  # remove old container
# re-run with docker run ...
```

### Recommended Additional Packages

**Web Application Testing:**
- `feroxbuster` — fast recursive content discovery
- `wfuzz` — web fuzzer for parameters, headers, cookies
- `ffuf` — fast web fuzzer written in Go
- `arjun` — HTTP parameter discovery
- `nuclei` — template-based vulnerability scanner
- `httpx` — fast HTTP toolkit for probing

**API Testing:**
- `postman` (CLI) or `httpie` — API request crafting
- `jwt-tool` — JWT token manipulation and attacks

**CMS-Specific:**
- `wpscan` — WordPress vulnerability scanner
- `droopescan` — Drupal/Joomla/SilverStripe scanner
- `joomscan` — Joomla scanner

**Credential Attacks:**
- `cewl` — custom wordlist generator from target site
- `cupp` — common user password profiler
- `kerbrute` — Kerberos brute forcing

**Active Directory:**
- `impacket-scripts` — AD exploitation toolkit (secretsdump, psexec, etc.)
- `bloodhound` — AD privilege escalation path finder
- `ldapdomaindump` — LDAP enumeration

**Post-Exploitation:**
- `chisel` — TCP/UDP tunneling over HTTP
- `ligolo-ng` — tunneling/pivoting
- `mimikatz` (via impacket) — credential extraction

---

## Techniques Demonstrated in This Project

### 1. OAuth 2.0 CSRF (Account Takeover)

**Vulnerability:** Missing `state` parameter in OAuth2 authorization flow.

**Attack chain:**
1. Register account on OAuth provider (Qooqle)
2. Generate OAuth authorization code linked to attacker's provider account
3. Inject the callback URL (`/accounts/oauth2/qooqle/callback/?code=ATTACKER_CODE`) into article content using allowed HTML tags (`<video poster="...">`)
4. Report the article — admin bot visits, browser loads the poster URL with admin's session cookies
5. Admin's account gets linked to attacker's OAuth provider account
6. Attacker logs in via OAuth, authenticated as admin

**Key insight:** CSP `default-src 'self'` blocks external resource loading, but the OAuth callback is **same-origin** — so it passes CSP validation.

### 2. Stored HTML Injection via CKEditor Content

**Vulnerability:** Article content field accepts raw HTML. CKEditor removes `<img>` and `<iframe>` plugins, and the server blocks those tags — but `<video>`, `<audio>`, `<meta>`, `<table background>`, and `<svg>` tags are allowed.

**Tags that auto-load resources:**
- `<video poster="URL">` — loads poster image on page render
- `<video src="URL" autoplay>` — attempts media load
- `<audio src="URL">` — attempts media load
- `<table background="URL">` — loads background image
- `<meta http-equiv="refresh" content="0;url=URL">` — page redirect

### 3. Django Admin via OAuth Privilege Escalation

After gaining admin access to the web application, the Django admin panel (`/accounts/admin/`) was accessible, providing:
- User management (password changes)
- SQL Explorer for direct database queries
- Database connection management

### 4. OAuth2 Password Grant Brute Force

**Technique:** Register a custom OAuth2 application on the provider with `password` grant type. Use the `/oauth2/token/` endpoint to rapidly test username/password combinations without rate limiting.

```python
requests.post("http://provider/oauth2/token/", data={
    "grant_type": "password",
    "username": target_user,
    "password": candidate,
    "client_id": attacker_client_id,
    "client_secret": attacker_client_secret,
})
# 200 = valid credentials, 400 = invalid
```

---

## VPN Providers Supported

- **HackTheBox** — `.ovpn` files from HTB lab access
- **TryHackMe** — `.ovpn` files from THM
- **Custom** — any OpenVPN-compatible `.ovpn` config

---

## Safety Notes

- All testing is performed inside an isolated Docker container
- The VPN runs inside the container, not on the host
- No tools are installed on the host machine
- Reports and evidence are persisted via Docker volumes
- **Only use against authorized targets (CTF, lab, permitted scope)**
