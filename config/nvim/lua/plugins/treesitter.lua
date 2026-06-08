-- =============================================================================
-- treesitter.lua — syntax, folding, text objects
-- =============================================================================

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    opts = {
      ensure_installed = {
        -- Core languages
        "typescript", "tsx", "javascript", "jsdoc",
        "python", "lua", "bash", "fish",

        -- Web
        "html", "css", "scss",

        -- Data
        "json", "jsonc", "yaml", "toml", "xml",
        "sql",

        -- Infrastructure
        "dockerfile", "nginx",

        -- Git
        "git_config", "git_rebase", "gitcommit", "gitignore", "gitattributes",

        -- Markdown
        "markdown", "markdown_inline",

        -- Config
        "vim", "vimdoc", "query", "regex",

        -- Misc
        "graphql", "prisma",
      },
      auto_install = true,  -- install missing parsers on open
      highlight = {
        enable = true,
        disable = function(_, buf)
          -- Disable on large files
          local max_filesize = 1024 * 1024  -- 1MB
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then return true end
        end,
      },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["ai"] = "@conditional.outer",
            ["ii"] = "@conditional.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["ab"] = "@block.outer",
            ["ib"] = "@block.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]f"] = "@function.outer",
            ["]c"] = "@class.outer",
            ["]a"] = "@parameter.inner",
          },
          goto_next_end = {
            ["]F"] = "@function.outer",
            ["]C"] = "@class.outer",
          },
          goto_previous_start = {
            ["[f"] = "@function.outer",
            ["[c"] = "@class.outer",
            ["[a"] = "@parameter.inner",
          },
          goto_previous_end = {
            ["[F"] = "@function.outer",
            ["[C"] = "@class.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>ca"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>cA"] = "@parameter.inner",
          },
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- ---------------------------------------------------------------------------
  -- TREESITTER-CONTEXT — sticky scroll: pins current function/class at top
  -- Exactly what Cursor's sticky context bar does. [C jumps up to the context.
  -- ---------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    opts = {
      enable = true,
      max_lines = 3,
      min_window_height = 0,
      trim_scope = "outer",
      mode = "cursor",
      separator = nil,
      zindex = 20,
    },
    keys = {
      { "[C", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Go to context" },
    },
  },
}
