-- =============================================================================
-- keymaps.lua — purposeful bindings only; no redundant remaps
-- =============================================================================

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ---------------------------------------------------------------------------
-- NAVIGATION
-- ---------------------------------------------------------------------------

-- Better half-page jump (centers cursor)
map("n", "<C-d>", "<C-d>zz", opts)
map("n", "<C-u>", "<C-u>zz", opts)

-- Keep search matches centered
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)

-- Ctrl+hjkl window navigation is owned by vim-tmux-navigator (plugins/terminal.lua).
-- It moves between Neovim splits and, at a split edge, hands off to the adjacent
-- tmux pane. Do NOT remap <C-hjkl> here or you'll re-break the seamless handoff.

-- Navigate quickfix list
map("n", "[q", "<cmd>cprev<cr>zz", { desc = "Prev quickfix" })
map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix" })
map("n", "[Q", "<cmd>cfirst<cr>zz", { desc = "First quickfix" })
map("n", "]Q", "<cmd>clast<cr>zz", { desc = "Last quickfix" })

-- ---------------------------------------------------------------------------
-- EDITING
-- ---------------------------------------------------------------------------

-- Move selected lines up/down in visual mode
map("v", "J", ":m '>+1<cr>gv=gv", opts)
map("v", "K", ":m '<-2<cr>gv=gv", opts)

-- Paste without losing register contents (paste over selection)
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Delete to black hole (don't pollute register)
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Copy to system clipboard explicitly
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Copy to clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Copy line to clipboard" })

-- Quick save
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
map("i", "<C-s>", "<Esc><cmd>w<cr>a", { desc = "Save" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", opts)

-- Join lines without moving cursor
map("n", "J", "mzJ`z", opts)

-- Don't move cursor on * (search current word without jumping)
map("n", "*", "*N", opts)

-- ---------------------------------------------------------------------------
-- BUFFERS
-- ---------------------------------------------------------------------------

map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>bD", "<cmd>%bdelete<cr>", { desc = "Delete all buffers" })
map("n", "<leader>bo", "<cmd>%bdelete|e#|bdelete#<cr>", { desc = "Delete other buffers" })

-- ---------------------------------------------------------------------------
-- FILES & NAVIGATION
-- ---------------------------------------------------------------------------

-- Oil: open file browser
map("n", "-", "<cmd>Oil<cr>", { desc = "Open file browser (Oil)" })
map("n", "<leader>e", "<cmd>Oil<cr>", { desc = "File browser" })

-- ---------------------------------------------------------------------------
-- QUICKFIX / LOCATION LIST
-- ---------------------------------------------------------------------------

map("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix list" })
map("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Location list" })

-- ---------------------------------------------------------------------------
-- DIAGNOSTICS
-- ---------------------------------------------------------------------------

map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- ---------------------------------------------------------------------------
-- GIT
-- ---------------------------------------------------------------------------

map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gw", "<cmd>FzfLua git_status<cr>", { desc = "Git status" })

-- ---------------------------------------------------------------------------
-- TERMINAL
-- ---------------------------------------------------------------------------

-- Exit terminal insert mode with Esc
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-h>", "<cmd>wincmd h<cr>", opts)
map("t", "<C-j>", "<cmd>wincmd j<cr>", opts)
map("t", "<C-k>", "<cmd>wincmd k<cr>", opts)
map("t", "<C-l>", "<cmd>wincmd l<cr>", opts)

-- ---------------------------------------------------------------------------
-- UTILITIES
-- ---------------------------------------------------------------------------

-- Source current file (for Lua config iteration)
map("n", "<leader>so", "<cmd>source %<cr>", { desc = "Source current file" })

-- Make current file executable
map("n", "<leader>cx", "<cmd>!chmod +x %<cr>", { desc = "Make executable" })

-- Open lazygit in a floating terminal (handled by lazygit.nvim plugin)

-- Format (handled by conform.nvim)
map({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file/selection" })

-- Substitute word under cursor across file
map("n", "<leader>rw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word" })

-- Toggle relative numbers
map("n", "<leader>ur", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle relative numbers" })

-- Resize windows with arrows
map("n", "<C-Up>", "<cmd>resize +2<cr>", opts)
map("n", "<C-Down>", "<cmd>resize -2<cr>", opts)
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", opts)
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", opts)
