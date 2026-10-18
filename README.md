# win.nvim

A standalone Neovim module for creating and managing floating windows and splits. No third-party dependencies required.

[简体中文](README.zh-CN.md)

- [Installation](#installation)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Styles](#styles)
- [Object API](#object-api)
- [Keys and actions](#keys-and-actions)
- [Backdrop](#backdrop)
- [Highlight groups](#highlight-groups)

## Requirements

- Neovim 0.9 or newer.
- Neovim 0.10 or newer for window footers. On older versions footers are omitted.

## Installation

The canonical repository is hosted on Codeberg: <https://codeberg.org/aevre/win.nvim>.

With lazy.nvim:

```lua
{
  "https://codeberg.org/aevre/win.nvim",
}
```

With packer.nvim:

```lua
use("https://codeberg.org/aevre/win.nvim")
```

Alternatively, clone the repository and add it to Neovim's `runtimepath`. The module is available as `require("win")`.

## Quick start

```lua
local Win = require("win")

local panel = Win({
  position = "float",
  width = 0.8,
  height = 0.7,
  border = "rounded",
  title = "Preview",
  text = { "Hello from win.nvim" },
  keys = {
    q = "close",
    ["<Esc>"] = "close",
  },
})
```

Instances open immediately by default. Use `Win.setup({ win = { ... } })` for shared defaults, then pass per-window overrides to `Win({...})`.

## Configuration

Neovim's `nvim_open_win()` fields are supported where applicable, including `relative`, `anchor`, `focusable`, `zindex`, `title`, and `title_pos`. Additional options:

| Option | Default | Description |
| --- | --- | --- |
| `style` | none | Name of a registered style to merge. |
| `show` | `true` | Open immediately when constructing the object. |
| `position` | `"float"` | `"float"`, `"top"`, `"right"`, `"bottom"`, `"left"`, or `"current"`. The directional positions create splits; `current` replaces the buffer in the current window. |
| `width`, `height` | float: `0.9`; split: `0.4` | Number or function receiving the window object. Values between 0 and 1 are fractions of the parent dimension; `0` fills it. |
| `row`, `col` | centered | Float position. Values between 0 and 1 are relative; negative values offset from the far edge. Functions are supported. |
| `min_width`, `max_width`, `min_height`, `max_height` | unset | Clamp calculated dimensions. |
| `border` | Neovim `winborder`, otherwise `"rounded"` | Border name, character array, `false`, or `"none"`. Named styles include `single`, `double`, `solid`, `shadow`, `bold`, `vertical`, `horizontal`, `top`, `right`, `bottom`, `left`, `top_bottom`, `hpad`, and `vpad`. |
| `relative` | `"editor"` | Parent for floats/splits: `"editor"`, `"win"`, `"cursor"`, or a supported split parent. `win` selects the parent window for `"win"` relative mode. |
| `enter` | `true` | Enter the created window. Set `false` to keep focus in the current window. `focusable = false` prevents entering. |
| `minimal` | `true` | Apply built-in minimal window options. |
| `backdrop` | float style: `60`; otherwise off | Dimming window behind a float. Set `false`, a blend number, or a table (see [Backdrop](#backdrop)). |
| `buf`, `file` | unset | Reuse a buffer or open a file read-only. Otherwise create a scratch buffer. |
| `text` | unset | Initial scratch text: string, string array, or function returning either. |
| `ft`, `scratch_ft` | unset | Highlighting language and scratch buffer filetype. `ft` does not override an existing filetype. |
| `bo`, `wo` | `{}` | Buffer-local and window-local options. `wo.winhighlight` also accepts a mapping table. |
| `b`, `w` | `{}` | Buffer-local and window-local variables. |
| `keys` | `{ q = "close" }` | Buffer-local mappings (see [Keys and actions](#keys-and-actions)). |
| `actions` | unset | Named actions available to mappings. |
| `footer_keys` | `false` | Show mappings in the footer (Neovim 0.10+). `true` shows all configured keys; an array filters them. |
| `resize` | `true` | Recalculate on editor resize. |
| `fixbuf` | `true` | Restore this instance's buffer if another buffer is opened in its window. |
| `stack` | `false` | Stack split windows with the same position. |
| `on_buf`, `on_win`, `on_close` | unset | Callbacks after buffer setup, after window setup, and during close. Each receives the window object. |

Setup deep-merges options. Defaults can be nested under `win` or supplied at the top level:

```lua
require("win").setup({
  win = { position = "bottom", height = 12, border = "top" },
})
```

## Styles

Built-in styles are `float`, `help`, `split`, and `minimal`. Instance options override style defaults. `minimal = true` applies the `minimal` style in addition to the selected position style.

```lua
local Win = require("win")
Win.style.add("picker", {
  position = "float",
  width = 0.6,
  height = 0.5,
  border = "single",
})
local picker = Win({ style = "picker", title = "Pick an item" })
```

`Win.style.add(name, defaults)` registers or updates a style. `Win.style.get(name)` and `Win.style(name)` return its config. `Win.resolve(...)` resolves style names and config tables.

## Object API

The module is callable (`Win(opts)`) and provides `Win.new(opts)`; both return a window object.

| Method | Description |
| --- | --- |
| `show()` | Create or reopen the window and return the object. |
| `hide()` | Close the window but retain its scratch buffer for reuse. |
| `close({ buf = false })` | Close the window. By default, the instance's scratch buffer is deleted; pass `buf = false` to retain it. User-supplied buffers are not wiped by this option. |
| `toggle()` | Hide a valid window or show it otherwise. |
| `destroy()` | Close the window and clear the object's events, mappings, and metadata. |
| `focus()` | Make the valid window current. |
| `valid()`, `win_valid()`, `buf_valid()` | Check the window/buffer association, window, or buffer validity. |
| `set_buf(buf)` | Set the buffer used by the window. |
| `set_title(title, pos)` | Set a bordered window title; `pos` is `"left"`, `"center"`, or `"right"`. |
| `on(event, callback, opts)` | Register an autocmd. Callback receives `(self, event_args)`; `opts.buf = true` or `opts.win = true` scopes it to this instance. |
| `size()` | Return calculated `{ width, height }`, including the border. |
| `dim(parent?)` | Return `{ width, height, row, col, border }`. |
| `is_floating()` | Check whether the valid window is floating. |
| `line(n)`, `lines(from?, to?)`, `text(from?, to?)` | Read buffer content. Line indices are 1-based and inclusive. |
| `update()` | Reapply options and recalculate a valid floating window. |
| `scroll(up?)`, `hscroll(left)`, `redraw()` | Scroll or redraw the window. |
| `action(names)`, `execute(names)` | Resolve or execute named actions. |
| `toggle_help(opts?)` | Toggle a help window listing normal/insert mappings and descriptions for the buffer. |
| `Win.zindex(opts?)` | Return the next available z-index. |

`hide()` retains the scratch buffer. `close()` wipes an instance-owned scratch buffer unless `{ buf = false }` is passed. The object can be reopened after closing; use `destroy()` only when it will not be reused.

## Keys and actions

`keys` maps lhs values to action names, callbacks, or key specifications. The default mode is normal; `mode` can be one mode or an array. `<Leader>` and `<LocalLeader>` use Neovim's current leader values.

```lua
local panel = require("win")({
  text = "Press x to refresh",
  keys = {
    q = "close",
    x = { "refresh", desc = "Refresh content", mode = { "n", "i" } },
  },
  actions = {
    refresh = function(self)
      self.opts.text = { "Updated" }
      self:scratch()
    end,
  },
})
```

An action can be `function(self) ... end` or `{ action = function(self) ... end, desc = "..." }`. A truthy return stops the action chain; returning a string displays a notification. Built-in method names such as `"close"`, `"hide"`, and `"toggle"` work as actions. Key specs may also use the `vim.keymap.set` tuple form `{ lhs, rhs, opts }`.

## Backdrop

`backdrop` accepts a blend percentage or a table:

```lua
require("win")({
  position = "float",
  backdrop = {
    bg = "#000000",
    blend = 60,
    transparent = true,
    win = { position = "float" },
  },
})
```

Table fields: `bg` (default `#000000`), `blend` (default `60`), `transparent` (default `true`), and `win` (backdrop-window overrides). A backdrop is only created for floats when `termguicolors` is enabled, blend is not `100`, and the current background/transparent settings allow it. A transparent `Normal` background with the default `transparent = true` skips the backdrop.

## Highlight groups

The plugin uses the `AevreWin*` prefix for window surfaces, title/footer, keys, separators, and backdrop. Define these groups after loading your colorscheme to customize the appearance. `wo.winhighlight` can override per-window highlight mappings.
