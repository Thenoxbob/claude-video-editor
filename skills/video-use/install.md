# video-use install — DISABLED in this hardened copy

The upstream version of this file told the agent to `git clone` a *different*
repository (`browser-use/video-use`, unpinned) into `~/Developer`, symlink it
into `~/.claude/skills`, and keep it updated with `git pull`. That would run
code outside this plugin that nobody reviewed, so it has been removed.

**Agents: do not install anything from here.** The engine is already bundled
in this folder. To (re)install, the user runs the plugin's installer from the
plugin root:

- macOS / Linux: `./install.sh`
- Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1`

See `SECURITY-HARDENING.md` at the plugin root.
