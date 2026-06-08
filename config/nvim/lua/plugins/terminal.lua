-- =============================================================================
-- terminal.lua — terminal integration for AI agents and dev workflows
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- ZELLIJ-NAV — seamless Ctrl+hjkl navigation across Neovim splits and Zellij panes
  -- Only active inside a Zellij session (ZELLIJ env var set). Calls
  -- `zellij action move-focus` when at the edge of Neovim's window layout.
  -- ---------------------------------------------------------------------------
  {
    "swaits/zellij-nav.nvim",
    lazy = true,
    event = "VeryLazy",
    cond = function()
      return vim.env.ZELLIJ ~= nil
    end,
    keys = {
      { "<C-h>", "<cmd>ZellijNavigateLeftTab<cr>",  desc = "Navigate left (Neovim/Zellij)" },
      { "<C-j>", "<cmd>ZellijNavigateDown<cr>",     desc = "Navigate down (Neovim/Zellij)" },
      { "<C-k>", "<cmd>ZellijNavigateUp<cr>",       desc = "Navigate up (Neovim/Zellij)" },
      { "<C-l>", "<cmd>ZellijNavigateRightTab<cr>", desc = "Navigate right (Neovim/Zellij)" },
    },
    opts = {},
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

      -- Claude Code terminal (persistent)
      local claude = Terminal:new({
        cmd = "claude",
        hidden = true,
        direction = "float",
        display_name = "Claude Code",
        float_opts = { border = "curved" },
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
      })

      vim.keymap.set("n", "<leader>tc", function() claude:toggle() end, { desc = "Claude Code terminal" })

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
