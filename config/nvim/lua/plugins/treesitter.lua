-- =============================================================================
-- treesitter.lua — syntax, folding, text objects
-- =============================================================================

return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Pin to the classic `master` branch. LazyVim defaults to the `main`-branch
    -- rewrite, which removed `nvim-treesitter.configs` and the inline opts schema
    -- used below. Staying on master keeps this config (textobjects/swap/etc.) valid.
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",  -- pinned to master below
    },
    opts = {
      ensure_installed = {
        "typescript",
        "tsx",
        "javascript",
        "lua",
        "bash",
        "markdown",
        "markdown_inline",
        "json",
        "yaml",
      },
      auto_install = false,
      highlight = {
        enable = true,
        disable = function(_, buf)
          -- Disable on large files
          local max_filesize = 1024 * 1024  -- 1MB
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then return true end
        end,
      },
      indent = { enable = false },
      incremental_selection = {
        enable = false,
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
          enable = false,
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
  -- TEXTOBJECTS — pin to master + neutralize LazyVim's main-branch config.
  -- LazyVim v15 ships an nvim-treesitter-textobjects spec on the `main` branch
  -- whose config calls the main-only `setup()` and errors on master. On master,
  -- textobjects are configured via the parent `configs.setup({ textobjects=… })`
  -- above, so we override that spec with a no-op config here to silence the nag.
  -- ---------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "master",
    config = function() end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    enabled = false,
  },
}
