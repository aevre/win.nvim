---@class win: win.Window, win.Buffer, win.Layout, win.Mappings, win.Appearance
---@field id integer
---@field buf? integer
---@field scratch_buf? integer
---@field win? integer
---@field opts win.Config
---@field augroup? integer
---@field backdrop? win
---@field keys win.Keys[]
---@field events (win.Event|{event:string|string[]})[]
---@field meta table<string, any>
---@field closed? boolean
---@overload fun(opts? :win.Config|{}): win
---@type win
local M = setmetatable({}, {
	__call = function(t, ...)
		return t.new(...)
	end,
})
M.__index = M

M.meta = {
	desc = "Create and manage floating windows or splits",
}

local config = require("win.config")
M.style = require("win.style")
M.resolve = config.resolve

local layout = require("win.layout")
M.parent_size = layout.parent_size
M.win_opts = layout.win_opts
M.size = layout.size
M.has_border = layout.has_border
M.is_border = layout.is_border
M.border = layout.border
M.border_size = layout.border_size
M.border_text_width = layout.border_text_width
M.dim = layout.dim
M.imax = layout.imax
M.imin = layout.imin
M.zindex = layout.zindex
M.equalize = layout.equalize

local buffer = require("win.buffer")
M.open_buf = buffer.open_buf
M.scratch = buffer.scratch
M.fixbuf = buffer.fixbuf
M.set_buf = buffer.set_buf
M.line = buffer.line
M.lines = buffer.lines
M.text = buffer.text
M.buf_valid = buffer.buf_valid

local keys = require("win.keys")
M.execute = keys.execute
M.action = keys.action
M.toggle_help = keys.toggle_help
M.map = keys.map

local appearance = require("win.appearance")
M.drop = appearance.drop

local window = require("win.window")
M.on = window.on
M._on = window._on
M.on_resize = window.on_resize
M.focus = window.focus
M.redraw = window.redraw
M.hscroll = window.hscroll
M.scroll = window.scroll
M.destroy = window.destroy
M.close = window.close
M.hide = window.hide
M.toggle = window.toggle
M.set_title = window.set_title
M.open_win = window.open_win
M.update = window.update
M.on_current_tab = window.on_current_tab
M.show = window.show
M.on_close = window.on_close
M.add_padding = window.add_padding
M.is_floating = window.is_floating
M.win_valid = window.win_valid
M.valid = window.valid

---@param opts? win.Setup|win.Config
---@return win
function M.setup(opts)
	config.setup(opts)
	return M
end

local id = 0

---@param opts? win.Config|{}
---@return win
function M.new(opts)
	local self = setmetatable({}, M)
	id = id + 1
	self.id = id
	self.meta = {}
	opts = config.get(opts)
	self.keys = keys.prepare(opts)
	self.events = {}

	self:on("WinClosed", self.on_close, { win = true })
	self:on("WinResized", function()
		if self.backdrop and not self:is_floating() then
			self.backdrop:close()
			self.backdrop = nil
		end
	end)

	-- update window size when resizing
	self:on("VimResized", self.on_resize)

	---@cast opts win.Config
	self.opts = opts
	if opts.show ~= false then
		self:show()
	end
	return self
end

return M
