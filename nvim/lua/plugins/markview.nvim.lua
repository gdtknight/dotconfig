-- For `plugins/markview.lua` users.
return {
	"OXY2DEV/markview.nvim",
	lazy = false,

	-- Completion for `blink.cmp`
	-- dependencies = { "saghen/blink.cmp" },

	opts = {
		yaml = {
			properties = {
				data_types = {
					["text"] = {
						text = "• ",
						hl = "MarkviewIcon4",
					},
					["list"] = {
						text = "• ",
						hl = "MarkviewIcon5",
					},
					["number"] = {
						text = "# ",
						hl = "MarkviewIcon6",
					},
					["date"] = {
						text = "· ",
						hl = "MarkviewIcon2",
					},
					["date_&_time"] = {
						text = "· ",
						hl = "MarkviewIcon3",
					},
					["checkbox"] = {
						text = function(_, item)
							return item.value == "true" and "[x] " or "[ ] "
						end,
						hl = "MarkviewIcon6",
					},
				},

				-- tags, aliases 등 주요 frontmatter 키도 미니멀 기호로 통일
				["^tags$"] = {
					use_types = false,
					text = "# ",
					hl = "MarkviewIcon0",
				},
				["^aliases$"] = {
					use_types = false,
					text = "• ",
					hl = "MarkviewIcon2",
				},
				["^description$"] = {
					use_types = false,
					text = "• ",
					hl = "MarkviewIcon0",
				},
			},
		},

		markdown = {
			-- 프론트매터 테두리를 깨지기 쉬운 블록 문자(▄, ▀) 대신 깔끔한 실선으로 변경
			metadata_minus = {
				border_top = "─",
				border_bottom = "─",
			},
			metadata_plus = {
				border_top = "─",
				border_bottom = "─",
			},
		},
	},
}
