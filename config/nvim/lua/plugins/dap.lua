-- =============================================================================
-- dap.lua — debugger: nvim-dap + UI + virtual text
-- Adapters: js-debug-adapter (TS/Node/Next.js), debugpy (Python)
-- Install adapters via Mason before first use.
-- =============================================================================

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      -- Run
      { "<F5>",        function() require("dap").continue() end,          desc = "Debug: continue" },
      { "<F10>",       function() require("dap").step_over() end,         desc = "Debug: step over" },
      { "<F11>",       function() require("dap").step_into() end,         desc = "Debug: step into" },
      { "<F12>",       function() require("dap").step_out() end,          desc = "Debug: step out" },

      -- Breakpoints
      { "<leader>db",  function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dB",  function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
      { "<leader>dl",  function() require("dap").run_last() end,          desc = "Run last" },
      { "<leader>dx",  function() require("dap").terminate() end,         desc = "Terminate" },

      -- UI
      { "<leader>du",  function() require("dapui").toggle() end,          desc = "DAP UI" },
      { "<leader>de",  function() require("dapui").eval() end, mode = { "n", "v" }, desc = "Eval expression" },

      -- REPL
      { "<leader>dr",  function() require("dap").repl.open() end,         desc = "Open REPL" },
    },

    config = function()
      local dap    = require("dap")
      local dapui  = require("dapui")

      -- ── Signs ──────────────────────────────────────────────────────────────
      vim.fn.sign_define("DapBreakpoint",         { text = "●", texthl = "DiagnosticError",   numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition",{ text = "◆", texthl = "DiagnosticWarn",    numhl = "" })
      vim.fn.sign_define("DapStopped",            { text = "▶", texthl = "DiagnosticOk",      numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint",    numhl = "" })

      -- ── UI layout ──────────────────────────────────────────────────────────
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.35 },
              { id = "breakpoints", size = 0.20 },
              { id = "stacks",      size = 0.25 },
              { id = "watches",     size = 0.20 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl",    size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 10,
            position = "bottom",
          },
        },
        floating = { border = "rounded", mappings = { close = { "q", "<Esc>" } } },
      })

      -- Auto-open/close UI when a debug session starts/ends
      dap.listeners.after.event_initialized["dapui_config"]  = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"]  = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]      = function() dapui.close() end

      -- ── Virtual text — shows variable values inline while stepping ──────────
      require("nvim-dap-virtual-text").setup({
        enabled                   = false,
        highlight_changed_variables = true,
        all_frames                = false,
        virt_text_pos             = "eol",
      })

      -- ── JavaScript / TypeScript / Node.js / Next.js ────────────────────────
      -- Requires: Mason install js-debug-adapter
      local js_debug = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"

      for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.adapters[ft] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args    = { js_debug, "${port}" },
          },
        }
        dap.configurations[ft] = {
          {
            type    = ft,
            request = "launch",
            name    = "Launch current file (Node)",
            program = "${file}",
            cwd     = "${workspaceFolder}",
            sourceMaps = true,
            console    = "integratedTerminal",
          },
          {
            type    = ft,
            request = "launch",
            name    = "Launch Next.js dev server",
            runtimeExecutable = "pnpm",
            runtimeArgs       = { "dev" },
            cwd               = "${workspaceFolder}",
            console           = "integratedTerminal",
            sourceMaps        = true,
          },
          {
            type    = ft,
            request = "attach",
            name    = "Attach (port 9229)",
            port    = 9229,
            cwd     = "${workspaceFolder}",
            sourceMaps = true,
          },
        }
      end

      -- ── Go ────────────────────────────────────────────────────────────────
      -- Requires: Mason install delve
      dap.adapters.go = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/packages/delve/dlv",
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }
      dap.configurations.go = {
        {
          type = "go",
          name = "Debug package",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}",
        },
        {
          type = "go",
          name = "Debug file",
          request = "launch",
          mode = "debug",
          program = "${file}",
        },
        {
          type = "go",
          name = "Debug test",
          request = "launch",
          mode = "test",
          program = "${file}",
        },
      }

      -- ── Rust ───────────────────────────────────────────────────────────────
      -- Requires: Mason install codelldb
      dap.adapters.rust = {
        type = "server",
        port = "${port}",
        host = "127.0.0.1",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb",
          args = { "--port", "${port}" },
        },
      }
      dap.configurations.rust = {
        {
          type = "rust",
          name = "Debug executable",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }

      -- ── Python ─────────────────────────────────────────────────────────────
      -- Requires: Mason install debugpy
      dap.adapters.python = function(cb, config)
        if config.request == "attach" then
          local port = (config.connect or config).port
          local host = (config.connect or config).host or "127.0.0.1"
          cb({ type = "server", port = port, host = host })
        else
          cb({
            type    = "executable",
            command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
            args    = { "-m", "debugpy.adapter" },
          })
        end
      end
      dap.configurations.python = {
        {
          type    = "python",
          request = "launch",
          name    = "Launch file",
          program = "${file}",
          pythonPath = function()
            local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_DEFAULT_ENV")
            if venv then return venv .. "/bin/python" end
            return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
          end,
        },
      }
    end,
  },
}
