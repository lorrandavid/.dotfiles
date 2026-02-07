local wezterm = require("wezterm")

local M = {}
local selected_scheme = "Catppuccin Macchiato"
local scheme = wezterm.get_builtin_color_schemes()[selected_scheme]
-- local BG_COLOR = "#292522"

M.color_schemes = {
	[selected_scheme] = scheme,
}
M.color_scheme = selected_scheme
-- M.colors = {
-- 	background = BG_COLOR,
-- 	tab_bar = {
-- 		background = BG_COLOR,
-- 	},
-- }

return M
