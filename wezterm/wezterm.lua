local wezterm = require("wezterm")

return {
	-- TERM
	term = "xterm-256color",
	enable_tab_bar = false,

	-- 테마
	-- color_scheme = "Coolnight",
	colors = {
		foreground = "#CBE0F0",
		background = "#011423",

		cursor_bg = "#47FF9C",
		cursor_border = "#47FF9C",
		cursor_fg = "#011423",

		selection_bg = "#033259",
		selection_fg = "#CBE0F0",

		ansi = {
			"#214969", -- black
			"#E52E2E", -- red
			"#44FFB1", -- green
			"#FFE073", -- yellow
			"#0FC5ED", -- blue
			"#A277FF", -- magenta
			"#24EAF7", -- cyan
			"#CBE0F0", -- white
		},

		brights = {
			"#214969", -- bright black
			"#E52E2E", -- bright red
			"#44FFB1", -- bright green
			"#FFE073", -- bright yellow
			"#A277FF", -- bright blue
			"#A277FF", -- bright magenta
			"#24EAF7", -- bright cyan
			"#FFFFFF", -- bright white
		},
	},

	-- 창
	window_decorations = "RESIZE",

	window_padding = {
		left = 4,
		right = 4,
		top = 4,
		bottom = 4,
	},

	window_background_opacity = 0.88,

	-- macOS blur
	macos_window_background_blur = 0,

	-- 폰트
	-- font = wezterm.font("D2CodingLigature Nerd Font"),
	font = wezterm.font("ComicShannsMono Nerd Font"),

	font_size = 12.0,

	send_composed_key_when_left_alt_is_pressed = false,
	send_composed_key_when_right_alt_is_pressed = false,
}
