return {
	"https://codeberg.org/esensar/nvim-dev-container",
	dependencies = "nvim-treesitter/nvim-treesitter",
	cmd = {
		"DevcontainerStart",
		"DevcontainerAttach",
		"DevcontainerExec",
		"DevcontainerStop",
		"DevcontainerStopAll",
		"DevcontainerRemoveAll",
		"DevcontainerLogs",
		"DevcontainerEditNearestConfig",
	},
	keys = {
		-- Which-Key group header
		{ "<leader>D", "", desc = "+devcontainer", mode = { "n", "v" } },
		-- Submenu keymaps
		{ "<leader>Ds", "<cmd>DevcontainerStart<cr>", desc = "Start Container" },
		{ "<leader>Da", "<cmd>DevcontainerAttach<cr>", desc = "Attach Container" },
		{ "<leader>De", "<cmd>DevcontainerEditNearestConfig<cr>", desc = "Edit devcontainer.json" },
		{ "<leader>Dl", "<cmd>DevcontainerLogs<cr>", desc = "View Logs" },
		{ "<leader>Dq", "<cmd>DevcontainerStop<cr>", desc = "Stop Container" },
		{ "<leader>DQ", "<cmd>DevcontainerStopAll<cr>", desc = "Stop All Containers" },
		{ "<leader>Dr", "<cmd>DevcontainerRemoveAll<cr>", desc = "Remove All Containers" },
	},
	opts = {
		attach_mounts = {
			neovim_config = {
				enabled = true,
				options = { "readonly" },
			},
		},
		container_runtime = "docker",
	},
}
