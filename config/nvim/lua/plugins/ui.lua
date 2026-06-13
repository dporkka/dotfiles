-- =============================================================================
-- ui.lua — minimal UI: colorscheme, statusline, notifications
-- NO visual gimmicks. Everything here has a function.
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- COLORSCHEME — tokyonight-storm: readable, good contrast, widely supported
  -- ---------------------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "storm",           -- storm | night | moon | day
      transparent = false,        -- set true if terminal has its own background
      terminal_colors = true,
      dim_inactive = false,       -- don't dim inactive windows (distracting in splits)
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        functions = {},
        variables = {},
        sidebars = "dark",
        floats = "dark",
      },
      on_highlights = function(hl, _)
        -- Make inactive window separator more visible
        hl.WinSeparator = { fg = "#3b4261" }
        -- Slightly subdued diagnostics virtual text
        hl.DiagnosticVirtualTextError = { fg = "#db4b4b", bg = "NONE" }
        hl.DiagnosticVirtualTextWarn = { fg = "#e0af68", bg = "NONE" }
        hl.DiagnosticVirtualTextInfo = { fg = "#0db9d7", bg = "NONE" }
        hl.DiagnosticVirtualTextHint = { fg = "#1abc9c", bg = "NONE" }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-storm")
    end,
  },

  -- ---------------------------------------------------------------------------
  -- LUALINE — statusline, showing only useful info
  -- ---------------------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "tokyonight",
        globalstatus = true,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "starter" } },
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          { "branch", icon = "" },
          {
            "diff",
            symbols = { added = " ", modified = " ", removed = " " },
          },
        },
        lualine_c = {
          { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
        },
        lualine_x = {
          {
            "diagnostics",
            symbols = {
              error = " ",
              warn = " ",
              info = " ",
              hint = " ",
            },
          },
          { "filetype", icon_only = false },
          {
            function()
              local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
              if #buf_clients == 0 then return "No LSP" end
              local names = {}
              for _, client in ipairs(buf_clients) do
                if client.name ~= "null-ls" and client.name ~= "copilot" then
                  table.insert(names, client.name)
                end
              end
              return " " .. table.concat(names, ", ")
            end,
            color = { fg = "#565f89" },
          },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      extensions = { "lazy", "oil", "toggleterm", "quickfix" },
    },
  },

  -- ---------------------------------------------------------------------------
  -- WHICH-KEY — discoverable keybindings. Not a gimmick: essential for
  -- remembering leader bindings across sessions.
  -- ---------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 300,
      spec = {
        { "<leader>a", group = "ai" },
        { "<leader>b", group = "buffers" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>D", group = "database" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>gh", group = "git hunks" },
        { "<leader>h", group = "harpoon" },
        { "<leader>n", group = "test" },
        { "<leader>r", group = "refactor" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "terminal" },
        { "<leader>u", group = "ui/toggle" },
        { "<leader>x", group = "diagnostics/quickfix" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "goto" },
        { "gp", group = "peek" },
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- NOICE — disabled due to memory leaks under heavy LSP/AI traffic
  -- ---------------------------------------------------------------------------
  {
    "folke/noice.nvim",
    enabled = false,
  },

  -- ---------------------------------------------------------------------------
  -- INDENT LINES — minimal, shows indent structure
  -- ---------------------------------------------------------------------------
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = {
      indent = {
        char = "│",
        tab_char = "│",
      },
      scope = { enabled = false },  -- scope highlighting can be noisy
      exclude = {
        filetypes = {
          "help", "alpha", "dashboard", "neo-tree", "Trouble",
          "trouble", "lazy", "mason", "notify", "toggleterm",
          "lazyterm",
        },
      },
    },
  },
}
