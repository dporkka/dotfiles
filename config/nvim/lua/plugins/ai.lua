-- =============================================================================
-- ai.lua — avante.nvim: Cursor-style AI editing inside Neovim
-- Side-by-side diffs, inline chat, inline refactoring, agentic code generation
-- Requires: ANTHROPIC_API_KEY in environment
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- SUPERMAVEN — inline ghost-text AI completions (free, sub-100ms latency)
  -- Tab accepts the full suggestion; C-j accepts one word; C-] dismisses.
  -- Only active in insert mode — does not touch blink.cmp's dropdown at all.
  -- ---------------------------------------------------------------------------
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    opts = {
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion  = "<C-]>",
        accept_word       = "<C-j>",
      },
      ignore_filetypes = { "TelescopePrompt", "ministarter", "alpha", "lazy", "mason" },
      color = {
        suggestion_color = "#6272a4",
        cterm = 244,
      },
      log_level = "off",
      disable_inline_completion = false,
      disable_keymaps = false,
    },
  },

  -- ---------------------------------------------------------------------------
  -- RENDER-MARKDOWN — extend to Avante filetype (LazyVim already installs this
  -- via lazyvim.plugins.extras.lang.markdown; we just add Avante to ft list)
  -- ---------------------------------------------------------------------------
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = function(_, opts)
      opts.file_types = opts.file_types or { "markdown" }
      vim.list_extend(opts.file_types, { "Avante" })
    end,
    ft = function(_, ft)
      vim.list_extend(ft, { "Avante" })
    end,
  },

  -- ---------------------------------------------------------------------------
  -- IMG-CLIP — paste images into Avante chat (e.g. screenshots of errors/UI)
  -- ---------------------------------------------------------------------------
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      default = {
        embed_image_as_base64 = false,
        prompt_for_file_name = false,
        drag_and_drop = { insert_mode = true },
        use_absolute_path = true,
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- AVANTE.NVIM — AI-driven editing: inline chat, side-by-side diff, refactor
  --
  -- Core workflow:
  --   <leader>aa  ask   → open sidebar, describe what you want
  --   <leader>ae  edit  → visual-select code, ask AI to transform it in-place
  --   <leader>at  toggle→ show/hide sidebar without losing context
  --
  -- Model picker (Cursor-style — switch the active model mid-session):
  --   <leader>ac  use Sonnet 4.6 (fast default)
  --   <leader>ao  use Opus 4.8   (hard reasoning / large refactors)
  --
  -- Context (Cursor-style @ mentions, powered by fzf-lua):
  --   @           add a file to context (in sidebar input)
  --   <leader>aM  toggle the repomap (whole-codebase awareness for the agent)
  --
  -- After generation:
  --   co / ct  accept ours / theirs in diff conflicts
  --   ]x / [x  jump between diff hunks
  --   a        apply suggestion under cursor (in sidebar)
  --   A        apply all suggestions
  -- ---------------------------------------------------------------------------
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    keys = {
      { "<leader>ao", function() require("avante.api").switch_provider("opus") end,   desc = "Avante: use Opus (hard tasks)" },
      { "<leader>ac", function() require("avante.api").switch_provider("claude") end, desc = "Avante: use Sonnet (default)" },
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "ibhagwan/fzf-lua",                 -- backs the @-file / @-symbol selector
      "HakonHarnes/img-clip.nvim",
      "MeanderingProgrammer/render-markdown.nvim",
    },
    opts = {
      -- agentic mode: avante can read files, search, and apply changes via tools
      -- legacy mode: older single-shot plan-and-apply approach
      mode = "agentic",

      provider = "claude",

      -- fzf-lua powers the @-file / @-symbol picker (Cursor-style @ mentions)
      selector = {
        provider = "fzf_lua",
        provider_opts = {},
      },

      providers = {
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-sonnet-4-6",      -- fast everyday default
          timeout = 30000,
          extra_request_body = {
            temperature = 0,
            max_tokens = 32000,             -- headroom for large multi-file edits
          },
        },
        -- Opus for hard reasoning / big refactors — switch with <leader>ao.
        -- Inherits endpoint + API key from `claude`; only the model changes.
        opus = {
          __inherited_from = "claude",
          model = "claude-opus-4-8",
          extra_request_body = {
            temperature = 0,
            max_tokens = 32000,
          },
        },
      },

      -- Optional — Cursor's @web. Uncomment and `export TAVILY_API_KEY=...` to
      -- let the agent fetch current docs/answers while working.
      -- web_search_engine = { provider = "tavily" },

      behaviour = {
        auto_suggestions = false,         -- don't suggest on every keystroke; use <leader>ae
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,  -- always review diff before applying
        auto_approve_tool_permissions = true,       -- no permission prompts in agentic mode
        support_paste_from_clipboard = true,
        minimize_diff = true,
        enable_token_counting = true,               -- show token usage per request
      },

      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        focus = "<leader>af",

        toggle = {
          default = "<leader>at",
          debug = "<leader>aD",
          hint = "<leader>ah",
          suggestion = "<leader>aS",
          repomap = "<leader>aM",
        },

        diff = {
          ours = "co",
          theirs = "ct",
          all_theirs = "ca",
          both = "cb",
          cursor = "cc",
          next = "]x",
          prev = "[x",
        },

        submit = {
          normal = "<CR>",
          insert = "<C-s>",  -- C-s submit in avante buffer; doesn't clash with global C-s save
        },

        cancel = {
          normal = "<C-c>",
          insert = "<C-c>",
        },

        sidebar = {
          apply_all = "A",
          apply_cursor = "a",
          retry_user_request = "r",
          edit_user_request = "e",
          switch_windows = "<Tab>",
          reverse_switch_windows = "<S-Tab>",
          remove_file = "d",
          add_file = "@",
          close = { "<Esc>", "q" },
        },
      },

      hints = { enabled = false },

      windows = {
        position = "right",
        wrap = true,
        width = 38,   -- chars, not %; gives a comfortable reading width
        sidebar_header = {
          enabled = true,
          align = "center",
          rounded = true,
        },
        input = {
          prefix = "> ",
          height = 8,
        },
        edit = {
          border = "rounded",
          start_insert = true,
        },
        ask = {
          floating = false,   -- sidebar mode, not floating popup
          start_insert = true,
          border = "rounded",
          focus_on_apply = "ours",
        },
      },

      highlights = {
        diff = {
          current = "DiffText",
          incoming = "DiffAdd",
        },
      },

      diff = {
        autojump = true,
        list_opener = "copen",
        -- prevents `c` in diff hunks from triggering operator-pending mode
        override_timeoutlen = 500,
      },
    },
  },
}
