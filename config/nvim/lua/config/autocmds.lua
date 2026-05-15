-- =============================================================================
-- autocmds.lua — autocommands for workflow automation
-- =============================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ---------------------------------------------------------------------------
-- HIGHLIGHT ON YANK
-- ---------------------------------------------------------------------------

autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- ---------------------------------------------------------------------------
-- RESTORE CURSOR POSITION
-- ---------------------------------------------------------------------------

autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then return end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ---------------------------------------------------------------------------
-- CLOSE UTILITY WINDOWS WITH q
-- ---------------------------------------------------------------------------

autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = {
    "help", "lspinfo", "man", "notify", "qf",
    "query", "startuptime", "checkhealth", "fugitive",
    "git", "neotest-summary", "spectre_panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- ---------------------------------------------------------------------------
-- AUTO-CREATE PARENT DIRECTORIES ON SAVE
-- ---------------------------------------------------------------------------

autocmd("BufWritePre", {
  group = augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+://") then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- ---------------------------------------------------------------------------
-- LARGE FILE OPTIMIZATION
-- ---------------------------------------------------------------------------
-- WHY: Large files (>1MB) in monorepos can make Neovim crawl.
-- Disable expensive features for them.

local large_file_group = augroup("large_file", { clear = true })

autocmd("BufReadPre", {
  group = large_file_group,
  callback = function(event)
    local file = event.match
    local ok, stat = pcall(vim.uv.fs_stat, file)
    if ok and stat and stat.size > 1024 * 1024 then  -- 1MB
      vim.b.large_file = true
      vim.opt_local.syntax = "off"
      vim.opt_local.spell = false
      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
      vim.opt_local.foldmethod = "manual"
      vim.notify("Large file: some features disabled", vim.log.levels.WARN)
    end
  end,
})

-- ---------------------------------------------------------------------------
-- FILETYPE OVERRIDES
-- ---------------------------------------------------------------------------

autocmd("FileType", {
  group = augroup("filetype_settings", { clear = true }),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.textwidth = 80
  end,
})

autocmd("FileType", {
  group = augroup("ts_settings", { clear = true }),
  pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  callback = function()
    -- Use project-local formatters (biome, prettier) over global
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

-- ---------------------------------------------------------------------------
-- TERMINAL: no line numbers, no signcolumn
-- ---------------------------------------------------------------------------

autocmd("TermOpen", {
  group = augroup("terminal_settings", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.scrolloff = 0
    vim.cmd.startinsert()
  end,
})

-- ---------------------------------------------------------------------------
-- TRIM TRAILING WHITESPACE (not for markdown)
-- ---------------------------------------------------------------------------

autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = { "*.lua", "*.ts", "*.tsx", "*.js", "*.jsx", "*.py", "*.sh" },
  callback = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, cursor)
  end,
})

-- ---------------------------------------------------------------------------
-- RESIZE SPLITS ON WINDOW RESIZE
-- ---------------------------------------------------------------------------

autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- ---------------------------------------------------------------------------
-- FOCUS EVENTS — important for Neovim inside tmux
-- ---------------------------------------------------------------------------

-- Reload file when it changes on disk (e.g., after git checkout, aider edits)
autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = augroup("auto_reload", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})
