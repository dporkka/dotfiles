-- =============================================================================
-- formatting.lua — conform.nvim for deterministic, project-aware formatting
-- =============================================================================

return {
  {
    "stevearc/conform.nvim",
    lazy = true,
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = { "n", "v" },
        desc = "Format file/selection",
      },
    },
    opts = {
      -- WHY conform over LSP formatting:
      -- 1. Consistent across LSP and non-LSP files
      -- 2. Respects project-local formatter config
      -- 3. Supports running multiple formatters in sequence
      -- 4. Format-on-save without blocking UI

      formatters_by_ft = {
        -- TypeScript/JavaScript: prefer biome if config exists, else prettier
        typescript = { "biome", "prettier", stop_after_first = true },
        typescriptreact = { "biome", "prettier", stop_after_first = true },
        javascript = { "biome", "prettier", stop_after_first = true },
        javascriptreact = { "biome", "prettier", stop_after_first = true },
        json = { "biome", "prettier", stop_after_first = true },
        jsonc = { "biome", "prettier", stop_after_first = true },

        -- Web
        css = { "prettier" },
        html = { "prettier" },
        scss = { "prettier" },

        -- Markup / config
        markdown = { "prettier" },
        yaml = { "prettier" },
        toml = { "taplo" },

        -- Python
        python = { "isort", "black" },

        -- Lua
        lua = { "stylua" },

        -- Shell
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },

        -- SQL (via pg_format or sql-formatter if available)
        sql = { "sql_formatter" },

        -- Catch-all: try prettier for unknown types
        ["_"] = { "trim_whitespace" },
      },

      format_on_save = function(bufnr)
        -- Disable format-on-save for large files
        if vim.b[bufnr].large_file then
          return
        end
        -- Disable for specific buffers
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return {
          timeout_ms = 3000,
          lsp_fallback = true,
        }
      end,

      formatters = {
        biome = {
          -- Biome is a Rust-based formatter/linter, much faster than prettier
          -- Only runs if biome.json exists in the project root
          require_cwd = true,
          condition = function(_, ctx)
            return vim.fs.find(
              { "biome.json", "biome.jsonc" },
              { upward = true, path = ctx.dirname }
            )[1] ~= nil
          end,
        },
        prettier = {
          require_cwd = false,
          -- Use project-local prettier if available
          condition = function(_, ctx)
            -- Run prettier if there's a config file or if biome isn't available
            return true
          end,
        },
        shfmt = {
          prepend_args = { "-i", "2", "-ci" },  -- 2-space indent, consistent indent
        },
        stylua = {
          prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" },
        },
        black = {
          prepend_args = { "--line-length", "88" },
        },
        sql_formatter = {
          command = "sql-formatter",
          args = { "--language", "postgresql" },
        },
      },
    },
    config = function(_, opts)
      require("conform").setup(opts)

      -- Toggle format on save
      vim.api.nvim_create_user_command("FormatToggle", function(args)
        local is_global = not args.bang
        if is_global then
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify(
            "Format on save " .. (vim.g.disable_autoformat and "disabled" or "enabled") .. " (global)",
            vim.log.levels.INFO
          )
        else
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          vim.notify(
            "Format on save " .. (vim.b.disable_autoformat and "disabled" or "enabled") .. " (buffer)",
            vim.log.levels.INFO
          )
        end
      end, { bang = true, desc = "Toggle autoformat-on-save" })
    end,
  },
}
