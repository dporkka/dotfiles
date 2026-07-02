-- =============================================================================
-- extras.lua — additional tools: database, testing, debugging, productivity
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- NVIM-DBTUI / DADBOD — PostgreSQL query runner inside Neovim
  -- Key: <leader>D (moved off <leader>db to free the d prefix for DAP)
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
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Database UI" },
    },
    init = function()
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_show_database_icon = true
      vim.g.db_ui_use_nerd_fonts = true
      vim.g.db_ui_execute_on_save = false
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
    "nvim-mini/mini.surround",
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
    "nvim-mini/mini.pairs",
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
  -- GRUG-FAR — project-wide search and replace (replaces spectre)
  -- WHY over spectre: simpler mental model, live preview, ripgrep native.
  -- ---------------------------------------------------------------------------
  {
    "MagicDuck/grug-far.nvim",
    lazy = true,
    cmd = "GrugFar",
    keys = {
      { "<leader>sr", "<cmd>GrugFar<cr>", desc = "Search/replace (grug-far)" },
      {
        "<leader>sw",
        function()
          require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
        end,
        desc = "Search current word",
      },
      {
        "<leader>sw",
        function()
          require("grug-far").with_visual_selection()
        end,
        mode = "v",
        desc = "Search selection",
      },
    },
    opts = {
      engine = "ripgrep",
      headerMaxWidth = 80,
      windowCreationCommand = "vsplit",
    },
  },

  -- ---------------------------------------------------------------------------
  -- AERIAL — code outline / symbol tree (Cursor's outline panel equivalent)
  -- ---------------------------------------------------------------------------
  {
    "stevearc/aerial.nvim",
    lazy = true,
    cmd = { "AerialToggle", "AerialNavToggle" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>co", "<cmd>AerialToggle!<cr>",   desc = "Symbol outline (Aerial)" },
      { "<leader>cO", "<cmd>AerialNavToggle<cr>", desc = "Symbol nav (Aerial)" },
    },
    opts = {
      backends   = { "lsp", "treesitter", "markdown", "man" },
      attach_mode = "global",
      show_guides = true,
      layout = {
        max_width    = { 40, 0.2 },
        min_width    = 20,
        default_direction = "prefer_right",
      },
      guides = {
        mid_item   = "├─",
        last_item  = "└─",
        nested_top = "│ ",
        whitespace = "  ",
      },
      filter_kind     = false,
      highlight_on_hover = true,
      autojump        = false,
    },
  },

  -- ---------------------------------------------------------------------------
  -- GLANCE — peek definitions/references in a floating window (like Cursor)
  -- gpd/gpr/gpi/gpt = peek definition/references/implementations/typedef
  -- ---------------------------------------------------------------------------
  {
    "dnlhc/glance.nvim",
    lazy = true,
    cmd = "Glance",
    keys = {
      { "gpd", "<cmd>Glance definitions<cr>",      desc = "Peek definition" },
      { "gpr", "<cmd>Glance references<cr>",       desc = "Peek references" },
      { "gpi", "<cmd>Glance implementations<cr>",  desc = "Peek implementations" },
      { "gpt", "<cmd>Glance type_definitions<cr>", desc = "Peek type definitions" },
    },
    config = function()
      require("glance").setup({
        height       = 18,
        border       = { enable = true },
        theme        = { enable = true, mode = "auto" },
        list         = { position = "right", width = 0.33 },
        preview_win_opts = { number = true, wrap = false },
        winbar       = { enable = true },
        folds        = { fold_closed = "", fold_open = "", folded = true },
      })
    end,
  },

  -- ---------------------------------------------------------------------------
  -- INC-RENAME — live rename preview (type the new name, see it applied live)
  -- Replaces the default LSP rename prompt with an in-place inline rename.
  -- ---------------------------------------------------------------------------
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    keys = {
      {
        "<leader>cr",
        function() return ":IncRename " .. vim.fn.expand("<cword>") end,
        expr = true,
        desc = "Rename (inc-rename)",
      },
    },
    opts = {},
  },

  -- ---------------------------------------------------------------------------
  -- REFACTORING — extract function/variable, inline variable (treesitter-aware)
  -- ---------------------------------------------------------------------------
  {
    "ThePrimeagen/refactoring.nvim",
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>re", function() require("refactoring").refactor("Extract Function") end,         mode = "v", desc = "Extract function" },
      { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end,         mode = "v", desc = "Extract variable" },
      { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end, mode = { "n", "v" }, desc = "Inline variable" },
      { "<leader>rE", function() require("refactoring").refactor("Extract Function To File") end, mode = "v", desc = "Extract to file" },
      { "<leader>rr", function() require("refactoring").select_refactor() end, mode = { "n", "v" }, desc = "Select refactor" },
    },
    opts = {},
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
