local Win = require("win")
local api = vim.api

local function flush()
	vim.wait(20, function()
		return false
	end)
end

local function test()
	vim.o.termguicolors = true
	api.nvim_set_hl(0, "Normal", { bg = "#202020" })
	assert(Win.setup({ win = { enter = false, backdrop = false } }) == Win)
	Win.setup({ win = { width = 30 } })
	vim.cmd("runtime plugin/win.lua")
	vim.cmd("runtime plugin/win.lua")
	assert(#api.nvim_get_autocmds({ group = "aevre_win_highlights" }) == 1)

	Win.style.add("test", { height = 5, border = "single" })
	assert(Win.style("test").height == 5)
	assert(Win.resolve("test", { height = 6 }).height == 6)
	local calls = {}
	local panel = Win({
		style = "test",
		show = false,
		text = { "one", "two" },
		wo = { winhighlight = { Normal = "NormalFloat" }, winblend = 13 },
		on_buf = function()
			calls[#calls + 1] = "buf"
		end,
		on_win = function()
			calls[#calls + 1] = "win"
		end,
		on_close = function()
			calls[#calls + 1] = "close"
		end,
		keys = { x = { "mark", desc = "Mark", mode = { "n", "i" } } },
		actions = {
			mark = function(self)
				self.meta.marked = true
				return true
			end,
		},
		footer_keys = { "x" },
	})
	assert(not panel:valid())
	assert(panel.opts.width == 30 and panel.opts.height == 5)
	local current = api.nvim_get_current_win()
	assert(panel:show() == panel and panel:valid())
	assert(api.nvim_get_current_win() == current)
	assert(table.concat(calls, ",") == "buf,win")
	assert(panel:text() == "one\ntwo" and panel:line(2) == "two")
	assert(vim.wo[panel.win].winblend == 13)
	assert(vim.wo[panel.win].winhighlight == "Normal:NormalFloat")
	assert(#api.nvim_buf_get_keymap(panel.buf, "i") == 1)
	panel:execute("mark")
	assert(panel.meta.marked)
	assert(panel:execute("unhandled") == "unhandled")
	if vim.fn.has("nvim-0.10") == 1 then
		assert(#api.nvim_win_get_config(panel.win).footer > 0)
	end
	panel:set_title("Preview")
	assert(panel.opts.title == " Preview ")
	panel:toggle_help()
	assert(#api.nvim_tabpage_list_wins(0) == 3)
	panel:toggle_help()
	flush()
	assert(#api.nvim_tabpage_list_wins(0) == 2)

	local buf = panel.buf
	panel:hide()
	assert(not panel:win_valid() and api.nvim_buf_is_valid(buf))
	assert(table.concat(calls, ",") == "buf,win,close")
	panel:show()
	assert(panel.buf == buf and panel:valid())
	panel.opts.width = 24
	api.nvim_exec_autocmds("VimResized", {})
	assert(api.nvim_win_get_width(panel.win) == 24)
	panel:close()
	assert(not api.nvim_buf_is_valid(buf))
	panel:show()
	assert(panel:valid() and panel.buf ~= buf)
	panel:destroy()
	assert(#panel.keys == 0 and #panel.events == 0)

	local user_buf = api.nvim_create_buf(false, true)
	local user = Win({ buf = user_buf })
	user:close()
	assert(api.nvim_buf_is_valid(user_buf))
	local swap = Win({ text = "owned" })
	local owned = swap.buf
	swap:set_buf(user_buf)
	swap:close()
	assert(api.nvim_buf_is_valid(user_buf) and not api.nvim_buf_is_valid(owned))
	api.nvim_buf_delete(user_buf, { force = true })

	local float = Win({ backdrop = { blend = 40 }, wo = { winblend = 17 } })
	assert(float.backdrop and float.backdrop:valid())
	assert(vim.wo[float.win].winblend == 17)
	assert(vim.wo[float.backdrop.win].winblend == 40)
	local drop_buf = float.backdrop.buf
	float:close()
	assert(not api.nvim_buf_is_valid(drop_buf))

	local external = Win({})
	local closes = 0
	external.opts.on_close = function()
		closes = closes + 1
	end
	external:on("WinClosed", function(self)
		self:close()
	end, { win = true })
	local external_buf = external.buf
	api.nvim_win_close(external.win, true)
	flush()
	assert(closes == 1 and not api.nvim_buf_is_valid(external_buf))

	for _, position in ipairs({ "top", "right", "bottom", "left" }) do
		local split = Win({ position = position, width = 12, height = 4 })
		assert(split:valid() and not split:is_floating())
		split:hide()
		split:show()
		assert(split:valid())
		flush()
		split:close()
	end
	local original_buf = api.nvim_get_current_buf()
	local in_place = Win({ position = "current" })
	assert(in_place.win == current and in_place:valid())
	in_place:hide()
	assert(in_place:buf_valid())
	in_place:close()
	api.nvim_win_set_buf(0, original_buf)

	local layout = Win({ show = false, width = 0.5, height = 0.5, border = "single" })
	local dim = layout:dim({ width = 80, height = 24 })
	assert(dim.width == 38 and dim.height == 10 and dim.col == 20 and dim.row == 6)
	assert(layout:has_border() and layout:border_size().left == 1)
	local parent = api.nvim_get_current_win()
	local relative = Win({ relative = "win", width = 10, height = 3 })
	assert(relative.opts.win == parent)
	relative:close()
	api.nvim_exec_autocmds("ColorScheme", {})
	assert(api.nvim_get_hl(0, { name = "AevreWinNormal", link = true }).link == "NormalFloat")
	flush()
end

local ok, err = xpcall(test, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
end
print("win.nvim smoke tests passed")
vim.cmd("qa!")
