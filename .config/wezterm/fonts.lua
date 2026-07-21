local wezterm = require("wezterm")

local M = {}

M.font = wezterm.font_with_fallback({
	"MonoLisaCode Trial",
	"MonoLisa Trial",
	"JetBrainsMono Nerd Font",
})
M.font_size = 11

return M
