---@class win.Configuration
local M = {}
local style = require("win.style")

---@type win.Setup|win.Config
local config = {}
---@param opts? win.Setup|win.Config
---@return win.Configuration
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	return M
end

---@param buf? integer
---@param win? integer
---@param bo? vim.bo|table<string, any>
---@param wo? win.WindowOptions
function M.set_options(buf, win, bo, wo)
	for name, value in pairs(bo or {}) do
		vim.api.nvim_set_option_value(name, value, { buf = buf })
	end
	for name, value in pairs(wo or {}) do
		if name == "winhighlight" and type(value) == "table" then
			local parts = {}
			for key, group in pairs(value) do
				if group ~= "" then
					parts[#parts + 1] = ("%s:%s"):format(key, group)
				end
			end
			value = table.concat(parts, ",")
		end
		vim.api.nvim_set_option_value(name, value, { scope = "local", win = win })
	end
end

---@type win.Config
local defaults = {
	show = true,
	fixbuf = true,
	relative = "editor",
	position = "float",
	minimal = true,
	wo = {
		winhighlight = "Normal:AevreWinNormal,NormalNC:AevreWinNormalNC,WinBar:AevreWinWinBar,WinBarNC:AevreWinWinBarNC,FloatTitle:AevreWinTitle,FloatFooter:AevreWinFooter,WinSeparator:AevreWinWinSeparator",
	},
	bo = {},
	title_pos = "center",
	keys = {
		q = "close",
	},
	footer_pos = "center",
	footer_keys = false,
}

---@param ...? win.Config|string|{}
---@return win.Config
function M.resolve(...)
	local done = {} ---@type table<string, boolean>
	local merge = {} ---@type win.Config[]
	local stack = {}
	for i = 1, select("#", ...) do
		local next = select(i, ...) ---@type win.Config|string?
		if next then
			table.insert(stack, next)
		end
	end
	while #stack > 0 do
		local next = table.remove(stack)
		next = type(next) == "string" and style(next) or next
		---@cast next win.Config?
		if next and type(next) == "table" then
			table.insert(merge, 1, next)
			if next.style and not done[next.style] then
				done[next.style] = true
				table.insert(stack, next.style)
			end
		end
	end
	local ret = #merge == 0 and {} or #merge == 1 and merge[1] or vim.tbl_deep_extend("force", {}, unpack(merge))
	ret.style = nil
	---@cast ret win.Config
	return ret
end

---@param opts? win.Config|{}
---@return win.Config
function M.get(opts)
	opts = M.resolve(vim.tbl_deep_extend("force", {}, defaults, config.win or config), opts)
	if opts.minimal then
		opts = M.resolve("minimal", opts)
	end
	if opts.position == "float" then
		opts = M.resolve("float", opts)
	else
		opts = M.resolve("split", opts)
		local vertical = opts.position == "left" or opts.position == "right"
		opts.wo = opts.wo or {}
		opts.wo.winfixheight = not vertical
		opts.wo.winfixwidth = vertical
	end
	if opts.relative == "win" then
		opts.win = opts.win or vim.api.nvim_get_current_win()
	end
	return opts
end

return M
