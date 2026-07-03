-- =============================================================================
-- options.lua — Neovim options tuned for WSL2 + large TS monorepos
-- =============================================================================

local opt = vim.opt

-- ---------------------------------------------------------------------------
-- PERFORMANCE
-- ---------------------------------------------------------------------------

opt.updatetime = 400      -- faster CursorHold events (default 4000ms is way too slow)
opt.timeoutlen = 300      -- faster which-key popup; shorter leader key timeout
opt.redrawtime = 1000     -- abort syntax highlight if it takes too long
opt.lazyredraw = false    -- don't use lazyredraw (breaks some plugins; true speeds up macros)
opt.synmaxcol = 200       -- don't syntax highlight past column 300 (perf on long lines)
opt.maxmempattern = 2000  -- limit regex memory

-- ---------------------------------------------------------------------------
-- DISPLAY
-- ---------------------------------------------------------------------------

opt.number = true
opt.relativenumber = true   -- hybrid line numbers: current=absolute, others=relative
opt.signcolumn = "yes"      -- always show; prevents layout shift when diagnostics appear
opt.cursorline = true
opt.scrolloff = 8           -- keep 8 lines above/below cursor when scrolling
opt.sidescrolloff = 8
opt.wrap = false            -- no line wrap (horizontal scroll instead)
opt.linebreak = true        -- if wrap=true, break at word boundaries
opt.showmode = false        -- mode shown in statusline, not command area
opt.ruler = false           -- shown in statusline
opt.cmdheight = 0           -- hide command line when not in use (Neovim 0.8+)
opt.laststatus = 3          -- single global statusline
opt.splitbelow = true       -- new horizontal splits open below
opt.splitright = true       -- new vertical splits open right
opt.termguicolors = true    -- true color support

-- ---------------------------------------------------------------------------
-- EDITOR BEHAVIOR
-- ---------------------------------------------------------------------------

opt.expandtab = true        -- spaces not tabs
opt.tabstop = 2             -- visual width of tab character
opt.shiftwidth = 2          -- indent size
opt.softtabstop = 2
opt.smartindent = true      -- auto-indent after {, etc.
opt.shiftround = true       -- round indent to shiftwidth multiple

opt.clipboard = "unnamedplus"
-- WHY unnamedplus: syncs unnamed register with system clipboard.
-- On WSL2 with wl-clipboard or win32yank, this enables seamless copy/paste
-- between Neovim and Windows applications.

opt.mouse = "a"             -- mouse support in all modes

opt.undofile = true         -- persistent undo across sessions
opt.undolevels = 10000
opt.backup = false
opt.writebackup = false
opt.swapfile = false        -- no swap files; use persistent undo instead

-- ---------------------------------------------------------------------------
-- SEARCH
-- ---------------------------------------------------------------------------

opt.ignorecase = true       -- case-insensitive search
opt.smartcase = true        -- case-sensitive when uppercase present
opt.incsearch = true        -- show matches while typing
opt.hlsearch = true         -- highlight all matches
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"
-- WHY rg: ripgrep is 10-100x faster than grep on large monorepos.

-- ---------------------------------------------------------------------------
-- FILES
-- ---------------------------------------------------------------------------

opt.fileencoding = "utf-8"
opt.bomb = false
opt.fixeol = true

-- WSL2: ensure LF line endings (never CRLF)
opt.fileformat = "unix"
opt.fileformats = "unix,dos"

-- ---------------------------------------------------------------------------
-- COMPLETION
-- ---------------------------------------------------------------------------

opt.completeopt = "menu,menuone,noselect"
opt.pumheight = 15          -- max items in completion popup
opt.pumblend = 10           -- popup transparency

-- ---------------------------------------------------------------------------
-- FOLDS — use Treesitter-based folding
-- ---------------------------------------------------------------------------

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99          -- start fully unfolded
opt.foldlevelstart = 99
opt.foldenable = false

-- ---------------------------------------------------------------------------
-- WHITESPACE DISPLAY
-- ---------------------------------------------------------------------------

opt.list = true
opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
  extends = "»",
  precedes = "«",
}

-- ---------------------------------------------------------------------------
-- WINDOW TITLES
-- ---------------------------------------------------------------------------

opt.title = true
opt.titlestring = "%t — nvim"

-- ---------------------------------------------------------------------------
-- DIFF
-- ---------------------------------------------------------------------------

opt.diffopt = "internal,filler,closeoff,algorithm:histogram,linematch:60"
-- histogram: better diff algorithm; linematch: aligns changed lines

-- ---------------------------------------------------------------------------
-- GREP / QUICKFIX
-- ---------------------------------------------------------------------------

opt.shortmess:append({ W = true, I = true, c = true, C = true })
opt.formatoptions:append({ r = true, o = false })

-- ---------------------------------------------------------------------------
-- WSL2 CLIPBOARD — win32yank integration
-- ---------------------------------------------------------------------------

-- win32yank.exe is the fastest clipboard bridge for WSL2 Neovim.
-- Install: curl -sLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
--          unzip /tmp/win32yank.zip -d ~/.local/bin && chmod +x ~/.local/bin/win32yank.exe
if vim.fn.has("wsl") == 1 then
  if vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
      name = "win32yank",
      copy = {
        ["+"] = "win32yank.exe -i --crlf",
        ["*"] = "win32yank.exe -i --crlf",
      },
      paste = {
        ["+"] = "win32yank.exe -o --lf",
        ["*"] = "win32yank.exe -o --lf",
      },
      cache_enabled = 0,
    }
  end
end
