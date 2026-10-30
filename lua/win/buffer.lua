---@class win.Buffer
local M = {}

local set_options = require("win.config").set_options

---@param self win
---@return integer
function M.open_buf(self)
	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		-- keep existing buffer
		self.buf = self.buf
	elseif self.scratch_buf and vim.api.nvim_buf_is_valid(self.scratch_buf) then
		-- keep existing scratch buffer
		self.buf = self.scratch_buf
	elseif self.opts.file then
		self.buf = vim.fn.bufadd(self.opts.file)
		if not vim.api.nvim_buf_is_loaded(self.buf) then
			vim.bo[self.buf].readonly = true
			vim.bo[self.buf].swapfile = false
			vim.fn.bufload(self.buf)
			vim.bo[self.buf].modifiable = false
		end
	elseif self.opts.buf then
		self.buf = self.opts.buf
	else
		self:scratch()
	end
	return self.buf
end

---@param self win
function M.scratch(self)
	if self.buf == self.scratch_buf and self:buf_valid() then
		return
	end
	self.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[self.buf].swapfile = false
	self.scratch_buf = self.buf
	local text = type(self.opts.text) == "function" and self.opts.text() or self.opts.text
	text = type(text) == "string" and vim.split(text, "\n") or text
	if text then
		---@cast text string[]
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text)
	end
	---@diagnostic disable-next-line: need-check-nil
	if not self.opts.bo.filetype then
		if self.opts.scratch_ft then
			vim.bo[self.buf].filetype = self.opts.scratch_ft
		else
			---@diagnostic disable-next-line: need-check-nil
			vim.bo[self.buf].filetype = self.opts.bo.filetype or "aevre_win"
		end
		vim.bo[self.buf].syntax = ""
	end
	if self:win_valid() then
		vim.api.nvim_win_set_buf(self.win, self.buf)
	end
end

---@param self win
---@return boolean?
function M.fixbuf(self)
	-- window closes, so delete the autocmd
	if not self:win_valid() then
		return true
	end

	if not self:buf_valid() then
		return
	end

	if not self:on_current_tab() then
		return
	end

	local buf = vim.api.nvim_win_get_buf(self.win)

	-- same buffer
	if buf == self.buf then
		return
	end

	-- don't swap if fixbuf is disabled
	if self.opts.fixbuf == false then
		self.buf = buf
		-- update window options
		set_options(self.buf, self.win, {}, self.opts.wo)
		return
	end

	-- another buffer was opened in this window
	-- find another window to swap with
	local main ---@type integer?
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local win_buf = vim.api.nvim_win_get_buf(win)
		local is_float = vim.api.nvim_win_get_config(win).zindex ~= nil
		if win ~= self.win and not is_float then
			if vim.bo[win_buf].buftype == "" or vim.b[win_buf].core_main or vim.w[win].core_main then
				main = win
				break
			end
		end
	end

	if main then
		vim.api.nvim_win_set_buf(self.win, self.buf)
		vim.api.nvim_win_set_buf(main, buf)
		vim.api.nvim_set_current_win(main)
		vim.cmd.stopinsert()
	else
		-- no main window found, so close this window
		vim.api.nvim_win_set_buf(self.win, self.buf)
		vim.schedule(function()
			vim.cmd.stopinsert()
			vim.cmd("sbuffer " .. buf)
			if self.win and vim.api.nvim_win_is_valid(self.win) then
				vim.api.nvim_win_close(self.win, true)
			end
		end)
	end
end

---@param buf integer
---@param self win
function M.set_buf(self, buf)
	assert(self:valid(), "Window is not valid")
	self.buf = buf
	vim.api.nvim_win_set_buf(self.win, buf)
	set_options(self.buf, self.win, {}, self.opts.wo)
end

---@param self win
---@param line integer
---@return string
function M.line(self, line)
	return self:lines(line, line)[1] or ""
end

---@param from? integer 1-indexed, inclusive
---@param to? integer 1-indexed, inclusive
---@param self win
---@return string[]
function M.lines(self, from, to)
	return self:buf_valid() and vim.api.nvim_buf_get_lines(self.buf, from and from - 1 or 0, to or -1, false) or {}
end

---@param from? integer 1-indexed, inclusive
---@param to? integer 1-indexed, inclusive
---@param self win
---@return string
function M.text(self, from, to)
	return table.concat(self:lines(from, to), "\n")
end

---@param self win
---@return boolean?
function M.buf_valid(self)
	return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

return M
