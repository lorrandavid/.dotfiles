local wezterm = require("wezterm")

local M = {}
local selected_scheme = "Github"
local scheme = wezterm.get_builtin_color_schemes()[selected_scheme]

M.color_schemes = {
	[selected_scheme] = scheme,
}
M.color_scheme = selected_scheme

-- The builtin "Github" scheme is a light theme but its ANSI palette has very low
-- contrast on a white background. Override the palette with darker values.
M.colors = {
	foreground = "#24292e",
	background = "#ffffff",
	cursor_bg = "#24292e",
	cursor_fg = "#ffffff",
	selection_bg = "#d0d7de",
	selection_fg = "#24292e",
	ansi = {
		"#24292e", -- black
		"#d73a49", -- red
		"#22863a", -- green
		"#b08800", -- yellow (darker for readability)
		"#0366d6", -- blue
		"#5a32a3", -- magenta
		"#0598bc", -- cyan
		"#6a737d", -- white
	},
	brights = {
		"#586069", -- bright black
		"#cb2431", -- bright red
		"#22863a", -- bright green
		"#b08800", -- bright yellow
		"#005cc5", -- bright blue
		"#5a32a3", -- bright magenta
		"#3192aa", -- bright cyan
		"#d0d7de", -- bright white
	},
}

return M
