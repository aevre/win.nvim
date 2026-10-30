---@class win.Appearance
local M = {}

---@return boolean
function M.transparent()
	return vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == nil
end

local highlights = {
	Backdrop = { bg = "#000000" },
	Footer = "FloatFooter",
	ActiveBorder = "FloatBorder",
	FooterDesc = "DiagnosticInfo",
	FooterKey = "DiagnosticVirtualTextInfo",
	Normal = "NormalFloat",
	NormalNC = "NormalFloat",
	Title = "FloatTitle",
	WinBar = "Title",
	WinBarNC = "Title",
	WinKey = "Keyword",
	WinKeySep = "NonText",
	WinKeyDesc = "Function",
	WinSeparator = "WinSeparator",
}

function M.setup()
	for name, value in pairs(highlights) do
		local hl ---@type vim.api.keyset.highlight
		if type(value) == "string" then
			hl = { link = value }
		else
			hl = vim.deepcopy(value)
		end
		hl.default = true
		vim.api.nvim_set_hl(0, "AevreWin" .. name, hl)
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("aevre_win_highlights", { clear = true }),
	callback = M.setup,
})

M.setup()

local function blend(fg, bg, alpha)
	local function channel(index)
		local f = tonumber(fg:sub(index, index + 1), 16)
		local b = tonumber(bg:sub(index, index + 1), 16)
		return math.floor(alpha * f + (1 - alpha) * b + 0.5)
	end
	return ("#%02x%02x%02x"):format(channel(2), channel(4), channel(6))
end

local function hl_color(group, prop)
	local color = vim.api.nvim_get_hl(0, { name = group, link = false })[prop or "fg"]
	return color and ("#%06x"):format(color)
end

---@param self win
function M.drop(self)
	if self.backdrop then
		self.backdrop:close()
		self.backdrop = nil
	end
	local backdrop = self.opts.backdrop
	if not backdrop then
		return
	end
	backdrop = type(backdrop) == "number" and { blend = backdrop } or backdrop
	backdrop = backdrop == true and {} or backdrop
	---@diagnostic disable-next-line: param-type-mismatch
	backdrop = vim.tbl_extend("force", { bg = "#000000", blend = 60, transparent = true }, backdrop)
	---@cast backdrop win.Backdrop

	if
		(M.transparent() and backdrop.transparent)
		or not vim.o.termguicolors
		or backdrop.blend == 100
		or not self:is_floating()
	then
		return
	end

	local bg, winblend = backdrop.bg or "#000000", backdrop.blend

	if not backdrop.transparent then
		if M.transparent() then
			---@diagnostic disable-next-line: assign-type-mismatch
			bg = "NONE"
		else
			local normal_bg = hl_color("Normal", "bg")
			if normal_bg then
				bg = blend(normal_bg, bg, (winblend or 0) / 100)
			end
		end
		winblend = 0
	end

	local group = ("AevreWinBackdrop_%s"):format(bg and bg:sub(2) or "T")
	vim.api.nvim_set_hl(0, group, { bg = bg })

	local Win = require("win")
	self.backdrop = Win.new(Win.resolve({
		enter = false,
		backdrop = false,
		relative = "editor",
		height = 0,
		width = 0,
		style = "minimal",
		border = "none",
		focusable = false,
		---@diagnostic disable-next-line: need-check-nil
		zindex = self.opts.zindex - 1,
		wo = {
			winhighlight = "Normal:" .. group,
			winblend = winblend,
			colorcolumn = "",
		},
		bo = {
			buftype = "nofile",
			filetype = "win_backdrop",
		},
	}, backdrop.win))
end

return M
