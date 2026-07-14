-- status.lua -- Status line, tab titles, and notification hooks.

local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")

local M = {}

local NODE_HEALTH_FILE = (os.getenv("HOME") or "/tmp") .. "/.cache/dev-plane/node-health.json"

-- Cache node-health reads for a few seconds so update-status (which fires on
-- every redraw) doesn't hit the disk and parse JSON each tick.
local HEALTH_CACHE_TTL = 5
local _health_cache = { value = nil, at = 0, populated = false }

local function read_node_health()
  local now = os.time()
  if _health_cache.populated and (now - _health_cache.at) < HEALTH_CACHE_TTL then
    return _health_cache.value
  end

  local value = nil
  local f = io.open(NODE_HEALTH_FILE, "r")
  if f then
    local data = f:read("*a")
    f:close()
    if data and data ~= "" then
      local ok, parsed = pcall(wezterm.json_parse, data)
      if ok then
        value = parsed
      end
    end
  end

  _health_cache = { value = value, at = now, populated = true }
  return value
end

function M.apply(config)
  -- Disable audible bell; rely on visual bell and notifications.
  config.audible_bell = "Disabled"

  -- OSC 777 push alerts on bell events.
  wezterm.on("bell", function(window, pane)
    if not window.toast_notification then
      return
    end
    local domain = pane.get_domain_name and pane:get_domain_name() or "unknown"
    window:toast_notification(
      "Command Tower Alert",
      "Worker error or manual triage boundary triggered (domain: " .. domain .. ")",
      nil,
      4000
    )
  end)
  -- Selection → clipboard sync: when text is selected with the mouse (PRIMARY),
  -- also copy it to CLIPBOARD so Ctrl+V pastes it. Tracks last selection per
  -- pane to avoid redundant clipboard writes.
  local _last_selection = {}

  -- Ambient status line.
  wezterm.on("update-status", function(window, pane)
    -- Sync mouse selection to clipboard (Ctrl+V).
    local pane_id = pane:pane_id()
    local sel = window:get_selection_text_for_pane(pane) or ""
    if sel ~= (_last_selection[pane_id] or "") then
      _last_selection[pane_id] = sel
      if #sel > 0 then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
      end
    end

    local cwd = utils.cwd_of(pane)

    -- Left status: git branch + agent task.
    local left_cells = {}
    if branch then
      table.insert(left_cells, { Foreground = { Color = "#b4befe" } })
      table.insert(left_cells, { Text = "  " .. branch .. " " })
    end
    if task_id and task_id ~= "" then
      table.insert(left_cells, { Foreground = { Color = "#f5c2e7" } })
      table.insert(left_cells, { Text = "ﬦ " .. task_id .. " " })
    end
    if #left_cells > 0 then
      window:set_left_status(wezterm.format(left_cells))
    else
      window:set_left_status(wezterm.format({ { Text = " " } }))
    end

    -- Right status: battery (if low) + node health.
    local right_cells = {}
    if battery and battery.status == "Discharging" and battery.capacity <= 30 then
      table.insert(right_cells, { Foreground = { Color = "#f38ba8" } })
      table.insert(right_cells, { Text = "  " .. battery.capacity .. "% " })
    end

    local health = read_node_health()
    if not health then
      table.insert(right_cells, { Foreground = { Color = "#f38ba8" } })
      table.insert(right_cells, { Text = " no-health " })
    else
      local status = health.status or "unknown"
      local nodes = health.nodes or 0
      local agents = health.agents or 0
      local load = health.load_avg and health.load_avg[1] or "?"
      local color = "#a6e3a1"
      if status == "degraded" then
        color = "#f9e2af"
      elseif status == "unhealthy" then
        color = "#f38ba8"
      end
      local text = string.format(" %s | nodes:%d agents:%d load:%s ", status, nodes, agents, load)
      table.insert(right_cells, { Foreground = { Color = color } })
      table.insert(right_cells, { Text = text })
    end

    window:set_right_status(wezterm.format(right_cells))
  end)

  -- Tab titles colored by domain and showing cwd basename.
  wezterm.on("format-tab-title", function(tab, tabs, panes, config_obj, hover, max_width)
    local pane = tab.active_pane
    local domain = pane.domain_name or "?"
    local cwd = pane.current_working_dir and pane.current_working_dir.file_path or ""
    local cwd_basename = cwd:match("([^/]+)/?$") or ""
    local title = string.format(" %d:%s ", tab.tab_index + 1, domain)
    if cwd_basename ~= "" then
      title = string.format(" %d:%s|%s ", tab.tab_index + 1, domain, cwd_basename)
    end

    local bg = utils.domain_color(domain)
    local fg = "#1e1e2e"
    if not tab.is_active then
      bg = "#313244"
      fg = "#a6adc8"
    end

    return {
      { Background = { Color = bg } },
      { Foreground = { Color = fg } },
      { Text = title },
    }
  end)
end

return M
