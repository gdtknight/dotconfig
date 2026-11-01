return {
	{
		"folke/tokyonight.nvim",
		opts = {
			style = "moon",
			transparent = true,
			styles = {
				sidebars = "transparent",
				keywords = { bold = true },
				functions = { bold = true },
				floats = "transparent",
			},
			on_colors = function(colors)
				colors.bg_statusline = colors.none -- To check if its working try something like "#ff00ff" instead of colors.none
				colors.bg = colors.none
			end,
			on_highlights = function(hl, c)
				-- TabLineFill is currently set to black
				hl.TabLineFill = {
					bg = c.none,
				}
			end,
		},
	},
}
