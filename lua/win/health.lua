local M = {}

local health = vim.health
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

function M.check()
	start("win.nvim")
	if vim.fn.has("nvim-0.9") == 1 then
		ok("Neovim 0.9+ is available")
	else
		error("Neovim 0.9+ is required")
	end

	if vim.fn.has("nvim-0.10") == 1 then
		ok("Window footer support is available")
	else
		warn("Neovim 0.10+ is required for window footers")
	end
end

return M
