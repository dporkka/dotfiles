-- =============================================================================
-- extras.lua — additional tools: database, testing, debugging, productivity
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- NVIM-DBTUI / DADBOD — PostgreSQL query runner inside Neovim
  -- WHY: run PostGIS queries without leaving the editor. Connect to any DB.
  -- ---------------------------------------------------------------------------
  {
    "kristijanhusak/vim-dadbod-ui",
    lazy = true,
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    keys = {
      { "<leader>db", "<cmd>DBUIToggle<cr>", desc = "Database UI" },
    },
    init = function()
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_show_database_icon = true
      vim.g.db_ui_use_nerd_fonts = true
      vim.g.db_ui_execute_on_save = false
      -- Configure DB connections via environment variables or:
      -- ~/.local/share/nvim/db_ui/connections.json
    end,
  },

  -- ---------------------------------------------------------------------------
  -- NEOTEST — run tests inline
  -- WHY: see pass/fail in the gutter, jump to failures, run single tests.
  -- Better than switching to a terminal for every test run.
  -- ---------------------------------------------------------------------------
  {
    "nvim-neotest/neotest",
    lazy = true,
    cmd = "Neotest",
    keys = {
      { "<leader>nr", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>nf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run test file" },
      { "<leader>ns", function() require("neotest").summary.toggle() end, desc = "Test summary" },
      { "<leader>no", function() require("neotest").output_panel.toggle() end, desc = "Test output" },
      { "<leader>nS", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Prev failed test" },
      { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-jest",
      "nvim-neotest/neotest-python",
      "marilari88/neotest-vitest",
    },
    opts = function()
      return {
        adapters = {
          require("neotest-jest")({
            jestCommand = "pnpm exec jest",
            jestConfigFile = "jest.config.ts",
            env = { CI = true },
          }),
          require("neotest-vitest"),
          require("neotest-python")({
            dap = { justMyCode = false },
          }),
        },
        status = { virtual_text = true },
        output = { open_on_run = false },
        quickfix = {
          open = function()
            vim.cmd("copen")
          end,
        },
      }
    end,
  },

  -- ---------------------------------------------------------------------------
  -- MINI.SURROUND — surround text with brackets, quotes, tags
  -- ---------------------------------------------------------------------------
  {
    "echasnovski/mini.surround",
    version = false,
    event = "BufReadPost",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- MINI.PAIRS — auto-close brackets, quotes
  -- ---------------------------------------------------------------------------
  {
    "echasnovski/mini.pairs",
    version = false,
    event = "InsertEnter",
    opts = {
      mappings = {
        ["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]." },
        ["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]." },
        ["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]." },
        [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
        ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
        ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
        ['"'] = { action = "closeopen", pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
        ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%a\\].", register = { cr = false } },
        ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].", register = { cr = false } },
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- TROUBLE — organized diagnostics, references, quickfix
  -- ---------------------------------------------------------------------------
  {
    "folke/trouble.nvim",
    lazy = true,
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (trouble)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols (trouble)" },
      { "<leader>xR", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP definitions (trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location list (trouble)" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list (trouble)" },
    },
    opts = {
      modes = {
        lsp = {
          win = { position = "right" },
        },
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- COMMENT.NVIM — smart commenting (handles JSX, TSX embedded languages)
  -- ---------------------------------------------------------------------------
  {
    "numToStr/Comment.nvim",
    event = "BufReadPost",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      require("Comment").setup({
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      })
    end,
  },

  -- ---------------------------------------------------------------------------
  -- TODO-COMMENTS — highlight and search TODO/FIXME/HACK/NOTE
  -- ---------------------------------------------------------------------------
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ft", "<cmd>TodoFzfLua<cr>", desc = "Todo comments" },
      { "]T", function() require("todo-comments").jump_next() end, desc = "Next todo" },
      { "[T", function() require("todo-comments").jump_prev() end, desc = "Prev todo" },
    },
    opts = {
      signs = true,
      sign_priority = 8,
      keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", color = "hint", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- SPECTRE — project-wide search and replace
  -- WHY: when you need to rename a function/type across an entire monorepo,
  -- spectre gives you a live preview before committing the replace.
  -- ---------------------------------------------------------------------------
  {
    "nvim-pack/nvim-spectre",
    lazy = true,
    cmd = "Spectre",
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Search/replace (Spectre)" },
      { "<leader>sw", function() require("spectre").open_visual({ select_word = true }) end, mode = "n", desc = "Search current word" },
    },
    opts = {
      open_cmd = "noswapfile vnew",
    },
  },

  -- ---------------------------------------------------------------------------
  -- TYPESCRIPT UTILITIES — extra TS actions via fzf-lua
  -- ---------------------------------------------------------------------------
  {
    "dmmulroy/ts-error-translator.nvim",
    ft = { "typescript", "typescriptreact" },
    opts = {
      auto_override_publish_diagnostics = true,
    },
  },

  -- ---------------------------------------------------------------------------
  -- PACKAGE-INFO — shows npm package versions in package.json
  -- ---------------------------------------------------------------------------
  {
    "vuki656/package-info.nvim",
    ft = "json",
    dependencies = "MunifTanjim/nui.nvim",
    opts = {
      colors = {
        up_to_date = "#3C4048",
        outdated = "#d19a66",
      },
      icons = {
        enable = true,
        style = {
          up_to_date = "|  ",
          outdated = "|  ",
        },
      },
      autostart = false,  -- don't fetch on every package.json open
      hide_up_to_date = true,
    },
    keys = {
      { "<leader>np", "<cmd>lua require('package-info').toggle()<cr>", desc = "Package info toggle" },
      { "<leader>nu", "<cmd>lua require('package-info').update()<cr>", desc = "Package update" },
    },
  },
}
