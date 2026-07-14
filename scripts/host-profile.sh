#!/usr/bin/env bash
# =============================================================================
# host-profile.sh — detect hardware tier + resource pressure, generate tunables
# for the terminal/agent stack (tmux, wezterm, nvim, agent scripts).
#
# Outputs (all under ~/.local/state/):
#   host/profile.env        KEY=VALUE lines, bash-sourceable (the contract)
#   tmux/tunables.conf      set -g history-limit / status-interval
#   wezterm/tunables.lua    return { scrollback_lines, max_fps, animation_fps }
#   nvim/tunables.lua       return { undolevels, persistence_max_buffers,
#                                    avante_max_tokens }
#
# Tiers (hardware):
#   low  (<8GB RAM or <4 cores)    mid (8-16GB or 4-8 cores)
#   high (>16GB RAM and >8 cores)
#
# Pressure clamp: effective tier = hardware tier downgraded one step (min low)
# when MemAvailable < 20% of MemTotal OR 1-min load > cpus*1.5. Hysteresis:
# downgrade immediately, upgrade back only after 3 consecutive no-pressure
# runs (tracked in ~/.local/state/host/pressure-history, last 3 entries).
# Battery discharging forces WEZTERM_MAX_FPS=30 regardless of tier.
#
# Safe to run every 15 min (systemd host-profile.timer). Never fails hard on
# missing /proc or /sys data: falls back to mid tier.
#
# Env overrides (testing):
#   HOST_PROFILE_FORCE_TIER=low|mid|high  force hardware tier; skips the
#                                         pressure clamp and history updates
#   HOST_PROFILE_LOAD1=<float>            override detected 1-min load
#   HOST_PROFILE_MEM_AVAILABLE_KB=<int>   override detected MemAvailable
#
# Usage: host-profile.sh
# =============================================================================

set -euo pipefail

STATE_DIR="$HOME/.local/state"
HOST_DIR="$STATE_DIR/host"
PROFILE_ENV="$HOST_DIR/profile.env"
HISTORY_FILE="$HOST_DIR/pressure-history"
TMUX_TUNABLES="$STATE_DIR/tmux/tunables.conf"
WEZTERM_TUNABLES="$STATE_DIR/wezterm/tunables.lua"
NVIM_TUNABLES="$STATE_DIR/nvim/tunables.lua"

mkdir -p "$HOST_DIR" "$STATE_DIR/tmux" "$STATE_DIR/wezterm" "$STATE_DIR/nvim"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

tier_rank() {  # low|mid|high -> 1|2|3
  case "$1" in
    low)  echo 1 ;;
    mid)  echo 2 ;;
    high) echo 3 ;;
    *)    echo 0 ;;
  esac
}

downgrade() {  # one step down, min low
  case "$1" in
    high) echo mid ;;
    *)    echo low ;;
  esac
}

# write_if_changed <path> <content> — atomic write; returns 0 if changed.
write_if_changed() {
  local path="$1" content="$2"
  if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
    return 1
  fi
  local tmp="${path}.tmp.$$"
  printf '%s\n' "$content" > "$tmp"
  mv -f "$tmp" "$path"
  return 0
}

# ------------------------------------------------------------------------------
# Hardware detection (never fatal; incomplete data -> mid tier fallback)
# ------------------------------------------------------------------------------

cpus="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
mem_total_kb=""
mem_avail_kb=""
if [[ -r /proc/meminfo ]]; then
  mem_total_kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
  mem_avail_kb="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
fi
load1=""
if [[ -r /proc/loadavg ]]; then
  load1="$(awk '{print $1; exit}' /proc/loadavg 2>/dev/null || true)"
fi

# Testing hooks: override detected values.
[[ -n "${HOST_PROFILE_LOAD1:-}" ]] && load1="$HOST_PROFILE_LOAD1"
[[ -n "${HOST_PROFILE_MEM_AVAILABLE_KB:-}" ]] && mem_avail_kb="$HOST_PROFILE_MEM_AVAILABLE_KB"

[[ "$cpus" =~ ^[0-9]+$ ]] || cpus=""
[[ "$mem_total_kb" =~ ^[0-9]+$ ]] || mem_total_kb=""
[[ "$mem_avail_kb" =~ ^[0-9]+$ ]] || mem_avail_kb=""

ram_gb=0
if [[ -n "$mem_total_kb" ]]; then
  ram_gb=$(( (mem_total_kb + 524288) / 1048576 ))  # GiB, rounded
fi

has_battery=0
discharging=0
for bat in /sys/class/power_supply/BAT*; do
  [[ -e "$bat" ]] || continue
  has_battery=1
  status="$(cat "$bat/status" 2>/dev/null || true)"
  [[ "$status" == "Discharging" ]] && discharging=1
done

# ------------------------------------------------------------------------------
# Hardware tier
# ------------------------------------------------------------------------------

force_tier="${HOST_PROFILE_FORCE_TIER:-}"
if [[ -n "$force_tier" ]]; then
  case "$force_tier" in
    low|mid|high) hw_tier="$force_tier" ;;
    *) echo "host-profile: ignoring invalid HOST_PROFILE_FORCE_TIER='$force_tier'" >&2
       force_tier="" ;;
  esac
fi

if [[ -z "$force_tier" ]]; then
  if [[ -z "$cpus" || -z "$mem_total_kb" ]]; then
    hw_tier="mid"  # detection failed -> safe fallback
  elif (( mem_total_kb > 16*1048576 && cpus > 8 )); then
    hw_tier="high"
  elif (( mem_total_kb < 8*1048576 || cpus < 4 )); then
    hw_tier="low"
  else
    hw_tier="mid"
  fi
fi

# ------------------------------------------------------------------------------
# Pressure detection + hysteresis
# ------------------------------------------------------------------------------

under_pressure=0
pressure_reasons=""
if [[ -n "$mem_avail_kb" && -n "$mem_total_kb" ]] \
  && (( mem_avail_kb * 5 < mem_total_kb )); then
  under_pressure=1
  pressure_reasons="${pressure_reasons}mem"
fi
if [[ -n "$load1" && -n "$cpus" ]] \
  && awk -v l="$load1" -v c="$cpus" 'BEGIN{ exit !(l > c*1.5) }'; then
  under_pressure=1
  pressure_reasons="${pressure_reasons:+,}load"
fi

if [[ -n "$force_tier" ]]; then
  # Forced tier: report pressure but do not clamp, do not touch history.
  eff_tier="$hw_tier"
else
  # Append current pressure flag, keep last 3.
  printf '%s\n' "$under_pressure" >> "$HISTORY_FILE"
  tail -n 3 "$HISTORY_FILE" > "$HISTORY_FILE.tmp.$$"
  mv -f "$HISTORY_FILE.tmp.$$" "$HISTORY_FILE"

  if (( under_pressure )); then
    eff_tier="$(downgrade "$hw_tier")"
  elif [[ "$(wc -l < "$HISTORY_FILE")" -eq 3 ]] \
    && ! grep -q '^1$' "$HISTORY_FILE"; then
    # 3 consecutive no-pressure runs -> full upgrade back.
    eff_tier="$hw_tier"
  else
    # Inside the hysteresis window: hold the previous effective tier.
    prev_eff=""
    if [[ -r "$PROFILE_ENV" ]]; then
      prev_eff="$(awk -F= '/^HOST_EFFECTIVE_TIER=/ {print $2; exit}' "$PROFILE_ENV" 2>/dev/null || true)"
    fi
    case "$prev_eff" in
      low|mid|high) eff_tier="$prev_eff" ;;
      *)            eff_tier="$hw_tier" ;;
    esac
    # Never exceed the current hardware tier (e.g. after a forced-tier test).
    if (( $(tier_rank "$eff_tier") > $(tier_rank "$hw_tier") )); then
      eff_tier="$hw_tier"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# Tier table
# ------------------------------------------------------------------------------

: "${cpus:=0}"
case "$eff_tier" in
  low)
    history_limit=5000;  status_interval=60; scrollback=5000
    fps=30; undolevels=500;  buffers=10; tokens=8000
    agent_max_load="$(awk -v c="$cpus" 'BEGIN{ printf "%g", c*0.75 }')"
    log_cap=100; log_age=3
    ;;
  high)
    history_limit=25000; status_interval=30; scrollback=25000
    fps=60; undolevels=2000; buffers=20; tokens=16000
    agent_max_load="$(awk -v c="$cpus" 'BEGIN{ printf "%g", c*1.5 }')"
    log_cap=300; log_age=14
    ;;
  *)  # mid
    history_limit=15000; status_interval=30; scrollback=15000
    fps=30; undolevels=1000; buffers=15; tokens=12000
    agent_max_load="$cpus"
    log_cap=200; log_age=7
    ;;
esac

# Battery discharging caps FPS at 30 regardless of tier.
(( discharging )) && fps=30

# ------------------------------------------------------------------------------
# Write the four output files
# ------------------------------------------------------------------------------

write_if_changed "$PROFILE_ENV" \
"HOST_TIER=$hw_tier
HOST_EFFECTIVE_TIER=$eff_tier
HOST_CPUS=$cpus
HOST_RAM_GB=$ram_gb
HOST_HAS_BATTERY=$has_battery
HOST_UNDER_PRESSURE=$under_pressure
TMUX_HISTORY_LIMIT=$history_limit
TMUX_STATUS_INTERVAL=$status_interval
WEZTERM_SCROLLBACK=$scrollback
WEZTERM_MAX_FPS=$fps
NVIM_UNDOLEVELS=$undolevels
NVIM_PERSISTENCE_MAX_BUFFERS=$buffers
AVANTE_MAX_TOKENS=$tokens
AGENT_MAX_LOAD=$agent_max_load
AGENT_LOG_CAP=$log_cap
AGENT_LOG_MAX_AGE_DAYS=$log_age" || true

tmux_changed=0
if write_if_changed "$TMUX_TUNABLES" \
"# Generated by host-profile.sh — do not edit.
set -g history-limit $history_limit
set -g status-interval $status_interval"; then
  tmux_changed=1
fi

write_if_changed "$WEZTERM_TUNABLES" \
"-- Generated by host-profile.sh — do not edit.
return { scrollback_lines = $scrollback, max_fps = $fps, animation_fps = $fps }" || true

write_if_changed "$NVIM_TUNABLES" \
"-- Generated by host-profile.sh — do not edit.
return { undolevels = $undolevels, persistence_max_buffers = $buffers, avante_max_tokens = $tokens }" || true

# ------------------------------------------------------------------------------
# Auto-apply to a running tmux server (only when tunables changed)
# ------------------------------------------------------------------------------

tmux_applied=0
if (( tmux_changed )) && command -v tmux >/dev/null 2>&1 \
  && tmux list-sessions >/dev/null 2>&1; then
  if tmux source-file "$TMUX_TUNABLES" 2>/dev/null; then
    tmux_applied=1
  fi
fi

echo "host-profile: tier=$hw_tier effective=$eff_tier cpus=$cpus ram_gb=$ram_gb" \
  "battery=$has_battery discharging=$discharging pressure=$under_pressure(${pressure_reasons:-none})" \
  "fps=$fps tmux_applied=$tmux_applied${force_tier:+ force_tier=$force_tier}"
