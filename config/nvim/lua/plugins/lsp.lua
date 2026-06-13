-- =============================================================================
-- lsp.lua — LSP configuration for the full TS/Next.js/Fastify/Python stack
-- =============================================================================

return {
  -- Mason: install LSP servers, linters, formatters
  {
    "williamboman/mason.nvim",
    opts = {
      ui = { border = "rounded" },
      -- Installed tools beyond what LazyVim manages
      ensure_installed = {
        -- Formatters
        "prettier",
        "prettierd",
        "biome",
        "stylua",
        "black",
        "isort",
        "shfmt",

        -- Linters
        "eslint_d",
        "shellcheck",

        -- Debug adapters
        "delve",            -- Go
        "codelldb",         -- C/Rust
        "js-debug-adapter", -- TypeScript/JavaScript/Node/Next.js
        "debugpy",          -- Python
      },
    },
  },

  -- LSP server configuration
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Global diagnostic config
      diagnostics = {
        underline = true,
        update_in_insert = false,  -- don't show diagnostics while typing
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
        },
      },
      inlay_hints = {
        enabled = false,  -- disabled to reduce LSP CPU/RAM churn
      },
      codelens = {
        enabled = false,  -- can be noisy; enable per-project
      },
      servers = {
        -- TypeScript / JavaScript — use vtsls (faster than typescript-tools)
        vtsls = {
          settings = {
            typescript = {
              inlayHints = {
                parameterNames = { enabled = "literals" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = false },  -- too noisy
                propertyDeclarationTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                enumMemberValues = { enabled = true },
              },
              suggest = {
                completeFunctionCalls = true,
              },
              preferences = {
                importModuleSpecifier = "non-relative",
                -- WHY non-relative: in monorepos with path aliases, absolute
                -- imports are more stable and readable.
              },
            },
            javascript = {
              inlayHints = {
                parameterNames = { enabled = "literals" },
              },
            },
            vtsls = {
              enableMoveToFileCodeAction = true,
              autoUseWorkspaceTsdk = true,
              -- WHY autoUseWorkspaceTsdk: use the project's own TypeScript
              -- version, not the global one. Critical in monorepos.
              experimental = {
                completion = {
                  enableServerSideFuzzyMatch = true,
                },
              },
            },
          },
          -- On large monorepos, vtsls can be slow to start. This is normal.
          -- To check status: :LspInfo
        },

        -- JSON with schema support (package.json, tsconfig.json, etc.)
        jsonls = {
          on_new_config = function(new_config)
            new_config.settings.json.schemas = new_config.settings.json.schemas or {}
            vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
          end,
          settings = {
            json = {
              validate = { enable = true },
            },
          },
        },

        -- YAML with schema support
        yamlls = {
          settings = {
            yaml = {
              schemaStore = { enable = false, url = "" },
              schemas = require("schemastore").yaml.schemas(),
              validate = true,
              format = { enable = true },
            },
          },
        },

        -- Lua (for Neovim config editing)
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              codeLens = { enable = true },
              completion = { callSnippet = "Replace" },
              doc = { privateName = { "^_" } },
              hint = {
                enable = true,
                setType = false,
                paramType = true,
                paramName = "Disable",
                semicolon = "Disable",
                arrayIndex = "Disable",
              },
            },
          },
        },

        -- Python
        pyright = {
          settings = {
            pyright = {
              disableOrganizeImports = true,  -- let isort handle it
            },
            python = {
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
                typeCheckingMode = "basic",
              },
            },
          },
        },

        -- Bash
        bashls = {},

        -- Docker
        dockerls = {},
        docker_compose_language_service = {},

        -- Tailwind CSS
        tailwindcss = {
          settings = {
            tailwindCSS = {
              experimental = {
                classRegex = {
                  { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
                  { "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
                  { "cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
                },
              },
            },
          },
        },

        -- Prisma
        prismals = {},

        -- TOML
        taplo = {},

        -- CSS
        cssls = {},

        -- HTML (minimal, mainly for template files)
        html = {},

        -- SQL (optional, needs setup)
        -- sqls = {},
      },
    },
  },

  -- SchemaStore for JSON/YAML schemas
  {
    "b0o/SchemaStore.nvim",
    lazy = true,
    version = false,
  },
}
