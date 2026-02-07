local wezterm = require("wezterm")
local config = {}

-- import modules
local colors = require("colors")
local fonts = require("fonts")
local window = require("window")
local keybindings = require("keybindings")

config.wsl_domains = {
	{
		name = "WSL:Ubuntu",
		distribution = "Ubuntu",
	},
}


if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Default to the local Windows domain (PowerShell), rather than WSL
config.default_domain = "local"
config.default_prog = { "pwsh-preview.exe" }

-- performance settings
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- merge configurations
for k, v in pairs(colors) do
	config[k] = v
end
for k, v in pairs(fonts) do
	config[k] = v
end
for k, v in pairs(window) do
	config[k] = v
end
for k, v in pairs(keybindings) do
	config[k] = v
end

return config
