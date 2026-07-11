-- ai_tools.lua -- Dynamic launchers and layouts for AI coding tools.

local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")

local M = {}

-- Spawn a command in a new tab on the current pane's domain, preserving cwd.
-- If AGENTS.md exists in the cwd, cat it first so the agent has project context.
-- Session logging via script(1) when available.
local function spawn_in_new_tab(cmd)
  return wezterm.action_callback(function(window, pane)
    local cwd = utils.cwd_of(pane)
    local log_dir = (os.getenv("HOME") or "/tmp") .. "/.cache/agent-logs"
    local log_file = log_dir .. "/" .. os.date("%Y-%m-%d-%H%M%S") .. "-" .. cmd[1] .. ".log"
    local agent_cmd = table.concat(cmd, " ")
    local has_script = os.execute("command -v script >/dev/null 2>&1")
    local runner
    if has_script then
      runner = "exec script -q -c '" .. agent_cmd .. "' " .. log_file
    else
      runner = "exec " .. agent_cmd .. " 2>&1 | tee " .. log_file
    end
    local wrapped = {
      "bash", "-c",
      "mkdir -p " .. log_dir .. " && " ..
      "[ -f AGENTS.md ] && cat AGENTS.md && echo '--- context loaded ---'; " ..
      runner,
    }
    window:perform_action(
      act.SpawnCommandInNewTab({
        cwd = cwd,
        domain = { DomainName = pane:get_domain_name() },
        args = wrapped,
      }),
      pane
    )
  end)
end

-- Build the 3-pane agent layout:
--   left          | top-right
--   editor (nvim) | AI tool
--                 | bottom-right (lazygit or fallback)
local function spawn_agent_layout(window, pane, opts)
  opts = opts or {}
  local cwd = opts.cwd or utils.cwd_of(pane)
  local domain = opts.domain or { DomainName = pane:get_domain_name() }
  local ai_cmd = opts.ai_cmd or { "kimi" }
  local bottom_cmd = opts.bottom_cmd
  if not bottom_cmd then
    if utils.which("lazygit") then
      bottom_cmd = { "lazygit" }
    else
      bottom_cmd = { "tail", "-f", "/dev/null" }
    end
  end

  -- Left pane: editor.
  local editor_pane = pane
  if cwd then
    editor_pane:send_text("cd " .. cwd:gsub(" ", "\\ ") .. "\n")
  end
  editor_pane:send_text("nvim .\n")

  -- Right column.
  local right_pane = editor_pane:split({
    direction = "Right",
    size = { Percent = 50 },
    domain = domain,
    cwd = cwd,
  })

  -- Top-right: AI tool (with AGENTS.md pre-load and session logging).
  local log_dir = (os.getenv("HOME") or "/tmp") .. "/.cache/agent-logs"
  local log_file = log_dir .. "/" .. os.date("%Y-%m-%d-%H%M%S") .. "-" .. ai_cmd[1] .. ".log"
  local agent_cmd = table.concat(ai_cmd, " ")
  local has_script = os.execute("command -v script >/dev/null 2>&1")
  local runner
  if has_script then
    runner = "exec script -q -c '" .. agent_cmd .. "' " .. log_file
  else
    runner = "exec " .. agent_cmd .. " 2>&1 | tee " .. log_file
  end
  local wrapped_ai = {
    "bash", "-c",
    "mkdir -p " .. log_dir .. " && " ..
    "[ -f AGENTS.md ] && cat AGENTS.md && echo '--- context loaded ---'; " ..
    runner,
  }
  local ai_pane = right_pane:split({
    direction = "Bottom",
    size = { Percent = 50 },
    domain = domain,
    cwd = cwd,
    args = wrapped_ai,
  })

  -- Bottom-right: lazygit / log watcher.
  right_pane:split({
    direction = "Bottom",
    size = { Percent = 50 },
    domain = domain,
    cwd = cwd,
    args = bottom_cmd,
  })

  -- Focus the AI pane so typing can begin immediately.
  pcall(function()
    ai_pane:activate()
  end)
end

-- Prompt for a Swarm Task ID with history and default-to-last behavior.
local function prompt_for_task_id(description, callback)
  return wezterm.action_callback(function(window, pane)
    local recent = utils.most_recent_task_id()
    local prompt_text = description
    if recent then
      prompt_text = prompt_text .. " [default: " .. recent .. "]"
    end
    window:perform_action(
      act.PromptInputLine({
        description = prompt_text,
        action = wezterm.action_callback(function(inner_window, inner_pane, line)
          local task_id = line
          if not task_id or task_id == "" then
            task_id = recent
          end
          if not task_id or task_id == "" then
            return
          end
          task_id = task_id:gsub("^%s*(.-)%s*$", "%1")
          utils.push_task_id(task_id)
          local remote_path = "/mnt/agent-swarms/" .. task_id
          callback(inner_window, inner_pane, remote_path)
        end),
      }),
      pane
    )
  end)
end

function M.apply(config)
  -- Discover installed AI tools.
  local tool_specs = {
    { key = "k", name = "kimi", label = "Kimi" },
    { key = "a", name = "aider", label = "Aider" },
    { key = "c", name = "claude", label = "Claude" },
    { key = "C", name = "claude-code", label = "Claude Code" },
    { key = "o", name = "codex", label = "Codex" },
    { key = "b", name = "carbonyl", label = "Carbonyl Browser" },
  }

  local installed_tools = {}
  for _, spec in ipairs(tool_specs) do
    if utils.which(spec.name) then
      table.insert(installed_tools, spec)
    end
  end

  -- Kimi snippet launcher.
  local kimi_snippets = {
    review = "/ask review this code for bugs, race conditions, and edge cases",
    test = "/ask write focused tests for the current function or module",
    explain = "/ask explain what this code does and why",
    doc = "/ask add concise docstrings/comments where helpful",
  }

  local function send_kimi_snippet()
    return wezterm.action_callback(function(window, pane)
      local choices = {}
      for name, _ in pairs(kimi_snippets) do
        table.insert(choices, name)
      end
      table.sort(choices)
      window:perform_action(
        act.PromptInputLine({
          description = "Kimi snippet (" .. table.concat(choices, "/") .. ")",
          action = wezterm.action_callback(function(inner_window, inner_pane, line)
            if not line or line == "" then
              return
            end
            local snippet = kimi_snippets[line]
            if snippet then
              inner_pane:send_text(snippet .. "\n")
            end
          end),
        }),
        pane
      )
    end)
  end

  config.key_tables = config.key_tables or {}
  config.key_tables.ai_tools = {
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  }

  for _, spec in ipairs(installed_tools) do
    table.insert(config.key_tables.ai_tools, {
      key = spec.key,
      action = spawn_in_new_tab({ spec.name }),
    })
  end

  -- Add snippet launcher if Kimi is installed.
  if utils.which("kimi") then
    table.insert(config.key_tables.ai_tools, {
      key = "s",
      action = send_kimi_snippet(),
    })
  end

  -- Remote agent layout is reachable from the ai_tools menu as 'r'.
  table.insert(config.key_tables.ai_tools, {
    key = "r",
    action = prompt_for_task_id("Swarm Task ID (remote agent layout)", function(window, pane, remote_path)
      spawn_agent_layout(window, pane, {
        cwd = remote_path,
        domain = { DomainName = "contabo-vps" },
        ai_cmd = { "kimi" },
      })
    end),
  })

  -- LEADER a: persistent AI tool picker — stays in the menu until Esc/q.
  -- Launch chains of agents without re-pressing leader.
  table.insert(config.keys, {
    key = "a",
    mods = "LEADER",
    action = act.ActivateKeyTable({ name = "ai_tools", one_shot = false }),
  })

  -- Full agent-session layout under LEADER + A (local). Uses the first
  -- detected AI tool; falls back to a plain shell.
  table.insert(config.keys, {
    key = "A",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local ai_cmd = #installed_tools > 0 and { installed_tools[1].name } or nil
      spawn_agent_layout(window, pane, { ai_cmd = ai_cmd })
    end),
  })

  -- CMD+SHIFT+J worktree teleportation to Contabo VPS (original Command Tower behavior).
  table.insert(config.keys, {
    key = "J",
    mods = "SUPER|SHIFT",
    action = prompt_for_task_id("Swarm Task ID (Contabo VPS)", function(window, pane, remote_path)
      window:perform_action(
        act.SplitPane({
          direction = "Right",
          size = { Percent = 50 },
          domain = { DomainName = "contabo-vps" },
          command = {
            cwd = remote_path,
            args = { "nvim", "." },
          },
        }),
        pane
      )
    end),
  })

  -- LEADER+SHIFT+J worktree teleportation using the current pane's domain.
  table.insert(config.keys, {
    key = "J",
    mods = "LEADER|SHIFT",
    action = prompt_for_task_id("Swarm Task ID (current domain)", function(window, pane, remote_path)
      window:perform_action(
        act.SplitPane({
          direction = "Right",
          size = { Percent = 50 },
          domain = { DomainName = pane:get_domain_name() },
          command = {
            cwd = remote_path,
            args = { "nvim", "." },
          },
        }),
        pane
      )
    end),
  })
end

return M
