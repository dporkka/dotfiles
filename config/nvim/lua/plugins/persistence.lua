-- =============================================================================
-- persistence.lua — auto-restore the cwd's session on startup
-- Bridges tmux-resurrect so a reboot brings the editor back, not just the panes.
-- =============================================================================
-- WHY: tmux continuum/resurrect restores each pane's cwd and relaunches a bare
-- `nvim`, but resurrect's `@resurrect-strategy-nvim 'session'` only looks for
-- ./Session.vim — which LazyVim/persistence never writes (sessions live in
-- ~/.local/state/nvim/sessions/). LazyVim ships persistence.nvim but leaves
-- restore manual (<leader>qs). This auto-loads the session when nvim starts
-- with no file argument, so a tmux restore reopens buffers/layout hands-off.
--
-- WHY HERE (and not config/autocmds.lua): when nvim opens with no args, LazyVim
-- defers config/autocmds.lua to the VeryLazy event, which fires AFTER VimEnter —
-- so a VimEnter autocmd registered there never runs. A plugin spec `init`
-- function runs during startup, before VimEnter, so the autocmd fires correctly.

return {
  "folke/persistence.nvim",
  lazy = false, -- load eagerly so require("persistence") is ready at VimEnter
  init = function()
    local group = vim.api.nvim_create_augroup("persistence_autoload", { clear = true })

    -- Skip auto-load when content is piped in (e.g. `cmd | nvim -`)
    vim.api.nvim_create_autocmd("StdinReadPre", {
      group = group,
      callback = function()
        vim.g.started_with_stdin = true
      end,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      nested = true, -- let the session fire its own BufRead/FileType autocmds
      callback = function()
        if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
          -- Defer past the dashboard's VimEnter handler, which would otherwise
          -- win the race and leave the session unrestored.
          vim.schedule(function()
            -- Skip session restore in huge repos to avoid loading 50+ buffers.
            -- Limit comes from the host profile tunables
            -- (dotfiles/scripts/host-profile.sh), then env, then 20.
            local max_buffers = tonumber(vim.env.NVIM_PERSISTENCE_MAX_BUFFERS) or 20
            local ok, tunables = pcall(dofile, vim.fn.expand("~/.local/state/nvim/tunables.lua"))
            if ok and type(tunables) == "table" and type(tunables.persistence_max_buffers) == "number" then
              max_buffers = tunables.persistence_max_buffers
            end
            local buf_count = #vim.fn.getbufinfo({ buflisted = true })
            if buf_count <= max_buffers then
              require("persistence").load()
            end
          end)
        end
      end,
    })
  end,
}
