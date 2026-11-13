-- ===========================================================================
-- LazyVim Keymaps for Neovim & VSCode Neovim
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. 공통 기본 키맵 (Common for CLI & VSCode)
-- ---------------------------------------------------------------------------
-- Better Indenting (Visual Mode 들여쓰기 시 선택 영역 유지)
vim.keymap.set("x", "<", "<gv", { desc = "Indent Left and reselect" })
vim.keymap.set("x", ">", ">gv", { desc = "Indent Right and reselect" })

-- Commenting (현재 줄 아래/위에 주석 추가)
vim.keymap.set("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
vim.keymap.set("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

-- Undo Break-points (구두점 입력 시 undo 포인트 생성)
vim.keymap.set("i", ",", ",<c-g>u")
vim.keymap.set("i", ".", ".<c-g>u")
vim.keymap.set("i", ";", ";<c-g>u")

-- Saner Search Behavior (검색 결과 이동 시 화면 중앙 정렬)
vim.keymap.set("n", "n", "nzzzv", { desc = "Next Search Result and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev Search Result and center" })

-- Scrolling & Clear Search Highlight
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Save File
vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- ---------------------------------------------------------------------------
-- 2. VS Code Neovim 전용 키맵 (Which-Key 팝업 연동)
-- ---------------------------------------------------------------------------
if vim.g.vscode then
	local vscode = require("vscode")

	-- 1) Leader (<Space>): Which-Key 메인 메뉴 (File, Buffer, Window, Code, Git 등)
	vim.keymap.set("n", "<leader>", function()
		vscode.action("whichkey.show")
	end, { desc = "Which-Key Main Menu" })

	-- 2) 'g' (Goto / LSP / Operations)
	local goto_menu = {
		{ key = "g", name = "Top of File (gg)", type = "command", command = "cursorTop" },
		{ key = "d", name = "Go to Definition (gd)", type = "command", command = "editor.action.revealDefinition" },
		{ key = "D", name = "Type Definition (gD)", type = "command", command = "editor.action.goToTypeDefinition" },
		{ key = "r", name = "References (gr)", type = "command", command = "editor.action.referenceSearch.trigger" },
		{ key = "i", name = "Implementation (gi)", type = "command", command = "editor.action.goToImplementation" },
		{ key = "c", name = "Comment Line (gcc)", type = "command", command = "editor.action.commentLine" },
		{ key = "b", name = "Navigate Back", type = "command", command = "workbench.action.navigateBack" },
	}
	vim.keymap.set("n", "g", function()
		vscode.action("whichkey.show", { args = { goto_menu } })
	end, { desc = "Goto / LSP Menu" })

	-- 3) 'z' (Folding & Viewport)
	local fold_menu = {
		{ key = "a", name = "Toggle Fold (za)", type = "command", command = "editor.toggleFold" },
		{ key = "c", name = "Close Fold (zc)", type = "command", command = "editor.fold" },
		{ key = "o", name = "Open Fold (zo)", type = "command", command = "editor.unfold" },
		{ key = "R", name = "Unfold All (zR)", type = "command", command = "editor.unfoldAll" },
		{ key = "M", name = "Fold All (zM)", type = "command", command = "editor.foldAll" },
	}
	vim.keymap.set("n", "z", function()
		vscode.action("whichkey.show", { args = { fold_menu } })
	end, { desc = "Folding Menu" })

	-- 4) '[' (Previous / Backwards Navigation)
	local prev_menu = {
		{ key = "b", name = "Prev Buffer / Tab ([b)", type = "command", command = "workbench.action.previousEditor" },
		{ key = "d", name = "Prev Diagnostic / Problem ([d)", type = "command", command = "editor.action.marker.prev" },
		{
			key = "c",
			name = "Prev Git Change ([c)",
			type = "command",
			command = "workbench.action.editor.previousChange",
		},
	}
	vim.keymap.set("n", "[", function()
		vscode.action("whichkey.show", { args = { prev_menu } })
	end, { desc = "Previous Navigation Menu" })

	-- 5) ']' (Next / Forwards Navigation)
	local next_menu = {
		{ key = "b", name = "Next Buffer / Tab (]b)", type = "command", command = "workbench.action.nextEditor" },
		{ key = "d", name = "Next Diagnostic / Problem (]d)", type = "command", command = "editor.action.marker.next" },
		{ key = "c", name = "Next Git Change (]c)", type = "command", command = "workbench.action.editor.nextChange" },
	}
	vim.keymap.set("n", "]", function()
		vscode.action("whichkey.show", { args = { next_menu } })
	end, { desc = "Next Navigation Menu" })

	-- 6) '<C-w>' (Window / Split Management)
	local window_menu = {
		{
			key = "s",
			name = "Split Horizontal (<C-w>s)",
			type = "command",
			command = "workbench.action.splitEditorDown",
		},
		{
			key = "v",
			name = "Split Vertical (<C-w>v)",
			type = "command",
			command = "workbench.action.splitEditorRight",
		},
		{
			key = "c",
			name = "Close Window / Editor (<C-w>c)",
			type = "command",
			command = "workbench.action.closeActiveEditor",
		},
		{
			key = "o",
			name = "Close Other Editors (<C-w>o)",
			type = "command",
			command = "workbench.action.closeOtherEditors",
		},
		{
			key = "m",
			name = "Toggle Maximize Editor",
			type = "command",
			command = "workbench.action.toggleEditorWidths",
		},
		{ key = "h", name = "Focus Left (<C-w>h)", type = "command", command = "workbench.action.navigateLeft" },
		{ key = "j", name = "Focus Down (<C-w>j)", type = "command", command = "workbench.action.navigateDown" },
		{ key = "k", name = "Focus Up (<C-w>k)", type = "command", command = "workbench.action.navigateUp" },
		{ key = "l", name = "Focus Right (<C-w>l)", type = "command", command = "workbench.action.navigateRight" },
		{ key = "=", name = "Reset / Even Layout", type = "command", command = "workbench.action.evenEditorWidths" },
	}
	vim.keymap.set("n", "<C-w>", function()
		vscode.action("whichkey.show", { args = { window_menu } })
	end, { desc = "Window Management Menu" })

	-- [에디터 분할 창 직접 이동 (<C-h/j/k/l>)]
	vim.keymap.set("n", "<C-h>", function()
		vscode.action("workbench.action.navigateLeft")
	end, { desc = "Navigate Left" })
	vim.keymap.set("n", "<C-j>", function()
		vscode.action("workbench.action.navigateDown")
	end, { desc = "Navigate Down" })
	vim.keymap.set("n", "<C-k>", function()
		vscode.action("workbench.action.navigateUp")
	end, { desc = "Navigate Up" })
	vim.keymap.set("n", "<C-l>", function()
		vscode.action("workbench.action.navigateRight")
	end, { desc = "Navigate Right" })

	-- [빠른 탭 전환 (<S-h/l>)]
	vim.keymap.set("n", "<S-h>", function()
		vscode.action("workbench.action.previousEditor")
	end, { desc = "Prev Buffer / Tab" })
	vim.keymap.set("n", "<S-l>", function()
		vscode.action("workbench.action.nextEditor")
	end, { desc = "Next Buffer / Tab" })

	-- [도움말 Hover]
	vim.keymap.set("n", "K", function()
		vscode.action("editor.action.showHover")
	end, { desc = "Show Hover" })

	-- [터미널 토글 (<C-/>)]
	vim.keymap.set({ "n", "t" }, "<C-/>", function()
		vscode.action("workbench.action.terminal.toggleTerminal")
	end, { desc = "Toggle Terminal" })
	vim.keymap.set({ "n", "t" }, "<C-_>", function()
		vscode.action("workbench.action.terminal.toggleTerminal")
	end, { desc = "Toggle Terminal" })

	-- [Visual Mode 줄 이동 (J / K)]
	vim.keymap.set("x", "J", function()
		vscode.action("editor.action.moveLinesDownAction")
	end, { desc = "Move lines down" })
	vim.keymap.set("x", "K", function()
		vscode.action("editor.action.moveLinesUpAction")
	end, { desc = "Move lines up" })
else
	-- -------------------------------------------------------------------------
	-- 3. 표준 Neovim 터미널 전용 키맵
	-- -------------------------------------------------------------------------
	vim.keymap.set("i", "jk", "<ESC>", { desc = "Return to normal mode", silent = true })

	vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
	vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
	vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
	vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

	vim.keymap.set(
		"n",
		"<F4>",
		":highlight clear cursorline<cr>",
		{ desc = "Clear cursorline highlight", silent = true }
	)

	local lazyterm = function()
		if Snacks and Snacks.terminal then
			Snacks.terminal(nil, { cwd = LazyVim.root() })
		else
			LazyVim.terminal(nil, { cwd = LazyVim.root() })
		end
	end
	vim.keymap.set("n", "<c-\\>", lazyterm, { desc = "Terminal (Root Dir)" })
	vim.keymap.set("t", "<C-\\>", "<cmd>close<cr>", { desc = "Hide Terminal" })

	vim.keymap.set("n", "<C-h>", ":NvimTmuxNavigateLeft<CR>", { desc = "NvimTmuxNavigateLeft", silent = true })
	vim.keymap.set("n", "<C-j>", ":NvimTmuxNavigateDown<CR>", { desc = "NvimTmuxNavigateDown", silent = true })
	vim.keymap.set("n", "<C-k>", ":NvimTmuxNavigateUp<CR>", { desc = "NvimTmuxNavigateUp", silent = true })
	vim.keymap.set("n", "<C-l>", ":NvimTmuxNavigateRight<CR>", { desc = "NvimTmuxNavigateRight", silent = true })
end
