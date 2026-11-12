local function get_workspaces()
	local workspaces = {}
	local icloud_docs = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents")

	-- 1. Automatically discover all vaults in the iCloud Obsidian Documents directory
	if vim.fn.isdirectory(icloud_docs) == 1 then
		for name, type in vim.fs.dir(icloud_docs) do
			if type == "directory" and not name:match("^%.") then
				table.insert(workspaces, {
					name = name,
					path = icloud_docs .. "/" .. name,
					templates = {
						folder = "templates",
						date_format = "%Y-%m-%d-%a",
						time_format = "%H:%M",
					},
				})
			end
		end
	end

	-- Sort discovered workspaces alphabetically by vault name
	table.sort(workspaces, function(a, b)
		return a.name < b.name
	end)

	-- 2. Fallback no-vault workspace (CWD or buffer directory)
	table.insert(workspaces, {
		name = "no-vault",
		path = function()
			return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
		end,
		notes_subdir = vim.NIL,
		new_notes_location = "current_dir",
		templates = {
			folder = vim.NIL,
		},
		disable_frontmatter = true,
	})

	return workspaces
end

return {
	"obsidian-nvim/obsidian.nvim",
	version = "*", -- use latest release, remove to use latest commit
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"hrsh7th/nvim-cmp",
		"nvim-telescope/telescope.nvim",
	},
	---@module 'obsidian'
	---@type obsidian.config
	opts = {
		legacy_commands = false,
		workspaces = get_workspaces(),

		templates = {
			folder = "templates",
			date_format = "%Y-%m-%d-%a",
			time_format = "%H:%M",
		},

		---@class obsidian.config.FooterOpts
		footer = {
			enabled = true,
			format = "{{backlinks}} backlinks  {{properties}} properties  {{words}} words  {{chars}} chars",
			hl_group = "Comment",
			separator = string.rep("-", 80),
		},

		-- UI Settings (Custom checkboxes & highlight groups)
		ui = {
			enable = true,
			update_debounce = 200,
			max_file_length = 5000,
			checkboxes = {
				[" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
				["x"] = { char = "", hl_group = "ObsidianDone" },
				[">"] = { char = "", hl_group = "ObsidianRightArrow" },
				["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
				["!"] = { char = "", hl_group = "ObsidianImportant" },
			},
			bullets = { char = "•", hl_group = "ObsidianBullet" },
			external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
			reference_text = { hl_group = "ObsidianRefText" },
			highlight_text = { hl_group = "ObsidianHighlightText" },
			tags = { hl_group = "ObsidianTag" },
			block_ids = { hl_group = "ObsidianBlockID" },
			hl_groups = {
				ObsidianTodo = { bold = true, fg = "#f78c6c" },
				ObsidianDone = { bold = true, fg = "#89ddff" },
				ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
				ObsidianTilde = { bold = true, fg = "#ff5370" },
				ObsidianImportant = { bold = true, fg = "#d73128" },
				ObsidianBullet = { bold = true, fg = "#89ddff" },
				ObsidianRefText = { underline = true, fg = "#c792ea" },
				ObsidianExtLinkIcon = { fg = "#c792ea" },
				ObsidianTag = { italic = true, fg = "#89ddff" },
				ObsidianBlockID = { italic = true, fg = "#89ddff" },
				ObsidianHighlightText = { bg = "#75662e" },
			},
		},

		-- Attachment settings
		attachments = {
			img_folder = "assets/imgs",
			img_name_func = function()
				return string.format("%s-", os.time())
			end,
			img_text_func = function(client, path)
				path = client:vault_relative_path(path) or path
				return string.format("![%s](%s)", path.name, path)
			end,
		},
	},
}
