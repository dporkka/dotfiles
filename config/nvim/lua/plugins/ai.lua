-- =============================================================================
-- ai.lua — avante.nvim: Cursor-style AI editing inside Neovim
-- Side-by-side diffs, inline chat, inline refactoring, agentic code generation
-- Requires: ANTHROPIC_API_KEY in environment
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- SUPERMAVEN — inline ghost-text AI completions (free, sub-100ms latency).
  -- Tab acceptance is routed through blink.cmp's <Tab> (see the blink spec below)
  -- so supermaven and the completion menu never fight over the key. The old
  -- collision was that BOTH plugins bound <Tab> in insert mode (last-loaded won,
  -- nondeterministically). supermaven's own keymaps are disabled here; we keep
  -- <C-j> (accept word) and <C-]> (dismiss).
  -- ---------------------------------------------------------------------------
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    opts = {
      ignore_filetypes = { "TelescopePrompt", "ministarter", "alpha", "lazy", "mason" },
      color = {
        suggestion_color = "#6272a4",
        cterm = 244,
      },
      log_level = "off",
      disable_inline_completion = false,  -- keep the ghost text
      disable_keymaps = true,             -- but not its keymaps; blink owns <Tab>
    },
    config = function(_, opts)
      require("supermaven-nvim").setup(opts)
      local preview = require("supermaven-nvim.completion_preview")
      vim.keymap.set("i", "<C-j>", function() preview.on_accept_suggestion_word() end,
        { desc = "Supermaven: accept word" })
      vim.keymap.set("i", "<C-]>", function() preview.on_dispose_inlay() end,
        { desc = "Supermaven: dismiss suggestion" })
    end,
  },

  -- ---------------------------------------------------------------------------
  -- BLINK.CMP — smart <Tab>: accept a Supermaven ghost suggestion if one is
  -- showing, else jump a snippet field, else fall through. This is the SINGLE
  -- owner of <Tab> in insert mode (resolves the supermaven/blink collision).
  -- Menu items are still accepted with <CR> (LazyVim's "enter" preset) and
  -- navigated with <C-n>/<C-p>, so Tab stays a pure "accept AI / next field" key.
  -- ---------------------------------------------------------------------------
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<Tab>"] = {
          function()
            local ok, preview = pcall(require, "supermaven-nvim.completion_preview")
            if ok and preview.has_suggestion() then
              preview.on_accept_suggestion()
              return true
            end
          end,
          "snippet_forward",
          "fallback",
        },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
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

      -- MCPHUB: inject live MCP server tools + prompt into avante (see plugins/mcp.lua).
      -- Both are functions (not values) so the server state is always fresh and mcphub
      -- isn't required before it's loaded; pcall keeps avante working if mcphub is absent.
      system_prompt = function()
        local ok, hub = pcall(function() return require("mcphub").get_hub_instance() end)
        return (ok and hub) and hub:get_active_servers_prompt() or ""
      end,
      custom_tools = function()
        local ok, ext = pcall(require, "mcphub.extensions.avante")
        return ok and { ext.mcp_tool() } or {}
      end,

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

      -- Cursor's @web — the agent fetches current docs/answers while working.
      -- Needs `export TAVILY_API_KEY=...` in your shell (stub in ~/.zshrc). If the
      -- key is unset, avante just skips web search; it doesn't error.
      web_search_engine = { provider = "tavily" },

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
        width = 50,   -- chars, not %; wide enough to read multi-file diffs comfortably
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

  -- ---------------------------------------------------------------------------
  -- CLAUDECODE.NVIM — deep Claude Code <-> Neovim bridge (WebSocket/MCP).
  -- This wires the terminal Claude Code you already drive into the editor: the
  -- Cursor loop on the agent you actually use. Visual-select code and send it as
  -- context; Claude's edits come back as NATIVE Neovim diffs you accept/reject in
  -- place (no alt-tabbing to a separate diff view). Complements avante: avante is
  -- the API-billed inline assistant, claudecode is your subscription agent.
  --
  -- Namespaced under <leader>k ("Klaude") because avante owns <leader>a and
  -- LazyVim owns <leader>c. Core flow:
  --   <leader>kk  toggle Claude          <leader>ks  send selection (visual mode)
  --   <leader>kf  focus Claude window    <leader>kb  add current buffer as context
  --   <leader>kr  resume last session    <leader>ka / <leader>kd  accept / deny diff
  --   <leader>km  switch model           <leader>ks  (in Oil) add file under cursor
  -- Inside a proposed-diff buffer, :w also accepts and :q rejects.
  --
  -- Requires the `claude` CLI on PATH (you have it) and snacks.nvim (LazyVim core).
  -- ---------------------------------------------------------------------------
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSelectModel",
      "ClaudeCodeAdd", "ClaudeCodeSend", "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus", "ClaudeCodeStart", "ClaudeCodeStop",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeCloseAllDiffs",
    },
    opts = {
      -- track_selection (default on): Claude always sees your current visual
      -- selection / cursor position, Cursor-style. Defaults are sensible; the
      -- empty table just triggers require("claudecode").setup().
    },
    keys = {
      { "<leader>k", nil, desc = "Claude Code" },
      { "<leader>kk", "<cmd>ClaudeCode<cr>",            desc = "Toggle Claude" },
      { "<leader>kf", "<cmd>ClaudeCodeFocus<cr>",       desc = "Focus Claude" },
      { "<leader>kr", "<cmd>ClaudeCode --resume<cr>",   desc = "Resume Claude" },
      { "<leader>kC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>km", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select model" },
      { "<leader>kb", "<cmd>ClaudeCodeAdd %<cr>",       desc = "Add current buffer" },
      { "<leader>ks", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      {
        "<leader>ks",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        ft = { "oil", "neo-tree", "NvimTree", "minifiles", "netrw" },
        desc = "Add file to Claude",
      },
      { "<leader>ka", "<cmd>ClaudeCodeDiffAccept<cr>",  desc = "Accept diff" },
      { "<leader>kd", "<cmd>ClaudeCodeDiffDeny<cr>",    desc = "Deny diff" },
    },
  },
}
