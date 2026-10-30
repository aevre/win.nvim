---@class win.Style
---@overload fun(name: string): win.Config
---@type win.Style
local M = setmetatable({}, {
	__call = function(t, ...)
		return t.get(...)
	end,
})

M.__index = M

---@type table<string, win.Config>
local styles = {}

---@param name string
---@param defaults win.Config|{}
---@return string
function M.add(name, defaults)
	styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), styles[name] or {})
	return name
end

---@param name string
---@return win.Config
function M.get(name)
	return styles[name]
end

M.add("float", {
	position = "float",
	backdrop = 60,
	height = 0.9,
	width = 0.9,
	zindex = 50,
})

M.add("help", {
	position = "float",
	backdrop = false,
	border = "top",
	row = -1,
	width = 0,
	height = 0.3,
})

M.add("split", {
	position = "bottom",
	height = 0.4,
	width = 0.4,
})

M.add("minimal", {
	wo = {
		cursorcolumn = false,
		cursorline = false,
		cursorlineopt = "both",
		colorcolumn = "",
		fillchars = "eob: ,lastline:…",
		foldcolumn = "0",
		list = false,
		listchars = "extends:…,tab:  ",
		number = false,
		relativenumber = false,
		signcolumn = "no",
		spell = false,
		winbar = "",
		statuscolumn = "",
		wrap = false,
		sidescrolloff = 0,
	},
})

return M
