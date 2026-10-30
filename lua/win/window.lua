---@class win.Window
local M = {}

local set_options = require("win.config").set_options
local transparent = require("win.appearance").transparent
local keys = require("win.keys")

local event_stack = {} ---@type string[]

---@param event string|string[]
---@param cb fun(self: win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?
---@param opts? win.Event
---@param self win
function M.on(self, event, cb, opts)
	opts = opts or {}
	opts.callback = cb
	table.insert(self.events, vim.tbl_extend("keep", { event = event }, opts))
	if self:valid() then
		self:_on(event, opts)
	end
end

---@param event string|string[]
---@param opts win.Event
---@param self win
function M._on(self, event, opts)
	local event_opts = {} ---@type vim.api.keyset.create_autocmd
	local skip = { "buf", "win", "event" }
	for k, v in pairs(opts) do
		if not vim.tbl_contains(skip, k) then
			---@diagnostic disable-next-line: assign-type-mismatch
			event_opts[k] = v
		end
	end
	event_opts.group = event_opts.group or self.augroup
	event_opts.callback = function(ev)
		table.insert(event_stack, ev.event)
		---@diagnostic disable-next-line: param-type-mismatch
		local ok, err = pcall(opts.callback, self, ev)
		table.remove(event_stack)
		---@diagnostic disable-next-line: return-type-mismatch
		return not ok and error(err) or err
	end
	if not event_opts.pattern and not event_opts.buffer then
		if opts.win then
			event_opts.pattern = self.win .. ""
		elseif opts.buf then
			event_opts.buffer = self.buf
		end
	end
	---@diagnostic disable-next-line: param-type-mismatch
	vim.api.nvim_create_autocmd(event, event_opts)
end

local SCROLL_UP = vim.api.nvim_replace_termcodes("<c-y>", true, true, true)
local SCROLL_DOWN = vim.api.nvim_replace_termcodes("<c-e>", true, true, true)

local split_commands = {
	editor = {
		top = "topleft",
		right = "vertical botright",
		bottom = "botright",
		left = "vertical topleft",
	},
	win = {
		top = "aboveleft",
		right = "vertical rightbelow",
		bottom = "belowright",
		left = "vertical leftabove",
	},
}

---@param self win
function M.on_resize(self)
	if self.opts.resize ~= false then
		self:update()
	end
end

---@param self win
function M.focus(self)
	if self:valid() then
		vim.api.nvim_set_current_win(self.win)
	end
end

---@param self win
function M.redraw(self)
	if vim.api.nvim__redraw then
		vim.api.nvim__redraw({ win = self.win, valid = false, flush = true, cursor = false })
	else
		vim.cmd("redraw")
	end
end

---@param self win
---@param left? boolean
function M.hscroll(self, left)
	vim.api.nvim_win_call(self.win, function()
		vim.cmd(("normal! %s"):format(left and "zh" or "zl"))
	end)
end

---@param up? boolean
---@param self win
function M.scroll(self, up)
	vim.api.nvim_win_call(self.win, function()
		vim.cmd(("normal! %d%s"):format(vim.wo[self.win].scroll, up and SCROLL_UP or SCROLL_DOWN))
	end)
end

---@param self win
function M.destroy(self)
	pcall(function()
		self:close()
	end)
	self.events = {}
	self.keys = {}
	self.meta = {}
	-- self.opts = {}
end

---@param opts? { buf: boolean }
---@param self win
function M.close(self, opts)
	---@diagnostic disable-next-line: assign-type-mismatch
	opts = opts or {}
	local wipe = opts.buf ~= false and self.buf == self.scratch_buf

	local win = self.win
	local buf = wipe and self.buf
	local scratch_buf = self.scratch_buf ~= self.buf and self.scratch_buf or nil
	self:on_close()

	local close = function()
		local errors = {} ---@type string[]
		local window_closed = not (win and vim.api.nvim_win_is_valid(win))
		if not window_closed then
			local ok, err = pcall(vim.api.nvim_win_close, win, true)
			if ok then
				window_closed = true
			elseif err and err:find("E444") then
				-- last window, so creat a split and close it again
				vim.cmd("silent! vsplit")
				window_closed = pcall(vim.api.nvim_win_close, win, true)
				if not window_closed then
					errors[#errors + 1] = err
				end
			else
				---@diagnostic disable-next-line: assign-type-mismatch
				errors[#errors + 1] = err
			end
		end
		if window_closed and buf and vim.api.nvim_buf_is_valid(buf) then
			local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
			errors[#errors + 1] = not ok and err or nil
		end
		if window_closed and scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
			local ok, err = pcall(vim.api.nvim_buf_delete, scratch_buf, { force = true })
			errors[#errors + 1] = not ok and err or nil
		end
		if #errors > 0 then
			error(table.concat(errors, "\n"))
		end
		self.win = nil
		if scratch_buf then
			self.scratch_buf = nil
		end
		if buf then
			self.buf = nil
		end
		if self.augroup then
			pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
			self.augroup = nil
		end
	end
	local retries = 0
	local try_close ---@type fun()
	try_close = function()
		local ok, err = pcall(close)
		if ok or not err then
			return
		end

		-- command window is open
		if err:find("E11") then
			vim.defer_fn(try_close, 200)
			return
		end

		-- text lock
		if err:find("E565") and retries < 20 then
			retries = retries + 1
			vim.defer_fn(try_close, 50)
			return
		end

		if not ok then
			vim.notify("Failed to close window: " .. err, vim.log.levels.ERROR)
		end
	end
	-- HACK: WinClosed is not recursive, so we need to schedule it
	-- if we're in a WinClosed event
	if vim.tbl_contains(event_stack, "WinClosed") or not pcall(close) then
		vim.schedule(try_close)
	end
end

---@param self win
---@return win
function M.hide(self)
	self:close({ buf = false })
	return self
end

---@param self win
---@return win
function M.toggle(self)
	if self:valid() then
		self:hide()
	else
		self:show()
	end
	return self
end

---@param title string|{[1]:string, [2]:string}[]
---@param pos? "center"|"left"|"right"
---@param self win
function M.set_title(self, title, pos)
	if not self:has_border() then
		return
	end
	if type(title) == "string" then
		title = vim.trim(title)
		if title ~= "" then
			-- HACK: add extra space when last char is non word
			-- like for icons etc
			if not title:sub(-1):match("%w") then
				title = title .. " "
			end
			title = " " .. title .. " "
		end
	elseif #title == 0 then
		title = ""
	end
	pos = pos or self.opts.title_pos or "center"
	if vim.deep_equal(self.opts.title, title) and self.opts.title_pos == pos then
		return
	end
	self.opts.title = title
	self.opts.title_pos = pos
	if not self:valid() then
		return
	end
	-- Don't try to update if the relative window is invalid.
	-- It will be fixed once a full update is done.
	local relative_win = vim.api.nvim_win_get_config(self.win).win
	if relative_win and not vim.api.nvim_win_is_valid(relative_win) then
		return
	end
	vim.api.nvim_win_set_config(self.win, {
		title = self.opts.title,
		title_pos = self.opts.title_pos,
	})
end

---@param self win
function M.open_win(self)
	local relative = self.opts.relative or "editor"
	local position = self.opts.position or "float"
	local enter = self.opts.enter == nil or self.opts.enter or false
	if self.opts.focusable == false then
		enter = false
	end
	local opts = self:win_opts()
	if position == "float" then
		self.win = vim.api.nvim_open_win(self.buf, enter, opts)
	elseif position == "current" then
		self.win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(self.win, self.buf)
	else --split
		local parent = self.opts.win and vim.api.nvim_win_is_valid(self.opts.win) and self.opts.win or 0
		local vertical = position == "left" or position == "right"
		-- When stacking is enabled, find an existing window with the same relative/position
		-- and stack the new window perpendicular to it instead of creating a new split
		if parent == 0 and self.opts.stack then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if
					vim.w[win].aevre_win
					and vim.w[win].aevre_win.relative == relative
					and vim.w[win].aevre_win.position == position
					and vim.w[win].aevre_win.stack == true
				then
					parent = win
					relative = "win"
					position = vertical and "bottom" or "right"
					vertical = not vertical
					break
				end
			end
		end
		---@diagnostic disable-next-line: need-check-nil
		local cmd = split_commands[relative][position]
		local size = vertical and opts.width or opts.height
		local resize = ("%sresize %s"):format(vertical and "vertical " or "", size)
		vim.api.nvim_win_call(parent, function()
			vim.cmd("silent noswapfile " .. cmd .. " sbuffer " .. self.buf .. " | " .. resize)
			self.win = vim.api.nvim_get_current_win()
		end)
		if enter then
			vim.api.nvim_set_current_win(self.win)
		end
		vim.schedule(function()
			self:equalize()
		end)
	end
	vim.w[self.win].aevre_win = {
		id = self.id,
		position = self.opts.position,
		relative = self.opts.relative,
		stack = self.opts.stack,
	}
end

---@param self win
function M.update(self)
	if self:valid() then
		set_options(self.buf, self.win, self.opts.bo, {})
		set_options(self.buf, self.win, {}, self.opts.wo)
		if self:is_floating() then
			local opts = self:win_opts()
			opts.noautocmd = nil
			vim.api.nvim_win_set_config(self.win, opts)
		end
	end
end

---@param self win
---@return boolean?
function M.on_current_tab(self)
	return self:win_valid() and vim.api.nvim_get_current_tabpage() == vim.api.nvim_win_get_tabpage(self.win)
end

---@param self win
---@return win
function M.show(self)
	if self:valid() then
		self:update()
		return self
	end
	self.augroup = vim.api.nvim_create_augroup("aevre_win_" .. self.id, { clear = true })

	self:open_buf()

	-- buffer local variables
	for k, v in pairs(self.opts.b or {}) do
		vim.b[self.buf][k] = v
	end

	-- OPTIM: prevent treesitter or syntax highlighting to attach on FileType if it's not already enabled
	local optim_hl = not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == ""
	vim.b[self.buf].ts_highlight = optim_hl or vim.b[self.buf].ts_highlight
	set_options(self.buf, self.win, self.opts.bo, {})
	vim.b[self.buf].ts_highlight = not optim_hl and vim.b[self.buf].ts_highlight or nil

	if self.opts.on_buf then
		self.opts.on_buf(self)
	end

	keys.footer(self)
	self:open_win()
	self.closed = false
	-- window local variables
	for k, v in pairs(self.opts.w or {}) do
		vim.w[self.win][k] = v
	end
	if transparent() then
		---@diagnostic disable-next-line: need-check-nil
		self.opts.wo.winblend = 0
	end
	set_options(self.buf, self.win, {}, self.opts.wo)
	if self.opts.on_win then
		self.opts.on_win(self)
	end

	-- syntax highlighting
	local ft = self.opts.ft or vim.bo[self.buf].filetype
	if ft and not ft:find("^core_") and not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == "" then
		local lang = vim.treesitter.language.get_lang(ft)
		if not (lang and pcall(vim.treesitter.start, self.buf, lang)) then
			vim.bo[self.buf].syntax = ft
		end
	end

	for _, event in ipairs(self.events) do
		---@diagnostic disable-next-line: param-type-mismatch
		self:_on(event.event, event)
	end

	-- swap buffers when opening a new buffer in the same window
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = self.augroup,
		nested = true,
		callback = function()
			return self:fixbuf()
		end,
	})

	self:map()
	self:drop()

	return self
end

---@param self win
function M.on_close(self)
	-- close the backdrop
	if self.backdrop then
		self.backdrop:close()
		self.backdrop = nil
	end
	if self.closed then
		return
	end
	self.closed = true
	if self.opts.on_close then
		self.opts.on_close(self)
	end
	-- Go back to the previous window when closing,
	-- and it's the current window
	if vim.api.nvim_get_current_win() == self.win then
		pcall(vim.cmd.wincmd, "p")
	end
end

---@param self win
function M.add_padding(self)
	---@diagnostic disable-next-line: need-check-nil
	local listchars = vim.split(self.opts.wo.listchars or "", ",")
	listchars = vim.tbl_filter(function(s)
		return not s:find("eol:") and s ~= ""
	end, listchars)
	table.insert(listchars, "eol: ")
	---@diagnostic disable-next-line: need-check-nil
	self.opts.wo.listchars = table.concat(listchars, ",")
	---@diagnostic disable-next-line: need-check-nil
	self.opts.wo.list = true
	---@diagnostic disable-next-line: need-check-nil
	self.opts.wo.statuscolumn = " "
end

---@param self win
---@return boolean?
function M.is_floating(self)
	return self:valid() and vim.api.nvim_win_get_config(self.win).zindex ~= nil
end

---@param self win
---@return boolean?
function M.win_valid(self)
	return self.win and vim.api.nvim_win_is_valid(self.win)
end

---@param self win
---@return boolean?
function M.valid(self)
	return self:win_valid() and self:buf_valid() and vim.api.nvim_win_get_buf(self.win) == self.buf
end

return M
