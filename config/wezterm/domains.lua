-- domains.lua -- Multiplexer domain definitions for the agent mesh.

local M = {}

function M.apply(config)
  -- The built-in "local" unix domain is used as the default landing zone.
  -- (We intentionally do not redefine it; "local" is reserved by WezTerm.)

  -- Remote mux servers are reached over Tailscale.
  -- Prefer MagicDNS names; hardcoded IPs are fallbacks if DNS isn't configured.
  -- Set TAILSCALE_TAILNET to your tailnet name (e.g. "example.ts.net") to use DNS.
  local tailnet = os.getenv("TAILSCALE_TAILNET")
  local function host(name, ip)
    if tailnet and tailnet ~= "" then
      return name .. "." .. tailnet
    end
    return ip
  end
  config.ssh_domains = {
    { name = "wsl2",        remote_address = host("wsl2",        "100.64.0.2") },
    { name = "mini-pc",     remote_address = host("mini-pc",     "100.64.0.3") },
    { name = "contabo-vps", remote_address = host("contabo-vps", "100.64.0.10") },
  }

  -- Start the GUI connected to the local mux domain so tabs/windows survive crashes.
  config.default_gui_startup_args = { "connect", "local" }
  config.mux_enable_ssh_agent = false
end

return M
