-- wezterm.lua -- Master WezTerm configuration for the Command Tower.
--
-- Features:
--   * Modular config split across the wezterm/ directory.
--   * WebGpu / OpenGL hardware accelerated graphics backend.
--   * Kitty Graphics Protocol (KGP) pass-through & Kitty Keyboard Protocol enabled.
--   * Tailscale-bound multiplexer domains for WSL2, Mini-PC, and Contabo VPS.
--   * Leader key (CTRL+Space) for tabs, panes, domains, and resize mode.
--   * AI tool launchers under LEADER + a (kimi, aider, claude, claude-code, codex).
--   * Agent session layouts under LEADER + A and LEADER + Shift + A.
--   * Workspace presets under LEADER + w.
--   * OSC 52 clipboard integration and OSC 777 bell-driven push alerts.
--   * dev-plane node-health status line.
--
-- Reload config with: LEADER + Shift + R (or CTRL+SHIFT+R by default).

local wezterm = require("wezterm")
local config = wezterm.config_builder and wezterm.config_builder() or {}

--------------------------------------------------------------------------------
-- ── KITTY GRAPHICS PROTOCOL & AGENTIC INFRASTRUCTURE INJECTIONS ────────────────
--------------------------------------------------------------------------------

-- GPU, kitty protocols, scrollback, and color/font config live in appearance.lua.
-- Only module loader + coordination stays here.
--------------------------------------------------------------------------------
-- ── MODULAR CORE LOADER ──────────────────────────────────────────────────────
--------------------------------------------------------------------------------

require("appearance").apply(config)
require("domains").apply(config)
require("keys").apply(config)
require("ai_tools").apply(config)
require("workspaces").apply(config)
require("status").apply(config)

return config