-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
-- This will hold the configuration.
local config = wezterm.config_builder()

local appearance = require("appearance")

local projects = require("projects")
local workspaces = require("workspaces")

wezterm.on("gui-startup", function()
	workspaces.loadWorkspaces()
end)

wezterm.on("save-workspaces", function()
	local activeWorkspace = wezterm.mux.get_active_workspace()
	print(wezterm.mux.all_windows())
	for _, window in ipairs(wezterm.mux.all_windows()) do
		if window:get_workspace() == activeWorkspace then
			window:gui_window():toast_notification("(Workspaces)", "Saving workspaces...", nil, 5000)
		end
	end
	workspaces.saveWorkspaces()
end)

if appearance.is_light() then
	config.color_scheme = "Gruvbox (Gogh)"
else
	config.color_scheme = "Gruvbox Dark (Gogh)"
end

-- config.enable_tab_bar = false

-- various terminal configurations
local function file_exists(name)
	local f = io.open(name, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function git_bash_bin_path()
	local candidates = {
		(os.getenv("ProgramFiles") or "") .. "\\Git\\bin\\bash.exe",
		(os.getenv("LocalAppData") or "") .. "\\Programs\\Git\\bin\\bash.exe",
		"C:\\Program Files\\Git\\bin\\bash.exe",
		"C:\\Users\\" .. (os.getenv("USERNAME") or "") .. "\\AppData\\Local\\Programs\\Git\\bin\\bash.exe",
	}
	for _, path in ipairs(candidates) do
		if file_exists(path) then
			return path
		end
	end
	return "bash.exe"
end

local function msys2_root()
	return os.getenv("MSYS2_ROOT") or "C:\\msys64"
end

local function msys2_home()
	return msys2_root() .. "\\home\\" .. (os.getenv("USERNAME") or "")
end

config.default_prog = { git_bash_bin_path(), "--login", "-i" }
config.launch_menu = {
	{
		label = "Git Bash",
		args = { git_bash_bin_path(), "--login", "-i" },
	},
	{
		label = "WSL Bash",
		args = { "C:\\Windows\\System32\\bash.exe", "--login", "-i" },
	},
	{
		label = "MSYS2 UCRT64",
		args = { msys2_root() .. "\\usr\\bin\\bash.exe", "--login", "-i" },
		cwd = msys2_home(),
	},
	{
		label = "Windows CMD",
		args = { "cmd.exe" },
	},
	{
		label = "Windows CMD (Admin)",
		args = { "powershell.exe", "-NoLogo", "-Command", "Start-Process cmd -Verb runAs" },
	},
	{
		label = "PowerShell",
		args = { "powershell.exe", "-NoLogo" },
	},
	{
		label = "PowerShell (Admin)",
		args = { "powershell.exe", "-NoLogo", "-Command", "Start-Process powershell -Verb runAs" },
	},
}

-- appearance configurations

config.window_background_opacity = 0.90
config.macos_window_background_blur = 1000000

config.window_decorations = "RESIZE"

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

-- shortcut configurations

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
local function resize_pane(key, direction)
	return {
		key = key,
		action = wezterm.action.AdjustPaneSize({ direction, 3 }),
	}
end
config.key_tables = {
	resize_panes = {
		resize_pane("j", "Down"),
		resize_pane("k", "Up"),
		resize_pane("h", "Left"),
		resize_pane("l", "Right"),
	},
}

config.keys = {
	{
		key = "p",
		mods = "LEADER",
		-- Present in to our project picker
		action = projects.choose_project(),
	},
	{
		key = "f",
		mods = "LEADER",
		-- Present a list of existing workspaces
		action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
	},
	{ key = "s", mods = "LEADER", action = wezterm.action.EmitEvent("save-workspaces") },
	{
		key = "h",
		mods = "CTRL|SHIFT|ALT",
		action = wezterm.action.SplitPane({
			direction = "Right",
			size = { Percent = 50 },
		}),
	},
	{
		key = "w",
		mods = "CTRL",
		action = wezterm.action.CloseCurrentPane({ confirm = false }),
	},
	{
		key = "v",
		mods = "CTRL|SHIFT|ALT",
		action = wezterm.action.SplitPane({
			direction = "Down",
			size = { Percent = 50 },
		}),
	},
	{
		-- When we push LEADER + R...
		key = "r",
		mods = "LEADER",
		-- Activate the `resize_panes` keytable
		action = wezterm.action.ActivateKeyTable({
			name = "resize_panes",
			-- Ensures the keytable stays active after it handles its
			-- first keypress.
			one_shot = false,
			-- Deactivate the keytable after a timeout.
			timeout_milliseconds = 1000,
		}),
	},
	{ key = "9", mods = "CTRL", action = act.PaneSelect },
	{ key = "L", mods = "CTRL", action = act.ShowDebugOverlay },
	{
		key = "O",
		mods = "CTRL|ALT",
		-- toggling opacity
		action = wezterm.action_callback(function(window, _)
			local overrides = window:get_config_overrides() or {}
			if overrides.window_background_opacity == 1.0 then
				overrides.window_background_opacity = 0.90
			else
				overrides.window_background_opacity = 1.0
			end
			window:set_config_overrides(overrides)
		end),
	},
	{
		-- I like to use vim direction keybindings, but feel free to replace
		-- with directional arrows instead.
		key = "j", -- or DownArrow
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	{
		key = "k", -- or UpArrow
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "h", -- or LeftArrow
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "l", -- or RightArrow
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
}

local function segments_for_right_status(window)
	return {
		window:active_workspace(),
		wezterm.strftime("%a %b %-d %H:%M"),
		wezterm.hostname(),
	}
end

wezterm.on("update-status", function(window, _)
	if appearance.is_light() then
		config.color_scheme = "Gruvbox (Gogh)"
	else
		config.color_scheme = "Gruvbox Dark (Gogh)"
	end
	local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
	local segments = segments_for_right_status(window)

	local color_scheme = window:effective_config().resolved_palette
	-- Note the use of wezterm.color.parse here, this returns
	-- a Color object, which comes with functionality for lightening
	-- or darkening the colour (amongst other things).
	local bg = wezterm.color.parse(color_scheme.background)
	local fg = color_scheme.foreground

	-- Each powerline segment is going to be coloured progressively
	-- darker/lighter depending on whether we're on a dark/light colour
	-- scheme. Let's establish the "from" and "to" bounds of our gradient.
	local gradient_to, gradient_from = bg
	if not appearance.is_light() then
		gradient_from = gradient_to:lighten(0.2)
	else
		gradient_from = gradient_to:darken(0.2)
	end

	-- Yes, WezTerm supports creating gradients, because why not?! Although
	-- they'd usually be used for setting high fidelity gradients on your terminal's
	-- background, we'll use them here to give us a sample of the powerline segment
	-- colours we need.
	local gradient = wezterm.color.gradient(
		{
			orientation = "Horizontal",
			colors = { gradient_from, gradient_to },
		},
		#segments -- only gives us as many colours as we have segments.
	)

	-- We'll build up the elements to send to wezterm.format in this table.
	local elements = {}

	for i, seg in ipairs(segments) do
		local is_first = i == 1

		if is_first then
			table.insert(elements, { Background = { Color = "none" } })
		end
		table.insert(elements, { Foreground = { Color = gradient[i] } })
		table.insert(elements, { Text = SOLID_LEFT_ARROW })

		table.insert(elements, { Foreground = { Color = fg } })
		table.insert(elements, { Background = { Color = gradient[i] } })
		table.insert(elements, { Text = " " .. seg .. " " })
	end

	window:set_right_status(wezterm.format(elements))
end)

-- and finally, return the configuration to wezterm
return config
