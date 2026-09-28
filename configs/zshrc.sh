# Managed by WBR mac-shell-setup.sh — edits inside this block are overwritten on re-run.
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"    # Adds `z` (jump to a frecent dir) and `zi` (interactive picker)

# Standard eza replacements
alias ls='eza --color=auto --icons=auto'                       # Quick directory view with syntax coloring and visual icons
alias ll='eza -lah --icons --group-directories-first'          # Full detail grid including hidden items, sizes, and headers
alias la='eza -a --icons'                                      # Minimalist layout that unhides all dotfiles in the path
alias lt='eza --tree --level=2 --icons'                        # Visual directory map displaying structures up to two levels deep
alias lsize='eza -lah --sort=size --reverse --icons'           # Detailed overview ranking every file from biggest to smallest
alias ldate='eza -lah --sort=modified --reverse --icons'       # Detailed timeline displaying the most recently edited files first
alias lgit='eza -lah --icons --git --git-repos'                # Git repository inspection showing commit tracking and status blocks

# Git shortcuts
alias gac='git add . && git commit --amend --no-verify --no-edit'                       # Fold all current changes into the previous commit
alias gacp='git add . && git commit --amend --no-verify --no-edit && git push --force'  # Same, then force-push (rewrites remote history)

# Tool shortcuts
alias -g cat=bat     # Global alias: use bat in place of cat anywhere on the line
alias cc='claude'    # Launch Claude Code
alias cdx='codex'    # Launch Codex
alias oc='opencode'  # Launch OpenCode
