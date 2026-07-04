-- =============================================================================
-- navigation.lua — file and project navigation
-- =============================================================================

return {
  -- ---------------------------------------------------------------------------
  -- OIL.NVIM — file browser that edits the filesystem like a buffer
  -- WHY oil over NerdTree/neo-tree: oil is modal, fast, and you edit files
  -- the same way you edit text. Rename files with 'cw'. Delete with 'dd'.
  -- Works great in tmux pane splits.
  -- ---------------------------------------------------------------------------
  {
    "stevearc/oil.nvim",
    lazy = false,  -- load on startup for -e "oil" support
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (Oil)" },
      { "<leader>e", "<cmd>Oil<cr>", desc = "File browser" },
      { "<leader>E", "<cmd>Oil --float<cr>", desc = "File browser (float)" },
    },
    opts = {
      default_file_explorer = true,
      columns = {
        "icon",
        "permissions",
        "size",
        "mtime",
      },
      win_options = {
        wrap = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
      delete_to_trash = false,
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
        is_hidden_file = function(name, _)
          return vim.startswith(name, ".")
        end,
        is_always_hidden = function(name, _)
          return name == ".." or name == ".git"
        end,
      },
      float = {
        padding = 2,
        max_width = 90,
        max_height = 30,
        border = "rounded",
      },
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-s>"] = "actions.select_split",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<BS>"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
        ["gy"] = {
          desc = "Yank relative path",
          callback = function()
            require("oil.actions").yank_entry.callback({ modify = ":." })
          end,
        },
        ["gY"] = {
          desc = "Yank absolute path",
          callback = function()
            require("oil.actions").yank_entry.callback()
          end,
        },
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- FZF-LUA — fast fuzzy finding, replaces telescope for most tasks
  -- WHY fzf-lua over telescope: fzf is a C binary, significantly faster on
  -- large repos. LazyVim's fzf extra handles the integration.
  -- ---------------------------------------------------------------------------
  {
    "ibhagwan/fzf-lua",
    lazy = true,
    cmd = "FzfLua",
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>/", "<cmd>FzfLua live_grep_glob<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>fg", "<cmd>FzfLua git_files<cr>", desc = "Git files" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
      { "<leader>fh", "<cmd>FzfLua help_tags<cr>", desc = "Help tags" },
      { "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Buffer diagnostics" },
      { "<leader>fD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace diagnostics" },
      { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document symbols" },
      { "<leader>fS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace symbols" },
      { "<leader>fc", "<cmd>FzfLua commands<cr>", desc = "Commands" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word under cursor" },
      { "<leader>fW", "<cmd>FzfLua grep_visual<cr>", mode = "v", desc = "Grep visual selection" },
      { "<leader>f;", "<cmd>FzfLua resume<cr>", desc = "Resume last picker" },
      { "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Fuzzy lines in buffer" },
      { "<leader>fq", "<cmd>FzfLua quickfix<cr>", desc = "Fuzzy quickfix" },
      { "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Git commits" },
      { "<leader>gb", "<cmd>FzfLua git_branches<cr>", desc = "Git branches" },
      { "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git status" },
      { "gr", "<cmd>FzfLua lsp_references<cr>", desc = "LSP references" },
      { "gd", "<cmd>FzfLua lsp_definitions<cr>", desc = "LSP definitions" },
      { "gi", "<cmd>FzfLua lsp_implementations<cr>", desc = "LSP implementations" },
      { "gt", "<cmd>FzfLua lsp_typedefs<cr>", desc = "LSP type definitions" },
    },
    opts = {
      winopts = {
        height = 0.85,
        width = 0.85,
        row = 0.35,
        col = 0.50,
        border = "rounded",
        preview = {
          border = "border",
          wrap = "nowrap",
          hidden = "nohidden",
          vertical = "down:45%",
          horizontal = "right:50%",
          layout = "flex",
          flip_columns = 120,
        },
      },
      fzf_opts = {
        ["--ansi"] = "",
        ["--info"] = "inline",
        ["--height"] = "100%",
        ["--layout"] = "reverse",
        ["--border"] = "none",
      },
      files = {
        fd_opts = "--type f --hidden --follow "
          .. "--exclude .git "
          .. "--exclude node_modules "
          .. "--exclude .next "
          .. "--exclude dist "
          .. "--exclude build "
          .. "--exclude target "
          .. "--exclude .venv --exclude venv "
          .. "--exclude __pycache__ "
          .. "--exclude .turbo --exclude .parcel-cache --exclude .cache "
          .. "--exclude coverage "
          .. "--exclude .nuxt --exclude .output "
          .. "--exclude '*.lock'",
      },
      grep = {
        rg_opts = "--hidden --follow --smart-case "
          .. "--glob '!.git' "
          .. "--glob '!node_modules' "
          .. "--glob '!.next' "
          .. "--glob '!dist' "
          .. "--glob '!build' "
          .. "--glob '!target' "
          .. "--glob '!.venv' --glob '!venv' "
          .. "--glob '!__pycache__' "
          .. "--glob '!.turbo' --glob '!.parcel-cache' --glob '!.cache' "
          .. "--glob '!coverage' "
          .. "--glob '!.nuxt' --glob '!.output' "
          .. "--glob '!*.lock'",
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- HARPOON — mark and quickly switch between frequent files
  -- WHY: in a monorepo you're constantly switching between a small set of files.
  -- Harpoon lets you mark them and jump with Alt+1-4 instantly.
  -- ---------------------------------------------------------------------------
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Harpoon: add file" },
      { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon: menu" },
      { "<M-1>", function() require("harpoon"):list():select(1) end, desc = "Harpoon 1" },
      { "<M-2>", function() require("harpoon"):list():select(2) end, desc = "Harpoon 2" },
      { "<M-3>", function() require("harpoon"):list():select(3) end, desc = "Harpoon 3" },
      { "<M-4>", function() require("harpoon"):list():select(4) end, desc = "Harpoon 4" },
    },
    opts = {
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
      },
    },
  },

  -- ---------------------------------------------------------------------------
  -- FLASH — fast motion / jump (replaces hop, leap, easymotion)
  -- WHY: navigate anywhere in the visible buffer in 2-3 keystrokes.
  -- ---------------------------------------------------------------------------
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        char = { enabled = false },  -- disable f/F/t/T enhancement (personal pref)
      },
    },
    keys = {
      { "s", function() require("flash").jump() end, mode = { "n", "x", "o" }, desc = "Flash jump" },
      { "S", function() require("flash").treesitter() end, mode = { "n", "x", "o" }, desc = "Flash treesitter" },
    },
  },

  -- ---------------------------------------------------------------------------
  -- NVIM-ROOTER replacement — LazyVim handles this via project detection
  -- rootdir is set automatically based on .git, package.json, etc.
  -- ---------------------------------------------------------------------------
}
