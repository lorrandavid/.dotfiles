local wezterm = require("wezterm")

local M = {}

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

local selected_scheme = "Github (Tuned)"

M.color_schemes = {
    ["Bearded Theme Arc Blueberry"] = arc_blueberry,
    ["Github (Tuned)"] = github_tuned,
    ["Github"] = wezterm.get_builtin_color_schemes()["Github"],
}

M.color_scheme = selected_scheme

return M
