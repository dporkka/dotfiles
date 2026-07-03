-- =============================================================================
-- mcp.lua — mcphub.nvim: a local MCP hub/bridge that feeds MCP tools to avante.
--
-- This is the "local MCP bridge server in the tmux topology" piece: mcphub runs
-- the `mcp-hub` node binary as a background server (port 37373) that manages the
-- MCP servers defined in our UNIFIED blueprint and exposes them to Neovim.
--
-- Single source of truth: it reads the SAME file Claude Code uses
-- (config/mcp/servers.json), so avante and Claude Code share one server list.
--
-- Usage:
--   :MCPHub            open the hub UI (start servers, inspect tools/resources)
--   <leader>am         (avante) tools are auto-injected; just ask avante to use them
--   In the UI: R restart hub · ga toggle global auto-approve · M marketplace
-- Health: :checkhealth mcphub
-- Requires: Node >= 18; the `build` step installs the mcp-hub binary globally.
-- =============================================================================

return {
  {
    "ravitemer/mcphub.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "MCPHub",
    build = "npm install -g mcp-hub@latest",
    opts = {
      -- Point the hub at our committed blueprint instead of the default
      -- ~/.config/mcphub/servers.json. Same file Claude Code syncs from.
      config = vim.fn.expand("~/dotfiles/config/mcp/servers.json"),
      -- Let the model start/stop servers on demand in agentic mode.
      auto_toggle_mcp_servers = true,
      -- Skip the per-call confirm dialog for MCP tools inside avante. Flip to
      -- false (or a function) if you want to approve each tool call.
      auto_approve = true,
      extensions = {
        avante = {
          make_slash_commands = true, -- MCP prompts become /mcp:server:prompt
        },
      },
    },
  },
}
