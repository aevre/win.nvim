---@class win.Layout
local M = {}

local win_opts = {
	"anchor",
	"border",
	"bufpos",
	"col",
	"external",
	"fixed",
	"focusable",
	"footer",
	"footer_pos",
	"height",
	"hide",
	"noautocmd",
	"relative",
	"row",
	"style",
	"title",
	"title_pos",
	"width",
	"win",
	"zindex",
}

---@type table<string, string[]>
local borders = {
	left = { "", "", "", "", "", "", "", "│" },
	right = { "", "", "", "│", "", "", "", "" },
	top = { "", "─", "", "", "", "", "", "" },
	bottom = { "", "", "", "", "", "─", "", "" },
	top_bottom = { "", "─", "", "", "", "─", "", "" },
	hpad = { "", "", "", " ", "", "", "", " " },
	vpad = { "", " ", "", "", "", " ", "", "" },
}

---@return { height: integer, width: integer }
---@param self win
function M.parent_size(self)
	if self.opts.relative == "win" and vim.api.nvim_win_is_valid(self.opts.win) then
		return {
			height = vim.api.nvim_win_get_height(self.opts.win),
			width = vim.api.nvim_win_get_width(self.opts.win),
		}
	end
	return {
		height = vim.o.lines,
		width = vim.o.columns,
	}
end

---@param self win
---@return vim.api.keyset.win_config
function M.win_opts(self)
	local opts = {} ---@type vim.api.keyset.win_config
	for _, k in ipairs(win_opts) do
		opts[k] = self.opts[k]
	end

	local border = self:border()

	---@diagnostic disable-next-line: assign-type-mismatch
	opts.border = border and (borders[border] or border) or "none"

	if opts.relative == "cursor" then
		self.opts.row = self.opts.row or 0
		self.opts.col = self.opts.col or 0
	end

	local dim = self:dim()
	opts.height, opts.width = dim.height, dim.width
	opts.row, opts.col = dim.row, dim.col

	if vim.fn.has("nvim-0.10") == 0 then
		opts.footer, opts.footer_pos = nil, nil
	end

	if border then
		opts.title_pos = opts.title and (opts.title_pos or "center") or nil
		opts.footer_pos = opts.footer and (opts.footer_pos or "center") or nil
	else
		opts.title, opts.footer = nil, nil
		opts.title_pos, opts.footer_pos = nil, nil
	end

	return opts
end

---@return { height: integer, width: integer }
---@param self win
function M.size(self)
	local opts = self:win_opts()
	local height = opts.height or 60
	local width = opts.width or 80
	if self:has_border() then
		height = height + 2
		width = width + 2
	end
	return { height = height, width = width }
end

---@param self win
---@return boolean
function M.has_border(self)
	return self:border() ~= nil
end

---@param border? win.Border
---@return boolean?
function M.is_border(border)
	return border and border ~= "" and border ~= "none"
end

---@param self win
---@return string|(string|{[1]: string, [2]: string})[]|nil
function M.border(self)
	if not M.is_border(self.opts.border) then
		return
	end

	if self.opts.border == true then
		local border ---@type string|string[]|nil
		pcall(function()
			border = vim.o.winborder
			border = border:find(",") and vim.split(border, ",") or border
		end)
		return M.is_border(border) and border or "rounded"
	end
	return self.opts.border --[[@as string|(string|{[1]: string, [2]: string})[] ]]
end

---@param self win
---@return {top: integer, right: integer, bottom: integer, left: integer}
function M.border_size(self)
	-- The array specifies the eight
	-- chars building up the border in a clockwise fashion
	-- starting with the top-left corner.
	-- { "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" }
	local border = self:border() or { "" }
	border = type(border) == "string" and borders[border] or border
	border = type(border) == "string" and { "x" } or border
	assert(type(border) == "table", "Invalid border type")
	---@cast border string[]
	while #border < 8 do
		vim.list_extend(border, border)
	end
	-- remove border hl groups
	border = vim.tbl_map(function(b)
		return type(b) == "table" and b[1] or b
	end, border)
	local function size(from, to)
		for i = from, to do
			if border[i] ~= "" then
				return 1
			end
		end
		return 0
	end
	---@type { top: number, right: number, bottom: number, left: number }
	return {
		top = size(1, 3),
		right = size(3, 5),
		bottom = size(5, 7),
		left = math.max(size(7, 8), size(1, 1)),
	}
end

---@param self win
---@return integer
function M.border_text_width(self)
	if not self:has_border() then
		return 0
	end
	local ret = 0
	for _, t in ipairs({ "title", "footer" }) do
		local str = self.opts[t] or {}
		str = type(str) == "string" and { str } or str
		---@cast str (string|string[])[]
		ret = math.max(ret, #table.concat(
			vim.tbl_map(function(s)
				return type(s) == "string" and s or s[1]
			end, str),
			""
		))
	end
	return ret
end

---@param parent? win.Dim
---@param self win
---@return win.Dim
function M.dim(self, parent)
	---@diagnostic disable-next-line: assign-type-mismatch
	parent = parent or self:parent_size()
	---@type win.Dim
	local ret = {
		height = 0,
		width = 0,
		col = 0,
		row = 0,
		border = self:has_border(),
	}

	---@param s? number|fun(win: win):number? size
	---@param ps number parent size
	local function size(s, ps, border_offset)
		s = type(s) == "function" and s(self) or s or 0
		---@cast s number
		if s == 0 then -- full size
			return ps - border_offset
		elseif s < 1 then -- relative size
			return math.floor(ps * s) - border_offset
		end
		return s
	end

	---@param p? integer|fun(win:win):integer? pos
	---@param s integer size
	---@param ps integer parent size
	local function pos(p, s, ps, border_from, border_to)
		p = type(p) == "function" and p(self) or p
		---@cast p number?
		if self.opts.relative == "cursor" then
			return p or 0
		end
		if not p then -- center
			return math.floor((ps - s) / 2) - border_from
		end
		---@cast p number
		if p < 0 then -- negative position
			return ps - s + p - border_from - border_to
		elseif p < 1 and p > 0 then -- relative position
			return math.floor(ps * p) + border_from
		end
		return p
	end

	local border = self:border_size()

	ret.height = size(self.opts.height, parent.height, border.top + border.bottom)
	ret.height = M.imax(ret.height, self.opts.min_height or 0, 1)
	ret.height = M.imin(ret.height, self.opts.max_height or ret.height, parent.height)
	ret.height = M.imax(ret.height, 1)

	ret.width = size(self.opts.width, parent.width, border.left + border.right)
	ret.width = M.imax(ret.width, self.opts.min_width or 0, 1)
	ret.width = M.imin(ret.width, self.opts.max_width or ret.width, parent.width)
	ret.width = M.imax(ret.width, 1)

	ret.row = pos(self.opts.row, ret.height, parent.height, border.top, border.bottom)
	ret.col = pos(self.opts.col, ret.width, parent.width, border.left, border.right)

	return ret
end

---@param ... number
---@return integer
function M.imax(...)
	return math.floor(math.max(...))
end

---@param ... number
---@return integer
function M.imin(...)
	return math.floor(math.min(...))
end

--- Calculate the next available zindex for windows.
--- New windows open on top of existing ones.
---@param opts? { zindex?: number, tab?: number|boolean, all?: boolean, max?: number }
---@overload fun(zindex: number): number
---@return number
function M.zindex(opts)
	opts = opts or {}
	---@diagnostic disable-next-line: assign-type-mismatch
	opts = type(opts) == "number" and { zindex = opts } or opts
	local zindex = opts.zindex or 50
	local max = opts.max or 100
	local wins = opts.tab == false and vim.api.nvim_list_wins()
		or vim.api.nvim_tabpage_list_wins(math.floor(tonumber(opts.tab) or 0))
	for _, win in ipairs(wins) do
		if opts.all ~= false or vim.w[win].aevre_win then
			local other = (vim.api.nvim_win_get_config(win).zindex or 0)
			-- ignore very high zindex windows, like notifications, completion, etc
			if other > zindex and other < max then
				zindex = math.max(zindex, other + 2) --[[@as number]]
			end
		end
	end
	return zindex
end

---@param self win
function M.equalize(self)
	if self:is_floating() then
		return
	end
	local all = vim.tbl_filter(function(win)
		return vim.w[win].aevre_win
			and vim.w[win].aevre_win.relative == self.opts.relative
			and vim.w[win].aevre_win.position == self.opts.position
	end, vim.api.nvim_tabpage_list_wins(0))
	if #all <= 1 then
		return
	end
	local vertical = self.opts.position == "left" or self.opts.position == "right"
	---@diagnostic disable-next-line: undefined-field
	local parent_size = self:parent_size()[vertical and "height" or "width"]
	---@diagnostic disable-next-line: need-check-nil
	local size = math.floor(parent_size / #all)
	for _, win in ipairs(all) do
		vim.api.nvim_win_call(win, function()
			vim.cmd(("%s resize %s"):format(vertical and "horizontal" or "vertical", size))
		end)
	end
end

return M
