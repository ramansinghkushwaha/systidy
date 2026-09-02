# SysTidy
Safe Linux housekeeping CLI — clears package caches &amp; stale temp files, with opt-in log rotation. Never touches auth logs, login records, or shell history.
# SysTidy

A small, safe housekeeping script for Linux: clears package caches, sweeps old temp files, and (optionally) rotates your own application logs — with a built-in system-info view thrown in.

## Why this exists

Most "system cleaner" scripts you'll find bundle log-clearing with *security-log* clearing — deleting `auth.log`, `secure`, `wtmp`, `btmp`, `lastlog`, and shell history alongside the harmless stuff. Those specific files are exactly what records logins, sessions, and commands on a Linux box, so wiping them is a well-known way of covering tracks after unauthorized access (MITRE ATT&CK T1070.002 / T1070.003) — not something a legitimate cleanup tool should do.

SysTidy keeps the useful parts of that idea (cache/temp cleanup, a system-info dashboard, an interactive shell) and drops the part that turns a "cleaner" into an anti-forensics tool.

## Features

- **Package cache cleanup** — `apt`, `yum`, or `pacman` cache, whichever is present
- **Temp-file sweep** — removes files older than a configurable age (default 7 days) from `/tmp`, `/var/tmp`, and `~/.cache`
- **Opt-in app-log rotation** — only removes rotated log patterns *you* list yourself in the `APP_LOGS` array
- **System info view** — OS, uptime, hostname, CPU model/usage, RAM usage
- **Dry-run mode** — preview exactly what would be removed before anything is deleted
- **Interactive shell** — run commands one at a time instead of via flags

## What SysTidy intentionally will not do

- Never touches `auth.log`, `secure`, `wtmp`, `btmp`, `lastlog`, `syslog`, `kern.log`, `messages`, or the systemd journal
- Never touches shell history files (`.bash_history`, `.zsh_history`, etc.)
- Never ships a flag for either of the above — that boundary isn't configurable

## Requirements

- Bash
- Standard coreutils: `rm`, `find`, `cut`
- Root privileges only for `--clean-cache` (package caches are system-owned)

## Installation

```bash
git clone https://github.com/<your-username>/systidy.git
cd systidy
chmod +x systidy.sh
```

## Usage

```
./systidy.sh [options]
```

| Flag | Short | Description |
|---|---|---|
| `--clean-cache` | `-cc` | Clean the system package manager cache (needs root) |
| `--clean-temp` | `-ct` | Remove files older than 7 days from temp dirs |
| `--clean-applogs` | `-ca` | Remove rotated logs listed in `APP_LOGS` (opt-in only) |
| `--fetch-info` | `-fi` | Print OS / CPU / RAM / uptime info |
| `--dry-run` | `-d` | Preview actions without deleting anything |
| `--shell` | `-sh` | Start the interactive shell |
| `--banner` | `-bn` | Print the banner and exit |
| `--no-banner` | `-nb` | Suppress the banner for this run |
| `--help` | `-h` | Show help text |
| `--version` | `-v` | Show the current version |

### Examples

```bash
# Preview what a temp cleanup would remove, no root needed
./systidy.sh --dry-run --clean-temp

# Actually clean the package cache (needs root)
sudo ./systidy.sh --clean-cache

# Interactive mode
./systidy.sh --shell
```

### Configuring app-log rotation (optional)

Edit the `APP_LOGS` array at the top of `systidy.sh` to point at your own rotated logs, e.g.:

```bash
export APP_LOGS=(
    "/var/log/myapp/*.log.gz"
    "/var/log/myapp/*.log.1"
)
```

Only add patterns for logs you own and are fine losing. Do not add security or audit logs to this list.

## License

MIT — see [LICENSE](LICENSE).

## Author

Raman Singh Kushwaha (Hemant)
