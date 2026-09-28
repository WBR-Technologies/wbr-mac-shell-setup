# WBR Mac Shell Setup

_A [WBR Technologies](https://wbrtechnologies.com) internal tooling script._

Point this script at a fresh Mac and you get a fast, good-looking, fully wired
terminal — no manual setup, no hunting through dotfiles. Run it once and the
machine is ready to work in. This is WBR Technologies' **opinionated** Mac
terminal setup, and the one we recommend to everyone on the team. Here's what it
leaves you with, and why it matters:

- **A modern terminal.** [Ghostty](https://ghostty.org) as the emulator, themed
  with `Nvim Dark` — a clean, distraction-free canvas, and the foundation
  everything else runs on.
- **A shell that works for you.** The Homebrew `zsh` as your default login
  shell, with **syntax highlighting** (commands light up as you type) and
  **autosuggestions** (ghost-text completions from your history) — so typos get
  caught before you hit Enter, and the commands you run a hundred times a day
  shrink to two-letter aliases.
- **A prompt that tells you things.** [Starship](https://starship.rs) renders a
  single, compact line showing your current directory and live git state —
  branch, staged/modified/untracked counts, and ahead/behind markers — so you
  always see your repo without leaving the shell, and never commit from the
  wrong branch or lose track of an uncommitted change.
- **A better `ls`.** [eza](https://github.com/eza-community/eza) replaces `ls`
  with colorized, icon-rich, git-aware listings, so you read your environment at
  a glance instead of running `git status` and `ls -la` by reflex.
- **A faster way to move around.** [zoxide](https://github.com/ajeetdsouza/zoxide)
  learns the directories you use most, so `z` jumps straight to them — no more
  typing long paths or pressing the up-arrow through your history.
- **A faster keyboard.** Caps Lock remaps to Escape — permanently, across
  reboots and logins — putting Escape where your hand expects it for Vim, tmux,
  and terminal-native editing.

Everything is provisioned through Homebrew and driven from a single
[`configs/`](configs) directory, so the whole environment is reproducible on any
Mac you sit down at — onboarding a new laptop, or a teammate, is one command,
not an afternoon of configuration.

## What the script installs

To achieve that, the script installs and configures all of the following, in
order:

| # | Step | Detail |
|---|------|--------|
| 1 | **Homebrew** | Installs it if missing, wires `brew shellenv` into the current run and into `~/.zprofile` for future shells, then runs `brew update`. |
| 2 | **zsh** | Installs the Homebrew `zsh`, registers it in `/etc/shells`, and sets it as your default login shell via `chsh`. |
| 3 | **Ghostty** | The terminal emulator, installed via `brew install --cask ghostty`. |
| 4 | **eza** | Modern `ls` replacement, installed via Homebrew. |
| 5 | **zoxide** | Smarter `cd` that remembers the directories you visit, installed via Homebrew. |
| 6 | **zsh-syntax-highlighting** | Colors commands in your prompt as you type. |
| 7 | **zsh-autosuggestions** | Suggests completions from your shell history. |
| 8 | **Starship** | Cross-shell prompt. |
| 9 | **Tool configs** | Copies each file from `configs/` to its destination: `configs/ghostty.conf` → Ghostty's config, `configs/starship.toml` → `~/.config/starship.toml`, and `configs/zshrc.sh` → a managed block in `~/.zshrc` (sourcing the two plugins, initializing Starship and zoxide, 7 `eza` aliases: `ls`, `ll`, `la`, `lt`, `lsize`, `ldate`, `lgit`, and 2 git aliases: `gac`, `gacp`). |
| 10 | **Caps Lock → Escape** | Remaps immediately via `hidutil`, and installs a LaunchAgent so it persists across reboots/logins. |

## What you can do once it's installed

| Command | What it gives you |
|---------|-------------------|
| `ls` | Colorized directory listing with icons |
| `ll` | Full detail: hidden files, sizes, grouped directories first |
| `la` | Unhide every dotfile in the current path |
| `lt` | A tree view of the folder, two levels deep |
| `lsize` | Every file ranked biggest → smallest |
| `ldate` | Everything ranked most-recently-edited → oldest |
| `lgit` | Listing annotated with per-file git status |
| `z <name>` | Jump to a directory you've visited before, matching on any part of the path |
| `zi` | Interactive picker for the same jump (fuzzy-select from your history) |
| `gac` | Stage everything and fold it into the previous commit |
| `gacp` | Same, then force-push — for your own branches only |
| `cc` / `cdx` / `oc` | Launch Claude Code / Codex / OpenCode |

The git shortcuts use `--amend`; `gacp` force-pushes, so only use it on branches
you own — never on a shared `main`.

## Where the configuration lives

Everything the script writes is sourced from [`configs/`](configs), so you can
edit these files and re-run to apply changes:

| File | Installed to |
|------|--------------|
| `configs/ghostty.conf` | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| `configs/starship.toml` | `~/.config/starship.toml` |
| `configs/zshrc.sh` | the managed block in `~/.zshrc` |

The `eza` aliases and Starship symbols use Nerd Font icons, so install a Nerd
Font separately (e.g. `brew install --cask font-jetbrains-mono-nerd-font`) and
set it as your Ghostty `font-family` for the glyphs to render.

## Requirements

- macOS
- Run as your normal user — not via `sudo`, not as root
- An internet connection (for Homebrew and package downloads)

## Run it

```bash
chmod +x mac-shell-setup.sh
./mac-shell-setup.sh
```

It checks its own state first, so it's safe to re-run any time. Run
`./mac-shell-setup.sh --help` for the available flags.

---

Maintained by [WBR Technologies](https://wbrtechnologies.com).
