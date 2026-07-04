#!/usr/bin/env bash
# =============================================================================
# preflight.sh — pre-install checks for dotfiles workstation setup.
#
# Validates OS, architecture, resources, network reachability, package
# manager locks, and required tooling before setup-workstation.sh runs.
#
# Usage:
#   bash preflight.sh [--json]
#
# Exit codes:
#   0  all checks passed (or only warnings)
#   1  fatal failure(s) detected
# =============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
MIN_RAM_MB=4096
MIN_DISK_GB=10

URLS=(
  "https://github.com"
  "https://raw.githubusercontent.com"
  "https://astral.sh/uv/install.sh"
  "https://get.pnpm.io/install.sh"
  "https://starship.rs/install.sh"
  "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh"
  "https://deb.gierens.de"
)

# ------------------------------------------------------------------------------
# Output mode
# ------------------------------------------------------------------------------
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=true; shift ;;
    --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ------------------------------------------------------------------------------
# Colors (disabled in JSON mode or when not a TTY)
# ------------------------------------------------------------------------------
RED='' GREEN='' YELLOW='' RESET='' BOLD=''
if [[ "$JSON_MODE" == false && -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RESET='\033[0m'
  BOLD='\033[1m'
fi

# ------------------------------------------------------------------------------
# Result collection
# ------------------------------------------------------------------------------
declare -a CHECK_NAMES=()
declare -a CHECK_STATUSES=()
declare -a CHECK_MESSAGES=()

record() {
  local name="$1" status="$2" message="${3:-}"
  CHECK_NAMES+=("$name")
  CHECK_STATUSES+=("$status")
  CHECK_MESSAGES+=("$message")
}

pass() { record "$1" "pass" "$2"; }
warn() { record "$1" "warn" "$2"; }
fail() { record "$1" "fail" "$2"; }

# ------------------------------------------------------------------------------
# JSON helpers
# ------------------------------------------------------------------------------
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

print_json() {
  local ok="true"
  for s in "${CHECK_STATUSES[@]}"; do
    if [[ "$s" == "fail" ]]; then ok="false"; break; fi
  done

  printf '{"ok":%s,"timestamp":"%s","checks":[' "$ok" "$(date -Iseconds)"
  local first=true
  for i in "${!CHECK_NAMES[@]}"; do
    if [[ "$first" == true ]]; then first=false; else printf ','; fi
    printf '\n  {"name":"%s","status":"%s","message":"%s"}' \
      "$(json_escape "${CHECK_NAMES[$i]}")" \
      "$(json_escape "${CHECK_STATUSES[$i]}")" \
      "$(json_escape "${CHECK_MESSAGES[$i]}")"
  done
  printf '\n]}\n'
}

print_human() {
  local has_fail=false has_warn=false
  echo ""
  echo "${BOLD}Preflight checks${RESET}"
  echo "=============================================================="
  for i in "${!CHECK_NAMES[@]}"; do
    local status="${CHECK_STATUSES[$i]}" msg="${CHECK_MESSAGES[$i]}"
    case "$status" in
      pass) printf "${GREEN}✓${RESET} %-24s %s\n" "${CHECK_NAMES[$i]}" "$msg" ;;
      warn) printf "${YELLOW}⚠${RESET} %-24s %s\n" "${CHECK_NAMES[$i]}" "$msg"; has_warn=true ;;
      fail) printf "${RED}✗${RESET} %-24s %s\n" "${CHECK_NAMES[$i]}" "$msg"; has_fail=true ;;
    esac
  done
  echo "=============================================================="
  if [[ "$has_fail" == true ]]; then
    echo ""
    echo -e "${RED}Preflight failed.${RESET} Resolve the issues above and rerun."
  elif [[ "$has_warn" == true ]]; then
    echo ""
    echo -e "${YELLOW}Preflight completed with warnings.${RESET}"
  else
    echo -e "${GREEN}All preflight checks passed.${RESET}"
  fi
}

# ------------------------------------------------------------------------------
# Check implementations
# ------------------------------------------------------------------------------

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    fail "os" "/etc/os-release not found"
    return
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local id="${ID:-unknown}" version="${VERSION_ID:-0}"
  local major="${version%%.*}"

  case "$id" in
    ubuntu)
      if [[ "$major" -ge 22 ]]; then
        pass "os" "Ubuntu ${version}"
      else
        fail "os" "Ubuntu ${version} is too old (need 22.04+)"
      fi
      ;;
    fedora)
      if [[ "$major" -ge 40 ]]; then
        pass "os" "Fedora ${version}"
      else
        fail "os" "Fedora ${version} is too old (need 40+)"
      fi
      ;;
    *)
      fail "os" "Unsupported OS: ${id} ${version} (need Ubuntu 22.04+ or Fedora 40+)"
      ;;
  esac
}

check_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|aarch64) pass "arch" "$arch" ;;
    *) fail "arch" "Unsupported architecture: $arch (need x86_64 or aarch64)" ;;
  esac
}

check_ram() {
  local total_mb
  if command -v free &>/dev/null; then
    total_mb="$(free -m | awk '/^Mem:/{print $2}')"
  else
    total_mb="$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo)"
  fi

  if [[ -z "$total_mb" || ! "$total_mb" =~ ^[0-9]+$ ]]; then
    warn "ram" "Could not determine total RAM"
    return
  fi

  if [[ "$total_mb" -ge "$MIN_RAM_MB" ]]; then
    pass "ram" "${total_mb} MB"
  else
    fail "ram" "${total_mb} MB (need ${MIN_RAM_MB} MB)"
  fi
}

check_disk() {
  local free_gb
  free_gb="$(df -BG / | awk 'NR==2 {print $4+0}')"

  if [[ -z "$free_gb" || ! "$free_gb" =~ ^[0-9]+$ ]]; then
    warn "disk" "Could not determine free disk space on /"
    return
  fi

  if [[ "$free_gb" -ge "$MIN_DISK_GB" ]]; then
    pass "disk" "${free_gb} GB free on /"
  else
    fail "disk" "${free_gb} GB free on / (need ${MIN_DISK_GB} GB)"
  fi
}

check_network() {
  local failed=() url
  for url in "${URLS[@]}"; do
    if curl -fsS --max-time 15 -o /dev/null "$url" 2>/dev/null; then
      continue
    else
      failed+=("$url")
    fi
  done

  if [[ ${#failed[@]} -eq 0 ]]; then
    pass "network" "all ${#URLS[@]} URLs reachable"
  else
    fail "network" "unreachable: $(printf '%s ' "${failed[@]}")"
  fi
}

check_package_locks() {
  local lock_held=false

  if command -v apt-get &>/dev/null; then
    local apt_locks=(
      /var/lib/apt/lists/lock
      /var/lib/dpkg/lock
      /var/lib/dpkg/lock-frontend
    )
    if command -v fuser &>/dev/null; then
      for lock in "${apt_locks[@]}"; do
        if [[ -f "$lock" ]] && fuser -s "$lock" 2>/dev/null; then
          warn "package-locks" "APT lock held: $lock"
          lock_held=true
        fi
      done
    else
      warn "package-locks" "fuser not available; cannot detect APT locks"
    fi
  fi

  if command -v dnf &>/dev/null; then
    local dnf_pid_file="/var/run/dnf.pid"
    if [[ -f "$dnf_pid_file" ]]; then
      local pid
      pid="$(cat "$dnf_pid_file" 2>/dev/null || true)"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        warn "package-locks" "DNF lock held (pid $pid)"
        lock_held=true
      fi
    fi
  fi

  if [[ "$lock_held" == false ]]; then
    pass "package-locks" "no package manager locks detected"
  fi
}

check_tools() {
  local tool missing=false
  for tool in git curl sudo; do
    if ! command -v "$tool" &>/dev/null; then
      fail "tool:$tool" "not found in PATH"
      missing=true
    fi
  done

  if [[ "$missing" == false ]]; then
    pass "tools" "git, curl, and sudo are available"
  fi

  if command -v sudo &>/dev/null && ! sudo -n true 2>/dev/null; then
    warn "sudo" "sudo is installed but may require interactive authentication"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
check_os
check_arch
check_ram
check_disk
check_network
check_package_locks
check_tools

if [[ "$JSON_MODE" == true ]]; then
  print_json
else
  print_human
fi

for s in "${CHECK_STATUSES[@]}"; do
  if [[ "$s" == "fail" ]]; then
    exit 1
  fi
done

exit 0
