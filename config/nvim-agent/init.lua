-- =============================================================================
-- nvim-agent — lean, plugin-free Neovim profile for agent tmux panes
-- Usage: NVIM_APPNAME=nvim-agent nvim .
-- =============================================================================

local opt = vim.opt

-- ---------------------------------------------------------------------------
-- PERFORMANCE
-- ---------------------------------------------------------------------------

opt.updatetime = 400      -- faster CursorHold events
opt.synmaxcol = 200       -- don't syntax highlight past column 200

-- ---------------------------------------------------------------------------
-- DISPLAY
-- ---------------------------------------------------------------------------

opt.number = true
opt.relativenumber = true   -- hybrid line numbers
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.laststatus = 3          -- single global statusline
opt.statusline = " %f %m%r%h%w %=%l:%c %y "
opt.splitbelow = true
opt.splitright = true

-- ---------------------------------------------------------------------------
-- EDITOR BEHAVIOR
-- ---------------------------------------------------------------------------

opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.smartindent = true
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.undofile = true
opt.swapfile = false

-- ---------------------------------------------------------------------------
-- SEARCH
-- ---------------------------------------------------------------------------

opt.ignorecase = true
opt.smartcase = true

-- ---------------------------------------------------------------------------
-- KEYMAPS — leader = space, obvious basics only
-- ---------------------------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File browser (netrw)" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- netrw: keep it simple
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
