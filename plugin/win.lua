if vim.g.loaded_win_nvim then
	return
end
vim.g.loaded_win_nvim = true

require("win").setup()
