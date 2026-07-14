-- =============================================================================
-- init.lua — LazyVim bootstrap
-- =============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Set leader before lazy loads plugins
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Load LazyVim with our config
require("lazy").setup({
  spec = {
    -- LazyVim core — provides defaults for everything
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- LazyVim extras — cherry-pick what we need
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.linting.eslint" },
    { import = "lazyvim.plugins.extras.formatting.prettier" },
    { import = "lazyvim.plugins.extras.editor.fzf" },       -- fzf-lua instead of telescope
    { import = "lazyvim.plugins.extras.coding.blink" },     -- blink.cmp instead of nvim-cmp

    -- Our custom plugins and overrides
    { import = "plugins" },
  },
  defaults = {
    lazy = true,       -- every plugin is lazy-loaded by default
    version = false,   -- use latest git commit, not pinned tags
  },
  install = {
    colorscheme = { "tokyonight", "habamax" },
  },
  checker = {
    enabled = true,
    notify = false,  -- don't popup on every check; use :Lazy to see updates
    frequency = 604800,  -- check once per week (was daily; fewer background git fetches)
  },
  performance = {
    cache = { enabled = true },
    reset_packpath = true,
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  ui = {
    border = "rounded",
    backdrop = 60,
  },
})
