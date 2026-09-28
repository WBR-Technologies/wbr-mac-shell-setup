#!/usr/bin/env bash
#
# WBR mac-shell-setup — provision a fresh macOS machine with a nice-looking shell.
# A WBR Technologies (wbrtechnologies.com) internal tooling script.
#
# Installs: Homebrew, zsh (set as your default shell), Ghostty, eza, zoxide,
# zsh-syntax-highlighting, zsh-autosuggestions and Starship; wires them into
# ~/.zshrc and installs per-tool configs from ./configs (Ghostty theme,
# starship.toml), remaps Caps Lock to Escape (persists across reboots).
#
# Usage:
#   ./mac-shell-setup.sh [options]
#
# Options:
#   -y, --yes               Don't ask for confirmation before starting
#       --dry-run           Show what would happen; changes nothing
#       --skip-zsh          Don't install zsh / change your default shell
#       --skip-ghostty      Don't install Ghostty
#       --skip-configs      Don't write tool configs (zshrc/starship/ghostty)
#       --skip-capslock     Don't remap Caps Lock to Escape
#   -h, --help              Show this help and exit
#
# Safe to re-run: every step checks its own state first and skips work
# that's already done.

set -uo pipefail

# ---------------------------------------------------------------------------
# Style
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m';    DIM=$'\033[2m';    RESET=$'\033[0m'
  RED=$'\033[31m';    GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m';   MAGENTA=$'\033[35m'; CYAN=$'\033[36m'; GRAY=$'\033[90m'
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; GRAY=""
fi

log_info()    { printf "  %s%s%sℹ%s  %s\n" "$BLUE" "$BOLD" "" "$RESET" "$*"; }
log_success() { printf "  %s%s✔%s  %s\n" "$GREEN" "$BOLD" "$RESET" "$*"; }
log_warn()    { printf "  %s%s⚠%s  %s\n" "$YELLOW" "$BOLD" "$RESET" "$*"; }
log_error()   { printf "  %s%s✖%s  %s\n" "$RED" "$BOLD" "$RESET" "$*" >&2; }
log_dry()     { printf "  %s%s»%s  %s\n" "$MAGENTA" "$BOLD" "$RESET" "[dry-run] $*"; }

hr() { printf '%s%s%s\n' "$GRAY" "────────────────────────────────────────────────────────────" "$RESET"; }

banner() {
  printf '\n%s%s' "$CYAN" "$BOLD"
  cat <<'EOF'
   ╔══════════════════════════════════════════════════════╗
   ║           WBR macOS Shell Provisioning Tool           ║
   ║  Homebrew · Ghostty · eza · zoxide · zsh · Starship   ║
   ╚══════════════════════════════════════════════════════╝
EOF
  printf '%s\n' "$RESET"
}

# current/total -> "[███████░░░░] 62%"
progress_bar() {
  local current="$1" total="$2" width=28
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar
  bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
  bar+=$(printf '%*s' "$empty" '' | tr ' ' '░')
  local pct=$(( current * 100 / total ))
  printf "%s[%s%s%s%s]%s %3d%%" "$GRAY" "$RESET$CYAN" "$bar" "$RESET$GRAY" "" "$RESET" "$pct"
}

step_header() {
  local n="$1" title="$2"
  echo
  printf "%s▸ Step %d/%d%s  %s%s%s   " "$BOLD$CYAN" "$n" "$TOTAL_STEPS" "$RESET" "$BOLD" "$title" "$RESET"
  progress_bar "$((n - 1))" "$TOTAL_STEPS"
  echo
}

# Run a command in the background with a spinner; output goes to $LOG_FILE.
run_step() {
  local msg="$1"; shift
  ( "$@" ) >>"$LOG_FILE" 2>&1 &
  local pid=$!
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0 ncols=${#spin}
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % ncols ))
    printf "\r  %s%s%s  %s" "$CYAN" "${spin:$i:1}" "$RESET" "$msg"
    sleep 0.1
  done
  local status=0
  wait "$pid" || status=$?
  if [ "$status" -eq 0 ]; then
    printf "\r  %s✔%s  %s\n" "$GREEN" "$RESET" "$msg"
  else
    printf "\r  %s✖%s  %s %s(exit %s — see %s)%s\n" "$RED" "$RESET" "$msg" "$DIM" "$status" "$LOG_FILE" "$RESET"
  fi
  return $status
}

# ---------------------------------------------------------------------------
# Config / defaults
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/configs"

TOTAL_STEPS=10
DRY_RUN=0
ASSUME_YES=0
SKIP_ZSH=0
SKIP_GHOSTTY=0
SKIP_CONFIGS=0
SKIP_CAPSLOCK=0

GHOSTTY_CASK="ghostty"
GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config.ghostty"

STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"

CAPSLOCK_LABEL="com.macshellsetup.capslock2escape"
CAPSLOCK_PLIST="$HOME/Library/LaunchAgents/${CAPSLOCK_LABEL}.plist"

ZSHRC="$HOME/.zshrc"
ZSH_BEGIN="# >>> WBR mac-shell-setup >>>"
ZSH_END="# <<< WBR mac-shell-setup <<<"

print_help() {
  sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) print_help; exit 0 ;;
      --dry-run) DRY_RUN=1 ;;
      -y|--yes) ASSUME_YES=1 ;;
      --skip-zsh) SKIP_ZSH=1 ;;
      --skip-ghostty) SKIP_GHOSTTY=1 ;;
      --skip-configs) SKIP_CONFIGS=1 ;;
      --skip-capslock) SKIP_CAPSLOCK=1 ;;
      *)
        log_error "Unknown option: $1"
        print_help
        exit 1
        ;;
    esac
    shift
  done
}

preflight() {
  if [ -z "${BASH_VERSION:-}" ]; then
    echo "Please run this with bash: bash $0" >&2
    exit 1
  fi
  if [ "$(uname -s)" != "Darwin" ]; then
    log_error "This tool only supports macOS."
    exit 1
  fi
  if [ "$(id -u)" -eq 0 ]; then
    log_error "Run this as your normal user account, not root/sudo."
    exit 1
  fi
  if [ ! -d "$CONFIG_SRC" ]; then
    log_error "configs/ directory not found next to the script ($CONFIG_SRC)."
    exit 1
  fi
}

confirm_start() {
  if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  printf "%sThis will install Homebrew packages, set zsh as your default shell, edit\n~/.zshrc, write tool configs (Ghostty/starship), and remap Caps Lock. Proceed? [Y/n]%s " "$BOLD" "$RESET"
  read -r reply
  case "$reply" in
    [nN]*) echo "Aborted — nothing was changed."; exit 0 ;;
    *) return 0 ;;
  esac
}

trap 'echo; log_warn "Interrupted — some steps may be partially applied."; exit 130' INT

# ---------------------------------------------------------------------------
# Step 1 — Homebrew
# ---------------------------------------------------------------------------

step_install_homebrew() {
  step_header 1 "Homebrew"

  if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew already installed ($(brew --version | head -n1))"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      log_dry "Install Homebrew"
    else
      log_info "Installing Homebrew — macOS may prompt for your password"
      if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >>"$LOG_FILE" 2>&1; then
        log_error "Homebrew installation failed — see $LOG_FILE"
        return 1
      fi
      log_success "Homebrew installed"
    fi
  fi

  local brew_bin=""
  if [ -x /opt/homebrew/bin/brew ]; then
    brew_bin=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    brew_bin=/usr/local/bin/brew
  fi

  if [ -n "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
  fi

  if ! command -v brew >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      log_dry "brew would be on PATH after a real run"
    else
      log_error "brew not found on PATH after installation."
      return 1
    fi
  fi

  if [ -n "$brew_bin" ]; then
    touch "$HOME/.zprofile"
    if ! grep -qF 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
      if [ "$DRY_RUN" -eq 1 ]; then
        log_dry "Add 'eval \"\$($brew_bin shellenv)\"' to ~/.zprofile"
      else
        # shellcheck disable=SC2016  # the $(...) is literal in the generated ~/.zprofile
        printf '\neval "$(%s shellenv)"\n' "$brew_bin" >> "$HOME/.zprofile"
        log_success "Added Homebrew shellenv to ~/.zprofile"
      fi
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "brew update"
  else
    run_step "Updating Homebrew" brew update || true
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Helpers for Homebrew installs
# ---------------------------------------------------------------------------

install_cask() {
  local cask="$1" label="$2"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_success "$label already installed"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "brew install --cask $cask"
    return 0
  fi
  run_step "Installing $label" brew install --cask "$cask"
}

install_formula() {
  local formula="$1" label="$2"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    log_success "$label already installed"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "brew install $formula"
    return 0
  fi
  run_step "Installing $label" brew install "$formula"
}

# Copy a config file from ./configs into place, backing up any existing file.
install_config_file() {
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$src" ]; then
    log_error "Missing config file: $src"
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    log_success "$label already up to date"
    return 0
  fi
  if [ -f "$dest" ]; then
    local backup
    backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$dest" "$backup"
    log_warn "Existing $label backed up to $(basename "$backup")"
  fi
  cp "$src" "$dest"
  log_success "$label written to $dest"
}

# ---------------------------------------------------------------------------
# Step 2 — zsh (install + default shell)
# ---------------------------------------------------------------------------

step_install_zsh() {
  step_header 2 "zsh"

  if [ "$SKIP_ZSH" -eq 1 ]; then
    log_warn "Skipped (--skip-zsh)"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "brew install zsh"
    log_dry "Register the Homebrew zsh in /etc/shells (if needed)"
    log_dry "chsh -s <homebrew zsh> (make it your default shell)"
    return 0
  fi

  install_formula zsh "zsh" || return 1

  local zsh_bin
  zsh_bin="$(brew --prefix)/bin/zsh"
  if [ ! -x "$zsh_bin" ]; then
    log_error "zsh not found at $zsh_bin after install."
    return 1
  fi

  if ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
    if printf '%s\n' "$zsh_bin" | sudo tee -a /etc/shells >/dev/null 2>>"$LOG_FILE"; then
      log_success "Registered $zsh_bin in /etc/shells"
    else
      log_error "Could not add $zsh_bin to /etc/shells (needs sudo)."
      return 1
    fi
  fi

  local current
  current="$(dscl . -read "$HOME" UserShell 2>/dev/null | awk '{print $2}')"
  if [ "$current" = "$zsh_bin" ]; then
    log_success "Default shell already set to $zsh_bin"
  elif sudo chsh -s "$zsh_bin" "$USER" 2>>"$LOG_FILE"; then
    log_success "Default shell set to $zsh_bin (takes effect in new sessions)"
  else
    log_warn "Couldn't set the default shell automatically. Run: chsh -s $zsh_bin"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Step 3 — Ghostty
# ---------------------------------------------------------------------------

step_install_ghostty() {
  step_header 3 "Ghostty"
  if [ "$SKIP_GHOSTTY" -eq 1 ]; then
    log_warn "Skipped (--skip-ghostty)"
    return 0
  fi
  install_cask "$GHOSTTY_CASK" "Ghostty"
}

# ---------------------------------------------------------------------------
# Steps 4-8 — CLI tools
# ---------------------------------------------------------------------------

step_install_eza() {
  step_header 4 "eza"
  install_formula eza "eza"
}

step_install_zoxide() {
  step_header 5 "zoxide"
  install_formula zoxide "zoxide"
}

step_install_zsh_syntax_highlighting() {
  step_header 6 "zsh-syntax-highlighting"
  install_formula zsh-syntax-highlighting "zsh-syntax-highlighting"
}

step_install_zsh_autosuggestions() {
  step_header 7 "zsh-autosuggestions"
  install_formula zsh-autosuggestions "zsh-autosuggestions"
}

step_install_starship() {
  step_header 8 "Starship prompt"
  install_formula starship "starship"
}

# ---------------------------------------------------------------------------
# Step 9 — Tool configs (from ./configs, each in its own file)
# ---------------------------------------------------------------------------

configure_zshrc() {
  local body="$CONFIG_SRC/zshrc.sh"
  if [ ! -f "$body" ]; then
    log_error "Missing config file: $body"
    return 1
  fi
  touch "$ZSHRC"
  if grep -qF "$ZSH_BEGIN" "$ZSHRC" 2>/dev/null; then
    sed -i '' "/$ZSH_BEGIN/,/$ZSH_END/d" "$ZSHRC"
  fi
  {
    echo ""
    echo "$ZSH_BEGIN"
    cat "$body"
    echo "$ZSH_END"
  } >> "$ZSHRC"
}

step_install_configs() {
  step_header 9 "Tool configs"

  if [ "$SKIP_CONFIGS" -eq 1 ]; then
    log_warn "Skipped (--skip-configs)"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "Copy configs/ghostty.conf -> $GHOSTTY_CONFIG_FILE"
    log_dry "Copy configs/starship.toml -> $STARSHIP_CONFIG_FILE"
    log_dry "Update ~/.zshrc with managed block from configs/zshrc.sh"
    return 0
  fi

  local rc=0
  install_config_file "$CONFIG_SRC/ghostty.conf" "$GHOSTTY_CONFIG_FILE" "Ghostty config" || rc=1
  install_config_file "$CONFIG_SRC/starship.toml" "$STARSHIP_CONFIG_FILE" "starship.toml" || rc=1
  if configure_zshrc; then
    log_success "Updated ~/.zshrc"
  else
    rc=1
  fi
  return $rc
}

# ---------------------------------------------------------------------------
# Step 10 — Caps Lock -> Escape
# ---------------------------------------------------------------------------

step_remap_capslock() {
  step_header 10 "Caps Lock -> Escape"

  if [ "$SKIP_CAPSLOCK" -eq 1 ]; then
    log_warn "Skipped (--skip-capslock)"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log_dry "Remap Caps Lock to Escape now (hidutil) and persist via a LaunchAgent"
    return 0
  fi

  hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}' >>"$LOG_FILE" 2>&1

  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$CAPSLOCK_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${CAPSLOCK_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

  launchctl bootout "gui/$(id -u)" "$CAPSLOCK_PLIST" >/dev/null 2>&1 || true
  if ! launchctl bootstrap "gui/$(id -u)" "$CAPSLOCK_PLIST" >>"$LOG_FILE" 2>&1; then
    launchctl load -w "$CAPSLOCK_PLIST" >>"$LOG_FILE" 2>&1 || true
  fi

  log_success "Caps Lock now maps to Escape (active now, persists across reboots)"
  return 0
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

summary() {
  local failures="$1"
  echo
  hr
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "%s%s  Dry run complete — no changes were made.%s\n" "$BOLD" "$MAGENTA" "$RESET"
  elif [ "$failures" -eq 0 ]; then
    printf "%s%s  All done — your shell has been forged.%s\n" "$BOLD" "$GREEN" "$RESET"
  else
    printf "%s%s  Finished with %d step(s) that need attention (see above).%s\n" "$BOLD" "$YELLOW" "$failures" "$RESET"
  fi
  hr
  echo
  echo "Next steps:"
  echo "  • Open a new Ghostty window/tab (or run: source ~/.zshrc) to load everything."
  echo "  • zsh is your default shell — it applies to new login sessions (log out/in if needed)."
  echo "  • Ghostty config lives at: $GHOSTTY_CONFIG_FILE"
  echo "  • Caps Lock -> Escape is active immediately; logging out/in reconfirms it via the LaunchAgent."
  echo "  • Full log: $LOG_FILE"
  echo
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  preflight

  LOG_DIR="$HOME/Library/Logs/mac-shell-setup"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
  : > "$LOG_FILE"

  banner
  if [ "$DRY_RUN" -eq 1 ]; then
    log_info "Dry run — no changes will be made."
  fi
  confirm_start

  local failures=0
  step_install_homebrew || failures=$((failures + 1))
  step_install_zsh || failures=$((failures + 1))
  step_install_ghostty || failures=$((failures + 1))
  step_install_eza || failures=$((failures + 1))
  step_install_zoxide || failures=$((failures + 1))
  step_install_zsh_syntax_highlighting || failures=$((failures + 1))
  step_install_zsh_autosuggestions || failures=$((failures + 1))
  step_install_starship || failures=$((failures + 1))
  step_install_configs || failures=$((failures + 1))
  step_remap_capslock || true

  summary "$failures"
  [ "$failures" -eq 0 ]
}

main "$@"
