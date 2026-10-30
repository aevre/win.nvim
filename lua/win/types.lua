---@class win.Window
---@class win.Buffer
---@class win.Layout
---@class win.Mappings
---@class win.Appearance

---@alias win.Border string|(string|{[1]: string, [2]: string})[]|boolean

---@class win.WindowOptions: vim.wo
---@field winhighlight? string|table<string, string>

---@class win.Setup
---@field win? win.Config

---@class win.Keys: vim.api.keyset.keymap
---@field [1]? string
---@field [2]? string|string[]|fun(self: win): string?
---@field mode? string|string[]

---@class win.Event: vim.api.keyset.create_autocmd
---@field buf? true
---@field win? true
---@field callback? fun(self: win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?

---@class win.Backdrop
---@field bg? string
---@field blend? integer
---@field transparent? boolean defaults to true
---@field win? win.Config overrides the backdrop window config

---@class win.Dim
---@field width integer width of the window, without borders
---@field height integer height of the window, without borders
---@field row integer row of the window (0-indexed)
---@field col integer column of the window (0-indexed)
---@field border? boolean whether the window has a border

---@alias win.Action.fn fun(self: win):(boolean|string?)
---@alias win.Action.spec win.Action|win.Action.fn
---@class win.Action
---@field action win.Action.fn
---@field desc? string

---@class win.Config: vim.api.keyset.win_config
---@field style? string
---@field show? boolean Show the window immediately (default: true)
---@field footer_keys? boolean|string[] Show keys footer. When string[], only show those keys with lhs (default: false)
---@field height? number|fun(self:win):number Height of the window. Use <1 for relative height. 0 means full height. (default: 0.9)
---@field width? number|fun(self:win):number Width of the window. Use <1 for relative width. 0 means full width. (default: 0.9)
---@field min_height? integer Minimum height of the window
---@field max_height? integer Maximum height of the window
---@field min_width? integer Minimum width of the window
---@field max_width? integer Maximum width of the window
---@field col? number|fun(self:win):number Column of the window. Use <1 for relative column. (default: center)
---@field row? number|fun(self:win):number Row of the window. Use <1 for relative row. (default: center)
---@field minimal? boolean Disable a bunch of options to make the window minimal (default: true)
---@field position? "float"|"bottom"|"top"|"left"|"right"|"current"
---@field border? win.Border
---@field buf? integer If set, use this buffer instead of creating a new one
---@field file? string If set, use this file instead of creating a new buffer
---@field enter? boolean Enter the window after opening (default: true)
---@field backdrop? integer|boolean|win.Backdrop Opacity of the backdrop (default: 60)
---@field wo? win.WindowOptions window options
---@field bo? vim.bo|{} buffer options
---@field b? table<string, any> buffer local variables
---@field w? table<string, any> window local variables
---@field ft? string filetype to use for treesitter/syntax highlighting. Won't override existing filetype
---@field scratch_ft? string filetype to use for scratch buffers
---@field keys? table<string, false|string|fun(self: win)|win.Keys> Key mappings
---@field on_buf? fun(self: win) Callback after opening the buffer
---@field on_win? fun(self: win) Callback after opening the window
---@field on_close? fun(self: win) Callback after closing the window
---@field fixbuf? boolean don't allow other buffers to be opened in this window
---@field text? string|string[]|fun():(string[]|string) Initial lines to set in the buffer
---@field actions? table<string,  win.Action.spec> Actions that can be used in key mappings
---@field resize? boolean Automatically resize the window when the editor is resized
---@field stack? boolean When enabled, multiple split windows with the same position will be stacked together (useful for terminals)
