local wezterm = require("wezterm")

local M = {}

local font_directories = {
	(os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts",
}

local local_app_data = os.getenv("LOCALAPPDATA")
if local_app_data then
	table.insert(font_directories, local_app_data .. "\\Microsoft\\Windows\\Fonts")
end

local function file_exists(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end

	file:close()
	return true
end

local function add_if_installed(families, family, filenames)
	for _, directory in ipairs(font_directories) do
		for _, filename in ipairs(filenames) do
			if file_exists(directory .. "\\" .. filename) then
				table.insert(families, family)
				return
			end
		end
	end
end

local families = {}
add_if_installed(families, "MonoLisaCode Trial", {
	"MonoLisaCodeTrial-Regular.ttf",
	"MonoLisaCodeTrial-Regular.otf",
})
add_if_installed(families, "MonoLisa Trial", {
	"MonoLisaTrial-Regular.ttf",
	"MonoLisaTrial-Regular.otf",
})
add_if_installed(families, "JetBrainsMono Nerd Font", {
	"JetBrainsMonoNerdFont-Regular.ttf",
	"JetBrainsMonoNerdFont-Regular_0.ttf",
})

if #families > 0 then
	M.font = wezterm.font_with_fallback(families)
end
M.font_size = 11

return M
