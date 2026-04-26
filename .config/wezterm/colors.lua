local wezterm = require("wezterm")

local M = {}

-- Based on the default "ember" palette from:
-- https://github.com/ember-theme/nvim/blob/main/lua/ember/palette.lua
local ember = {
	foreground = "#d8d0c0",
	background = "#1c1b19",
	cursor_bg = "#e08060",
	cursor_border = "#e08060",
	cursor_fg = "#1c1b19",
	selection_bg = "#3e3c38",
	selection_fg = "#d8d0c0",
	scrollbar_thumb = "#585550",
	split = "#3e3c38",
	ansi = {
		"#151412", -- black
		"#e08060", -- red
		"#8a9868", -- green
		"#c09058", -- yellow
		"#7890a0", -- blue
		"#988090", -- magenta
		"#80a090", -- cyan
		"#b8b0a0", -- white
	},
	brights = {
		"#585550", -- bright black
		"#b07878", -- bright red
		"#80a090", -- bright green
		"#c8b468", -- bright yellow
		"#7890a0", -- bright blue
		"#988090", -- bright magenta
		"#80a090", -- bright cyan
		"#d8d0c0", -- bright white
	},
	indexed = {
		[16] = "#c8b468", -- extra gold
		[17] = "#b07878", -- extra rose
	},
	tab_bar = {
		background = "#151412",
		inactive_tab_edge = "#3e3c38",
		active_tab = {
			bg_color = "#3e3c38",
			fg_color = "#d8d0c0",
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = "#252422",
			fg_color = "#908a7e",
		},
		inactive_tab_hover = {
			bg_color = "#2e2d2a",
			fg_color = "#d8d0c0",
			italic = true,
		},
		new_tab = {
			bg_color = "#151412",
			fg_color = "#908a7e",
		},
		new_tab_hover = {
			bg_color = "#e08060",
			fg_color = "#1c1b19",
			italic = true,
		},
	},
}

-- Based on:
-- https://github.com/BeardedBear/bearded-theme/blob/master/dist/zed/themes/bearded-theme.json
local arc_blueberry = {
    foreground = "#bcc1dc",
    background = "#111422",
    cursor_bg = "#8eb0e6",
    cursor_fg = "#111422",
    selection_bg = "#1a1e33",
    selection_fg = "#bcc1dc",
    ansi = {
        "#000000", -- black
        "#E35535", -- red
        "#3CEC85", -- green
        "#EACD61", -- yellow
        "#69C3FF", -- blue
        "#F38CEC", -- magenta
        "#22ECDB", -- cyan
        "#FFFFFF", -- white
    },
    brights = {
        "#3b4677", -- bright black
        "#e97b62", -- bright red
        "#6af1a2", -- bright green
        "#f0db8e", -- bright yellow
        "#9cd7ff", -- bright blue
        "#f8baf4", -- bright magenta
        "#51f0e3", -- bright cyan
        "#dee0ee", -- bright white
    },
}

-- The builtin "Github" scheme is a light theme but its ANSI palette has very low
-- contrast on a white background. Keep a tuned version as an alternate scheme.
local github_tuned = {
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

local selected_scheme = "Ember"

M.color_schemes = {
	["Ember"] = ember,
    ["Bearded Theme Arc Blueberry"] = arc_blueberry,
    ["Github (Tuned)"] = github_tuned,
    ["Github"] = wezterm.get_builtin_color_schemes()["Github"],
}

M.color_scheme = selected_scheme

return M
