# 🧭 gnotermon — GNOME Terminal Orchestration Tool

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![Built with: Bash](https://img.shields.io/badge/built%20with-Bash-1f425f.svg)
![Status: Personal Project](https://img.shields.io/badge/status-personal-lightgrey.svg)
![Stage: Experimental](https://img.shields.io/badge/stage-experimental-orange.svg)

**`gnotermon`** is a unified shell control layer (a "terminal orchestrator", but requiring no terminal multiplexer) for GNOME Terminal on **X11**.  It gives you a programmable way to *see, track, tag, and control* your open terminal windows on your cluttered desktop (say when you have 235 terminals across 3 monitors and 7 workspaces, some of them in interactive sessions, some holding webservers mocking your SaaS and some just sitting there at ~ after a few overzealous in-the-moment Ctrl-Alt-Ts), something GNOME Terminal doesn’t natively expose, and an experience that is in some cases reminiscent of using the Docker CLI verbs or kubect as opposed to pressing the Super key or clicking on your GNOME taskbar and letting your GNOME session freeze (like Alt-F2 "r" freeze!) on making the window preview thumbnails.

It combines D-Bus introspection, X11 window control, process tree analysis, and self-registration to maintain a live registry of your active terminals.

---

## 💡 Why You’d Want This

If you use GNOME Terminal heavily, you’ve probably hit one or more of these frustrations:

- You have **too many terminals** open and can’t tell which are idle, running something, or attached to tmux or Docker.
- You wish you could **automatically close idle windows**, **focus the terminal serving a given port**, or **minimize inactive ones**.
- You’d like to **record or replay** terminal sessions for debugging or documentation.

GNOME Terminal doesn’t track its windows’ processes or states — and tools like `xdotool` only know about window geometry, not which process lives inside each one.

`gnotermon` bridges that gap through a clever **self-registration mechanism**:
- Each terminal “checks in” on startup via `admiralty checkin`, recording its own **window ID, PID, TTY, and tag**.
- That data is stored in a simple runtime file (`xadmiralty.state`).
- Other subcommands use that registry to correlate GNOME Terminal windows with the processes inside them.

This enables real automation:
```bash
gnotermon admiralty minimize-all-idle
gnotermon admiralty focus-port 8080
gnotermon admiralty close-all-tagged build
```

Without self-registration, this problem is very thorny because of details left out of the D-Bus implementation and process ownership under a centralized server, to the effect that normally there’s no reliable way to map GNOME Terminal windows back to their shell PIDs.

---

## ✨ Features

- 🪄 **D-Bus Puppetry:** Introspect and command GNOME Terminal windows directly over D-Bus.  
- 🌳 **Arbory View:** Build a live GNOME Terminal → PTY → process tree map.  
- 🪟 **Window Wranglery:** Move, resize, rename, tile, or focus terminal windows via X11.  
- ⚓ **Admiralty Mode:** Persistent terminal registry with tags, IDLE/BUSY/DEAD detection, and powerful automation.  
- 🧩 **Posterity:** Record and replay tagged sessions using `asciinema`.  
- 🧰 **Dependency Checker:** Ensure all required tools are installed.  
- 💡 **Smart Tiling:** Automatically arrange terminals into grid layouts based on screen geometry.  

---

## 🧠 Technical Design

At its core, `gnotermon` is built around **three interacting systems**:

### 1. **Self-Registration (Admiralty Mode)**
At terminal window creation, when conditions are ripest for ID correlation, the terminal session calls:
```bash
gnotermon admiralty checkin <optional-tag>
```
This collects:
- The GNOME window ID (via `xdotool`),
- The controlling shell PID (`$$`),
- The TTY name,
- And an optional tag (e.g. “dev”, “db”, “build”).

All of this is stored line-by-line in a statefile at:
```
$XDG_RUNTIME_DIR/gnotermon/xadmiralty.state
```

This statefile becomes the living source of truth for all orchestration commands.

---

### 2. **Process Introspection**
Whenever a subcommand runs (like `focus-all-busy` or `minimize-all-idle`),  
`gnotermon` dynamically inspects process trees and `/proc` data to determine:

- Whether a process is alive,
- Whether it has children (indicating BUSY vs IDLE),
- Whether it’s attached to `tmux`, running inside Docker, or has open network sockets.

This real-time inspection makes it possible to safely minimize idle terminals, focus active builds, or close disconnected windows.

---

### 3. **X11 Window Control**
Window control is performed through `xdotool`, which allows:
- Moving, resizing, and focusing GNOME Terminal windows by their X11 IDs,
- Sending keystrokes (e.g., to trigger `asciinema` recordings),
- Building intelligent layouts (`wranglery tile`).

Because it’s X11-based, the tool can directly manipulate windows, synchronize visual state with process state, and even rename titles dynamically to reflect activity.

---

Together, these systems create a **tight feedback loop** between GNOME Terminal’s graphical windows, their underlying processes, and your shell automation.  
This approach is minimal (pure Bash + standard tools), robust, and extendable.

gnotermon arbory builds a live mapping of GNOME Terminal servers, pseudo-TTYs, and their descendant processes, effectively showing which shell or command tree belongs to which terminal window.
It scans /dev/pts/*, identifies the controlling shell PID for each, and recursively enumerates child processes using ps.
This provides a hierarchical, visual “forest” of active terminals and their workloads, helping you see at a glance which terminals are idle shells and which are hosting long-running jobs or subsystems.

While the architecture above captures the intended design faithfully, the current implementation includes some practical simplifications worth noting:

- **Activity detection (IDLE/BUSY):**  
  The `admiralty checkin` routine currently determines BUSY vs IDLE status by inspecting the shell’s background job list (`jobs`).  
  It does **not yet** account for CPU usage, process I/O, or child process activity beyond direct shell jobs.

- **State correlation:**  
  The registry correlates windows to processes primarily through **TTYs** and **PIDs**, discovered via `/proc` inspection and `ps`.  
  This mechanism is robust for interactive terminals but may miss detached or reparented processes.

- **Environment variable filtering:**  
  `focus-all-envvar`, `minimize-all-envvar`, and related verbs read from `/proc/$pid/environ` to match variables in active shells.  
  This allows session-scoped targeting but relies on Linux-specific `/proc` semantics.

- **Posterity session handling:**  
  The `posterity merge` logic depends on a manually generated `manifest.json` file within the session directory.  
  Timestamp rebasing and tag prefixing are implemented via `jq`, but manifest creation is not yet automated.

- **Network awareness:**  
  The `netwatch` and `netwatch_smart` modes focus windows when activity is detected via `/proc/$pid/net/dev` or `ss`.  
  These provide proof-of-concept behavior but may require tuning for noisy systems.


---

## 🚀 Installation

Add it directly to your shell configuration — this is designed to *live inside your shell*, not as a standalone binary.

Most easily, back up your ~/.bashrc and paste it in there.

Each new terminal session will automatically self-register:
```bash
gnotermon admiralty checkin "auto"
```

You can check for dependencies with:
```bash
gnotermon checkdeps
```

Which may look like this:
```
Checking required dependencies for gnotermon...
  [OK]      gdbus (/home/null/anaconda3/bin/gdbus)
  [OK]      xdotool (/usr/bin/xdotool)
  [OK]      xprop (/usr/bin/xprop)
  [OK]      awk (/usr/bin/awk)
  [OK]      ps (/bin/ps)
  [OK]      jq (/usr/bin/jq)
  [OK]      lsof (/usr/bin/lsof)
  [OK]      ss (/bin/ss)
  [OK]      asciinema (/usr/bin/asciinema)
  [OK]      tmux (/usr/bin/tmux)

All dependencies appear to be installed and available.
```

---

## 🧩 Example Workflows

### 🔍 Observe and Track Terminals
```bash
gnotermon admiralty list
```

### 💤 Minimize Idle Terminals
```bash
gnotermon admiralty minimize-all-idle
```

### ⚙️ Focus by Port or Tag
```bash
gnotermon admiralty focus-port 8000
gnotermon admiralty focus-all-tagged build
```

### 🪟 Control Window Layout
```bash
gnotermon wranglery tile
```

### 🎥 Record and Replay Sessions
```bash
gnotermon posterity record_tagged build
gnotermon posterity stoprecord_tagged build
gnotermon posterity play_tagged build
```

---

## ⚙️ Dependencies

Run `gnotermon checkdeps` to verify your environment.

**Core dependencies:**
```
gdbus
xdotool
xprop
awk, ps, jq
lsof, ss
tmux
asciinema
```

---

## 🗂️ State and Storage

Default state directory:
```
$XDG_RUNTIME_DIR/gnotermon/
# Falls back to /tmp/gnotermon if unset
```

Contains:
- `xadmiralty.state` — live window registry  
- `records/session-*` — asciinema recordings  

---

## 🧭 Why It Requires X11

`gnotermon` depends on **X11’s introspectable window model** to function:
- It identifies windows via their XIDs,
- Sends window management commands through `xdotool`,
- Retrieves geometry and state via `xprop`.

Wayland **blocks these operations for security reasons** — no process may directly control another window.  
Under Wayland, GNOME Terminal’s API doesn’t expose equivalent handles, so these features are **not available**.

---

## 🛣️ Roadmap

- [ ] **Enhance Smart Tiling:** Expand `wranglery tile` to support multi-monitor setups, configurable margins, and dynamic layout persistence.
- [ ] **Deepen Posterity integration:**  
  - Auto-generate and maintain `manifest.json` files when recording sessions.  
  - Implement cross-tag and multi-window replay with timestamp rebasing.  
  - Provide CLI utilities for trimming or merging `.cast` files without manual `jq`.
- [ ] **Improve Activity Detection:** Replace simple child-process heuristics with richer signals (e.g. CPU usage, foreground job state, or recent TTY I/O) to better determine `BUSY`, `IDLE`, and `DEAD`.
- [ ] **Extend D-Bus Puppetry:** Move beyond introspection to implement full window enumeration and control verbs (e.g. open new tabs, rename profiles, toggle zoom).
- [ ] **Wayland Compatibility:** Prototype a bridge via `ydotool`, `wlrctl`, or a GNOME Shell extension to restore focus/move control under Wayland.
- [ ] **Posterity Merge Utility:** Package the current experimental `merge` logic into a standalone helper command for session curation.
- [ ] **Documentation Sync:** Add reference examples for undocumented commands such as  
  `focus-all-envvar`, `minimize-all-envvar`, `tmux-all-sessions-force`, `netwatch`, and Docker-related verbs.

The current script already implements nearly all of the described functionality, but several subcommands remain **undocumented** or **experimental**:

- `focus-all-envvar`, `minimize-all-envvar`, `close-all-envvar`, and `list-envvar`
- `focus-all-networked`, `minimize-all-networked`
- `focus-all-dockered`, `minimize-all-dockered`
- `netwatch` and `netwatch_smart` (activity-driven window focusing)
- `tmux-all-sessions-force`, `focus-all-tmux`, `minimize-all-tmux`, and `close-all-tmux`
- `posterity grepjump_tagged` and `posterity merge` (with manual manifest support)

Future documentation updates may include structured examples for these features, along with clarified heuristics for process state detection, better cross-session persistence, and automated posterity manifest management.

---
