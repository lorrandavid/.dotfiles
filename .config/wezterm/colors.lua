local wezterm = require("wezterm")

local M = {}

local function parse_hex(hex)
	local r = tonumber(hex:sub(2, 3), 16)
	local g = tonumber(hex:sub(4, 5), 16)
	local b = tonumber(hex:sub(6, 7), 16)
	return r, g, b
end

local function to_hex(r, g, b)
	r = math.max(0, math.min(255, math.floor(r + 0.5)))
	g = math.max(0, math.min(255, math.floor(g + 0.5)))
	b = math.max(0, math.min(255, math.floor(b + 0.5)))
	return string.format("#%02x%02x%02x", r, g, b)
end

local function darken(hex, factor)
	local r, g, b = parse_hex(hex)
	return to_hex(r * (1 - factor), g * (1 - factor), b * (1 - factor))
end

local function lighten(hex, factor)
	local r, g, b = parse_hex(hex)
	return to_hex(r + (255 - r) * factor, g + (255 - g) * factor, b + (255 - b) * factor)
end

local function mix(hex1, hex2, t)
	local r1, g1, b1 = parse_hex(hex1)
	local r2, g2, b2 = parse_hex(hex2)
	return to_hex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
end

local function derive_tab_bar(s)
	return {
		background = darken(s.background, 0.15),
		inactive_tab_edge = s.selection_bg,
		active_tab = {
			bg_color = s.selection_bg,
			fg_color = s.foreground,
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = darken(s.background, 0.05),
			fg_color = mix(s.foreground, s.background, 0.45),
		},
		inactive_tab_hover = {
			bg_color = lighten(s.background, 0.08),
			fg_color = s.foreground,
			italic = true,
		},
		new_tab = {
			bg_color = darken(s.background, 0.15),
			fg_color = mix(s.foreground, s.background, 0.45),
		},
		new_tab_hover = {
			bg_color = s.brights[5] or s.ansi[5],
			fg_color = s.foreground,
			italic = true,
		},
	}
end

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

local subliminal = {
	foreground = "#d4d4d4",
	background = "#282c35",
	cursor_bg = "#c7c7c7",
	cursor_fg = "#282c35",
	selection_bg = "#484e5b",
	selection_fg = "#d4d4d4",
	ansi = {
		"#7f7f7f",
		"#e15a60",
		"#a9cfa4",
		"#ffe2a9",
		"#6699cc",
		"#f1a5ab",
		"#5fb3b3",
		"#d4d4d4",
	},
	brights = {
		"#7f7f7f",
		"#e15a60",
		"#a9cfa4",
		"#ffe2a9",
		"#6699cc",
		"#f1a5ab",
		"#5fb3b3",
		"#d4d4d4",
	},
}

-- Ported from the terminal palette in Ahmed Hatem's Kintsugi Dark Flared
-- VS Code theme.
local kintsugi_dark_flared = {
	foreground = "#cacac2",
	background = "#131314",
	cursor_bg = "#d4a943",
	cursor_border = "#d4a943",
	cursor_fg = "#0e0e0e",
	selection_bg = "#24262a",
	selection_fg = "#dddddd",
	scrollbar_thumb = "#33352d",
	split = "#2a2a28",
	ansi = {
		"#131314", -- black
		"#b38f8f", -- red
		"#a3be8c", -- green
		"#ebcb8b", -- yellow
		"#6c7a8a", -- blue
		"#b3a3d3", -- magenta
		"#6ac6f2", -- cyan
		"#dddddd", -- white
	},
	brights = {
		"#444444", -- bright black
		"#d9a6a6", -- bright red
		"#c3de9c", -- bright green
		"#fbe4a8", -- bright yellow
		"#8fa3b3", -- bright blue
		"#d3a3d3", -- bright magenta
		"#8ac6f2", -- bright cyan
		"#ffffff", -- bright white
	},
}

local selected_scheme = "Kintsugi Dark Flared"

M.color_schemes = {
	["Kintsugi Dark Flared"] = kintsugi_dark_flared,
	["Subliminal"] = subliminal,
	["Ember"] = ember,
	["Bearded Theme Arc Blueberry"] = arc_blueberry,
	["Github (Tuned)"] = github_tuned,
	["Github"] = wezterm.get_builtin_color_schemes()["Github"],
}

M.color_scheme = selected_scheme

local active_scheme = M.color_schemes[selected_scheme]
if active_scheme then
	M.colors = {
		tab_bar = derive_tab_bar(active_scheme),
	}
end

return M
