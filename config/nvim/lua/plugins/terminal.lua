-- =============================================================================
-- terminal.lua — terminal integration for AI agents and dev workflows
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- VIM-TMUX-NAVIGATOR — seamless Ctrl+hjkl across Neovim splits AND tmux panes.
  -- Your tmux.conf already ships the matching `is_vim` smart-switch bindings, so
  -- C-h/j/k/l now flows editor pane <-> Claude/agent pane as one surface: at a
  -- Neovim split edge focus hands off to the adjacent tmux pane instead of
  -- stalling. (Previously this was zellij-nav, gated on $ZELLIJ, so under tmux it
  -- never loaded and C-hjkl dead-ended at the edge.)
  -- `tmux_navigator_no_mappings = 1` lets us own the maps here, lazy-loaded.
  -- ---------------------------------------------------------------------------
  {
    "christoomey/vim-tmux-navigator",
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Navigate left (nvim/tmux)" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Navigate down (nvim/tmux)" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Navigate up (nvim/tmux)" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (nvim/tmux)" },
    },
  },

  -- ---------------------------------------------------------------------------
  -- TOGGLETERM — persistent terminals in Neovim
  -- WHY: run claude/aider/tests in a persistent terminal that you can hide/show
  -- without losing the process. Critical for AI agent workflows.
  -- ---------------------------------------------------------------------------
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    lazy = true,
    cmd = "ToggleTerm",
    keys = {
      -- Floating terminal (quick commands)
      { "<C-`>", "<cmd>ToggleTerm direction=float<cr>", mode = { "n", "t" }, desc = "Float terminal" },
      -- Horizontal split terminal (logs, tests)
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Terminal (horizontal)" },
      -- Vertical split terminal (side by side with code)
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Terminal (vertical)" },
      -- Named terminals for AI agents
      { "<leader>ta", "<cmd>1ToggleTerm direction=float name=agent<cr>", desc = "Agent terminal" },
      { "<leader>tA", "<cmd>2ToggleTerm direction=float name=agent2<cr>", desc = "Agent 2 terminal" },
      { "<leader>tl", "<cmd>3ToggleTerm direction=horizontal size=20 name=logs<cr>", desc = "Logs terminal" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
      end,
      open_mapping = [[<c-`>]],
      hide_numbers = true,
      shade_terminals = false,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = "float",
      close_on_exit = true,
      shell = vim.o.shell,
      auto_scroll = true,
      float_opts = {
        border = "curved",
        winblend = 5,
        width = function()
          return math.floor(vim.o.columns * 0.85)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.80)
        end,
      },
      highlights = {
        FloatBorder = { link = "FloatBorder" },
      },
      winbar = {
        enabled = false,
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Helper: run command in a named terminal
      local Terminal = require("toggleterm.terminal").Terminal

      -- NOTE: the dedicated Claude Code float used to live here. It's gone because
      -- claudecode.nvim (see plugins/ai.lua, <leader>k...) now owns Claude Code and
      -- gives you the same persistent float PLUS editor integration (selection
      -- context, native in-buffer diffs). The generic agent floats below
      -- (<leader>ta / <leader>tA) remain for aider or any other CLI agent.

      -- Lazygit terminal (standalone, not the plugin — useful as fallback)
      local lazygit = Terminal:new({
        cmd = "lazygit",
        hidden = true,
        direction = "float",
        display_name = "LazyGit",
        float_opts = {
          border = "curved",
          width = math.floor(vim.o.columns * 0.95),
          height = math.floor(vim.o.lines * 0.90),
        },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "t", "q", "<cmd>close<cr>", { noremap = true, silent = true })
        end,
      })

      vim.keymap.set("n", "<leader>tg", function() lazygit:toggle() end, { desc = "LazyGit (terminal)" })
    end,
  },
}
