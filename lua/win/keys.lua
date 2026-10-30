---@class win.Mappings
local M = {}

local function normkey(key)
	local function norm(value)
		local lower = value:lower()
		if lower == "leader" then
			return normkey("<leader>")
		elseif lower == "localleader" then
			return normkey("<localleader>")
		end
		return vim.fn.keytrans(vim.api.nvim_replace_termcodes("<" .. value .. ">", true, true, true))
	end
	key = key:gsub("<lt>", "<")
	local lower = key:lower()
	if lower == "<leader>" or lower == "<localleader>" then
		local value = lower == "<leader>" and vim.g.mapleader or vim.g.maplocalleader
		key = vim.fn.keytrans(value and value ~= "" and value or "\\")
	else
		local extracted = {}
		local function extract(value)
			local token = value:sub(2, -2)
			if token:sub(2, 2) == "-" and token:sub(1, 1):find("[aAmMcCsS]") then
				local modifier, char = token:sub(1, 1):upper(), token:sub(3)
				modifier = modifier == "A" and "M" or modifier
				if #char > 1 then
					return norm(token)
				elseif modifier == "C" then
					char = char:upper()
				elseif modifier == "S" then
					return char:upper()
				end
				return ("<%s-%s>"):format(modifier, char)
			end
			return norm(token)
		end
		local placeholder = "_#_"
		key = key:gsub("(%b<>)", function(value)
			extracted[#extracted + 1] = extract(value)
			return placeholder
		end)
		key = vim.fn.keytrans(key):gsub("<lt>", "<")
		local index = 0
		key = key:gsub(placeholder, function()
			index = index + 1
			return extracted[index] or ""
		end)
	end
	return key
end

---@param opts win.Config
---@return win.Keys[]
function M.prepare(opts)
	local keys = {}
	local done = {} ---@type table<string, win.Keys?>
	opts.keys = opts.keys or {}
	for key, spec in pairs(opts.keys) do
		if spec then
			if type(spec) == "string" then
				spec = { key, spec, desc = spec }
			elseif type(spec) == "function" then
				spec = { key, spec }
			elseif type(spec) == "table" and spec[1] and not spec[2] then
				spec = vim.deepcopy(spec) -- deepcopy just in case
				spec[1], spec[2] = key, spec[1]
			end
			---@cast spec win.Keys
			local lhs = normkey(spec[1] or "")
			local mode = type(spec.mode) == "table" and spec.mode or { spec.mode or "n" }
			---@cast mode string[]
			mode = #mode == 0 and { "n" } or mode
			for _, m in ipairs(mode) do
				local k = m .. ":" .. lhs
				if done[k] then
					vim.notify(
						("# Duplicate key mapping for `%s` mode=%s (check case):\n```lua\n%s\n```\n```lua\n%s\n```"):format(
							lhs,
							m,
							vim.inspect(done[k]),
							vim.inspect(spec)
						)
					)
				end
				done[k] = spec
			end
			table.insert(keys, spec)
		end
	end
	-- last defined mapping is found first, so for `nowait` to work,
	-- we need to sort in reverse order
	table.sort(keys, function(a, b)
		return (a[1] or "") > (b[1] or "")
	end)

	return keys
end

---@param self win
function M.footer(self)
	if self.opts.footer_keys then
		self.opts.footer = {}
		table.sort(self.keys, function(a, b)
			return a[1] < b[1]
		end)
		local want = type(self.opts.footer_keys) == "table" and self.opts.footer_keys or nil
		---@cast want string[]|nil
		want = want and vim.tbl_map(normkey, want) or nil --[[@as string[]?]]
		for _, key in ipairs(self.keys) do
			local keymap = normkey(key[1] or "")
			if want == nil or vim.tbl_contains(want, keymap) then
				table.insert(self.opts.footer, { " ", "AevreWinFooter" })
				table.insert(self.opts.footer, { " " .. keymap .. " ", "AevreWinFooterKey" })
				table.insert(self.opts.footer, { " " .. (key.desc or keymap) .. " ", "AevreWinFooterDesc" })
			end
		end
		table.insert(self.opts.footer, { " ", "AevreWinFooter" })
	end
end

---@param actions string|string[]
---@param self win
---@return boolean|string|nil
function M.execute(self, actions)
	return self:action(actions)()
end

---@param actions string|string[]
---@return (fun(): boolean|string?) action, string? desc
---@param self win
function M.action(self, actions)
	actions = type(actions) == "string" and { actions } or actions
	---@cast actions string[]
	local desc = {} ---@type string[]
	for a, name in ipairs(actions) do
		desc[a] = name:gsub("_", " ")
		if self.opts.actions and self.opts.actions[name] then
			local action = self.opts.actions[name]
			desc[a] = type(action) == "table" and action.desc and action.desc or desc[a]
		end
	end
	return function()
		for _, name in ipairs(actions) do
			if self.opts.actions and self.opts.actions[name] then
				local a = self.opts.actions[name]
				local fn = type(a) == "function" and a or a.action
				local ret = fn(self)
				if ret then
					return type(ret) == "string" and ret or nil
				end
			elseif self[name] then
				self[name](self)
				return
			else
				return name
			end
		end
	end,
		table.concat(desc, ", ")
end

---@param opts? {col_width?: integer, key_width?: integer, win?: win.Config}
---@param self win
function M.toggle_help(self, opts)
	opts = opts or {}
	local col_width, key_width = opts.col_width or 30, opts.key_width or 10
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "win_help" then
			vim.api.nvim_win_close(win, true)
			return
		end
	end
	local ns = vim.api.nvim_create_namespace("win.help")
	local Win = require("win")
	local win = Win.new(Win.resolve({ style = "help" }, opts.win or {}, {
		show = false,
		focusable = false,
		zindex = (self.opts.zindex or 50) + 1,
		bo = { filetype = "win_help" },
	}))
	self:on("WinClosed", function()
		win:close()
	end, { win = true })
	self:on("BufLeave", function()
		win:close()
	end, { buf = true })
	local dim = win:dim()

	-- NOTE: we use the actual buffer keymaps instead of self.keys,
	-- since we want to show all keymaps, not just the ones we've defined on the window
	local keys = {} ---@type vim.api.keyset.get_keymap[]
	vim.list_extend(keys, vim.api.nvim_buf_get_keymap(self.buf, "n"))
	vim.list_extend(keys, vim.api.nvim_buf_get_keymap(self.buf, "i"))
	table.sort(keys, function(a, b)
		return (a.desc or a.lhs or "") < (b.desc or b.lhs or "")
	end)

	local done = {} ---@type table<string, boolean>
	keys = vim.tbl_filter(function(keymap)
		local key = normkey(keymap.lhs or "")
		if done[key] or (keymap.desc and keymap.desc:find("which%-key")) then
			return false
		end
		done[key] = true
		return true
	end, keys)

	local cols = math.floor((dim.width - 1) / col_width)
	local rows = math.ceil(#keys / cols)
	win.opts.height = rows
	local help = {} ---@type {[1]:string, [2]:string}[][]
	local row, col = 0, 1

	---@param str string
	---@param len integer
	---@param align? "left"|"right"
	local function trunc(str, len, align)
		local w = vim.api.nvim_strwidth(str)
		if w > len then
			return vim.fn.strcharpart(str, 0, len - 1) .. "…"
		end
		return align == "right" and (string.rep(" ", len - w) .. str) or (str .. string.rep(" ", len - w))
	end

	for _, keymap in ipairs(keys) do
		local key = normkey(keymap.lhs or "")
		row = row + 1
		if row > rows then
			row, col = 1, col + 1
		end
		help[row] = help[row] or {}
		vim.list_extend(help[row], {
			{ trunc(key, key_width, "right"), "AevreWinWinKey" },
			{ " " },
			{ "➜", "AevreWinWinKeySep" },
			{ " " },
			{ trunc(keymap.desc or "", col_width - key_width - 3), "AevreWinWinKeyDesc" },
		})
	end
	win:show()
	for l, line in ipairs(help) do
		vim.api.nvim_buf_set_lines(win.buf, l - 1, l, false, { "" })
		vim.api.nvim_buf_set_extmark(win.buf, ns, l - 1, 0, {
			virt_text = line,
			virt_text_pos = "overlay",
		})
	end
end

---@param self win
function M.map(self)
	if not self:buf_valid() then
		return
	end
	for _, spec in pairs(self.keys) do
		local opts = vim.tbl_extend("force", {}, spec)
		opts[1] = nil
		opts[2] = nil
		opts.mode = nil
		opts.buffer = self.buf
		opts.nowait = true
		local rhs = spec[2]
		local is_action = type(rhs) == "string" or type(rhs) == "table"
		if is_action then
			local desc = spec.desc
			---@diagnostic disable-next-line: param-type-mismatch
			rhs, desc = self:action(rhs)
			opts.desc = opts.desc or desc
		else
			rhs = function()
				return spec[2](self)
			end
		end
		spec.desc = spec.desc or opts.desc
		---@diagnostic disable-next-line: param-type-mismatch
		---@cast spec win.Keys
		vim.keymap.set(spec.mode or "n", spec[1], rhs, opts)
	end
end

return M
