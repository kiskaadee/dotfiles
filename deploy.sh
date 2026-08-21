#!/usr/bin/env bash
# ==============================================================================
# deploy.sh - Deterministic and Idempotent Dotfiles Deployer
# ==============================================================================
# Invariant-driven symlink manager with strict collision backups and diagnostics.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Constants
# ------------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_BASE="${HOME}/.dotfiles_backup"
BACKUP_DIR=""

readonly MODULES=(
  alacritty
  fastfetch
  git
  niri
  nvim
  tmux
)

# Colors (disabled if stdout is not a TTY)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  RED='\033[0;31m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  GREEN=''
  YELLOW=''
  BLUE=''
  RED=''
  CYAN=''
  BOLD=''
  NC=''
fi

# ------------------------------------------------------------------------------
# Module Target Mapping
# ------------------------------------------------------------------------------
get_module_targets() {
  local module="$1"
  case "$module" in
    alacritty)
      echo "alacritty:${DOTFILES_DIR}/alacritty:${TARGET_BASE}/alacritty"
      ;;
    fastfetch)
      echo "fastfetch:${DOTFILES_DIR}/fastfetch:${TARGET_BASE}/fastfetch"
      ;;
    git)
      echo "git:${DOTFILES_DIR}/git:${TARGET_BASE}/git"
      ;;
    niri)
      echo "niri/config.kdl:${DOTFILES_DIR}/niri/config.kdl:${TARGET_BASE}/niri/config.kdl"
      echo "niri/custom.kdl:${DOTFILES_DIR}/niri/custom.kdl:${TARGET_BASE}/niri/custom.kdl"
      ;;
    nvim)
      echo "nvim:${DOTFILES_DIR}/nvim:${TARGET_BASE}/nvim"
      ;;
    tmux)
      echo "tmux:${DOTFILES_DIR}/tmux:${TARGET_BASE}/tmux"
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
resolve_link() {
  local link="$1"
  local dest
  dest="$(readlink "$link" 2>/dev/null || true)"
  if [[ -z "$dest" ]]; then
    echo "$link"
    return
  fi

  if [[ "$dest" != /* ]]; then
    local link_dir
    link_dir="$(cd "$(dirname "$link")" 2>/dev/null && pwd -P || echo "$(dirname "$link")")"
    if [[ -d "${link_dir}/$(dirname "$dest")" ]]; then
      dest="$(cd "${link_dir}/$(dirname "$dest")" 2>/dev/null && pwd -P)/$(basename "$dest")"
    else
      dest="${link_dir}/${dest}"
    fi
  else
    if [[ -d "$dest" ]]; then
      dest="$(cd "$dest" 2>/dev/null && pwd -P || echo "$dest")"
    fi
  fi
  echo "$dest"
}

get_status() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    echo "missing"
    return
  fi

  if [[ -L "$target" ]]; then
    local target_dest
    target_dest="$(resolve_link "$target")"
    if [[ "$target_dest" == "$source" ]]; then
      if [[ -e "$target" ]]; then
        echo "linked"
      else
        echo "broken_symlink"
      fi
    else
      if [[ -e "$target" ]]; then
        echo "foreign_symlink"
      else
        echo "broken_symlink"
      fi
    fi
    return
  fi

  if [[ -d "$target" ]]; then
    echo "directory"
    return
  fi

  if [[ -f "$target" ]]; then
    echo "file"
    return
  fi

  echo "other"
}

validate_paths() {
  local source="$1"
  local target="$2"

  if [[ "$source" == "$target" ]]; then
    echo -e "${RED}Error: Source and target paths are identical: $target${NC}" >&2
    exit 1
  fi

  if [[ "$target" == "$DOTFILES_DIR"* ]]; then
    echo -e "${RED}Error: Target path cannot reside inside repository: $target${NC}" >&2
    exit 1
  fi

  if [[ ! -e "$source" ]]; then
    echo -e "${RED}Error: Source configuration file/directory missing: $source${NC}" >&2
    exit 1
  fi
}

ensure_backup_dir() {
  if [[ -z "$BACKUP_DIR" ]]; then
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    BACKUP_DIR="${BACKUP_BASE}/${ts}"
    local counter=1
    while [[ -e "$BACKUP_DIR" ]]; do
      BACKUP_DIR="${BACKUP_BASE}/${ts}_${counter}"
      counter=$((counter + 1))
    done
    mkdir -p "$BACKUP_DIR"
  fi
}

# ------------------------------------------------------------------------------
# Core Actions
# ------------------------------------------------------------------------------
deploy_target() {
  local label="$1"
  local source="$2"
  local target="$3"
  local dry_run="$4"

  validate_paths "$source" "$target"
  local status
  status="$(get_status "$source" "$target")"

  case "$status" in
    linked)
      echo -e "  ${GREEN}✓${NC} ${BOLD}${label}${NC}: already linked (${target} -> ${source})"
      ;;

    missing)
      if [[ "$dry_run" == "1" ]]; then
        echo -e "  ${CYAN}○${NC} [dry-run] ${BOLD}${label}${NC}: would link ${target} -> ${source}"
      else
        mkdir -p "$(dirname "$target")"
        ln -s "$source" "$target"
        echo -e "  ${GREEN}+${NC} ${BOLD}${label}${NC}: linked (${target} -> ${source})"
      fi
      ;;

    foreign_symlink|directory|file|broken_symlink|other)
      if [[ "$dry_run" == "1" ]]; then
        echo -e "  ${YELLOW}!${NC} [dry-run] ${BOLD}${label}${NC}: collision (${status}) at ${target}; would backup and link"
      else
        ensure_backup_dir
        local backup_dest="${BACKUP_DIR}/${label}"
        mkdir -p "$(dirname "$backup_dest")"
        mv "$target" "$backup_dest"
        echo -e "  ${YELLOW}↳${NC} ${BOLD}${label}${NC}: backed up existing ${status} to ${backup_dest}"
        mkdir -p "$(dirname "$target")"
        ln -s "$source" "$target"
        echo -e "  ${GREEN}+${NC} ${BOLD}${label}${NC}: linked (${target} -> ${source})"
      fi
      ;;
  esac
}

unlink_target() {
  local label="$1"
  local source="$2"
  local target="$3"
  local dry_run="$4"

  validate_paths "$source" "$target"
  local status
  status="$(get_status "$source" "$target")"

  case "$status" in
    linked)
      if [[ "$dry_run" == "1" ]]; then
        echo -e "  ${CYAN}○${NC} [dry-run] ${BOLD}${label}${NC}: would remove symlink ${target}"
      else
        rm "$target"
        echo -e "  ${RED}-${NC} ${BOLD}${label}${NC}: unlinked ${target}"
      fi
      ;;
    missing)
      echo -e "  ${BLUE}·${NC} ${BOLD}${label}${NC}: target does not exist (skip)"
      ;;
    broken_symlink)
      if [[ -L "$target" ]]; then
        local target_dest
        target_dest="$(resolve_link "$target")"
        if [[ "$target_dest" == "$source" ]]; then
          if [[ "$dry_run" == "1" ]]; then
            echo -e "  ${CYAN}○${NC} [dry-run] ${BOLD}${label}${NC}: would remove broken repo symlink ${target}"
          else
            rm "$target"
            echo -e "  ${RED}-${NC} ${BOLD}${label}${NC}: removed broken symlink ${target}"
          fi
          return
        fi
      fi
      echo -e "  ${YELLOW}!${NC} ${BOLD}${label}${NC}: target is ${status} (not owned by dotfiles, skip)"
      ;;
    *)
      echo -e "  ${YELLOW}!${NC} ${BOLD}${label}${NC}: target is ${status} (not owned by dotfiles, skip)"
      ;;
  esac
}

cmd_status() {
  local -a target_modules=("${@}")
  printf "${BOLD}%-18s %-40s %-16s${NC}\n" "TARGET" "LOCATION" "STATUS"
  printf -- '--------------------------------------------------------------------------------\n'
  for mod in "${target_modules[@]}"; do
    while IFS=: read -r label src tgt; do
      local st
      st="$(get_status "$src" "$tgt")"
      local color="$NC"
      case "$st" in
        linked)          color="$GREEN" ;;
        missing)         color="$BLUE" ;;
        foreign_symlink) color="$YELLOW" ;;
        file|directory)  color="$YELLOW" ;;
        broken_symlink)  color="$RED" ;;
      esac
      local display_tgt="${tgt/#$HOME/~}"
      printf "%-18s %-40s ${color}%-16s${NC}\n" "$label" "$display_tgt" "$st"
    done < <(get_module_targets "$mod")
  done
}

cmd_check() {
  local -a target_modules=("${@}")
  local failures=0
  for mod in "${target_modules[@]}"; do
    while IFS=: read -r label src tgt; do
      local st
      st="$(get_status "$src" "$tgt")"
      if [[ "$st" != "linked" ]]; then
        failures=$((failures + 1))
      fi
    done < <(get_module_targets "$mod")
  done

  if [[ "$failures" -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

cmd_doctor() {
  echo -e "${BOLD}Environment & Dependency Diagnostics${NC}"
  printf -- '--------------------------------------------------\n'
  echo ""

  check_cmd() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" &>/dev/null; then
      printf "  ${GREEN}✓${NC} %-16s ${BOLD}%s${NC} (%s)\n" "$cmd" "found" "$desc"
    else
      printf "  ${RED}✗${NC} %-16s ${YELLOW}%s${NC} (%s)\n" "$cmd" "missing" "$desc"
    fi
  }

  check_font() {
    local pattern="$1"
    local name="$2"
    if command -v fc-list &>/dev/null; then
      if fc-list : family | grep -iq "$pattern"; then
        printf "  ${GREEN}✓${NC} %-16s ${BOLD}%s${NC} (Font)\n" "$name" "installed"
      else
        printf "  ${YELLOW}!${NC} %-16s ${YELLOW}%s${NC} (Font recommended)\n" "$name" "not detected"
      fi
    else
      printf "  ${BLUE}?${NC} %-16s fontconfig (fc-list) unavailable\n" "$name"
    fi
  }

  echo -e "${BOLD}Core Applications:${NC}"
  check_cmd "bash" "Shell"
  check_cmd "git" "Version Control"
  check_cmd "nvim" "Neovim 0.11+ Editor"
  check_cmd "tmux" "Terminal Multiplexer"
  check_cmd "alacritty" "GPU Terminal Emulator"
  check_cmd "niri" "Scrollable Wayland Compositor"
  check_cmd "fastfetch" "System Information Fetch"
  echo ""

  echo -e "${BOLD}CLI & Integration Utilities:${NC}"
  check_cmd "delta" "Git Syntax Pager"
  check_cmd "gh" "GitHub CLI"
  check_cmd "wl-copy" "Wayland Clipboard (wl-clipboard)"
  check_cmd "jq" "JSON Parser (Niri window management)"
  check_cmd "notify-send" "Desktop Notifications"
  check_cmd "fzf" "Fuzzy Finder"
  echo ""

  echo -e "${BOLD}Language Servers & DAP Adapters (Neovim):${NC}"
  check_cmd "pyright" "Python LSP"
  check_cmd "ruff" "Python Linter/Formatter"
  check_cmd "rust-analyzer" "Rust LSP"
  check_cmd "taplo" "TOML LSP"
  check_cmd "marksman" "Markdown LSP"
  check_cmd "kdl-lsp" "KDL Document LSP"
  check_cmd "debugpy" "Python DAP"
  check_cmd "codelldb" "Rust/C/C++ DAP"
  echo ""

  echo -e "${BOLD}Typography:${NC}"
  check_font "FiraCode Nerd Font" "FiraCode NF"
  echo ""
  echo -e "${BLUE}Note:${NC} Doctor is diagnostic only. Install missing tools using your system's package manager."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [MODULE...]

Deterministic and idempotent dotfiles deployment engine.

Modules:
  ${MODULES[*]}

Options:
  -n, --dry-run     Simulate actions without modifying the filesystem
  -s, --status      Display tabular status of managed configuration modules
  -c, --check       Verify all links are healthy (exits 0 on success, 1 otherwise)
  -u, --unlink      Safely remove symlinks owned by this repository
  -d, --doctor      Run environment and dependency diagnostics
  -h, --help        Show this help message

Examples:
  $(basename "$0")                Deploy all modules
  $(basename "$0") nvim tmux      Deploy only nvim and tmux
  $(basename "$0") --dry-run      Preview deployment actions
  $(basename "$0") --status       Inspect current link status
  $(basename "$0") --check        Run CI link verification
  $(basename "$0") --doctor       Check installed tools and language servers
EOF
}

# ------------------------------------------------------------------------------
# CLI Entrypoint
# ------------------------------------------------------------------------------
main() {
  local action="deploy"
  local dry_run=0
  local -a requested_modules=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      -s|--status)
        action="status"
        shift
        ;;
      -c|--check)
        action="check"
        shift
        ;;
      -u|--unlink)
        action="unlink"
        shift
        ;;
      -d|--doctor)
        action="doctor"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        echo -e "${RED}Unknown option: $1${NC}" >&2
        usage >&2
        exit 1
        ;;
      *)
        # Validate module name
        local valid=0
        for m in "${MODULES[@]}"; do
          if [[ "$m" == "$1" ]]; then
            valid=1
            break
          fi
        done
        if [[ "$valid" -eq 0 ]]; then
          echo -e "${RED}Invalid module: $1${NC}" >&2
          echo "Available modules: ${MODULES[*]}" >&2
          exit 1
        fi
        requested_modules+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#requested_modules[@]} -eq 0 ]]; then
    requested_modules=("${MODULES[@]}")
  fi

  case "$action" in
    status)
      cmd_status "${requested_modules[@]}"
      ;;
    check)
      cmd_check "${requested_modules[@]}"
      ;;
    doctor)
      cmd_doctor
      ;;
    unlink)
      echo -e "${BOLD}Unlinking Dotfiles...${NC}"
      for mod in "${requested_modules[@]}"; do
        while IFS=: read -r label src tgt; do
          unlink_target "$label" "$src" "$tgt" "$dry_run"
        done < <(get_module_targets "$mod")
      done
      echo -e "${BOLD}Done.${NC}"
      ;;
    deploy)
      echo -e "${BOLD}Deploying Dotfiles...${NC}"
      for mod in "${requested_modules[@]}"; do
        while IFS=: read -r label src tgt; do
          deploy_target "$label" "$src" "$tgt" "$dry_run"
        done < <(get_module_targets "$mod")
      done
      echo -e "${BOLD}Deployment complete.${NC}"
      ;;
  esac
}

main "$@"
