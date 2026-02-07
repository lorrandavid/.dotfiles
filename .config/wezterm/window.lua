local wezterm = require("wezterm")

local M = {}
-- local selected_scheme = "Catppuccin Macchiato"
-- local scheme = wezterm.get_builtin_color_schemes()[selected_scheme]

-- window settings
M.bold_brightens_ansi_colors = true
M.window_padding = {
	left = 8,
	right = 8,
	top = 4,
	bottom = 0,
}

-- tab settings
M.tab_bar_at_bottom = true
M.hide_tab_bar_if_only_one_tab = true
M.show_new_tab_button_in_tab_bar = false
M.show_tab_index_in_tab_bar = true
M.status_update_interval = 1000
M.use_fancy_tab_bar = false
M.tab_max_width = 32

-- local function tab_title(tab)
-- 	local title = tab.tab_title
-- 	if title and #title > 0 then
-- 		return title
-- 	end
-- 	return tab.active_pane.title
-- end

-- format tab style
-- wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
-- 	local background = "#FFFFFF"
-- 	local foreground = "#ECE1D7"
-- 	local edge_background = "#292522"
--
-- 	if tab.is_active or hover then
-- 		background = "#78997A"
-- 		foreground = "#282C34"
-- 	end
-- 	local edge_foreground = background
--
-- 	local title = tab_title(tab)
--
-- 	local max = M.tab_max_width - 9
-- 	if #title > max then
-- 		title = wezterm.truncate_right(title, max) .. "…"
-- 	end
--
-- 	return {
-- 		{ Background = { Color = edge_background } },
-- 		{ Foreground = { Color = edge_foreground } },
-- 		-- { Text = " " },
-- 		{ Background = { Color = background } },
-- 		{ Foreground = { Color = foreground } },
-- 		{ Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
-- 		{ Text = " " .. (tab.tab_index + 1) .. ": " .. title .. " " },
-- 		{ Background = { Color = edge_background } },
-- 		{ Foreground = { Color = edge_foreground } },
-- 		-- { Text = "" },
-- 	}
-- end)

-- show if leader key is active
wezterm.on("update-right-status", function(window, _)
	local prefix = ""

	if window:leader_is_active() then
		prefix = " " .. utf8.char(0x1f30a) .. " " -- ocean wave
	end

	window:set_left_status(wezterm.format({
		{ Background = { Color = "#BD8183" } },
		{ Text = prefix },
	}))
end)

return M
