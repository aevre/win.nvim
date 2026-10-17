# win.nvim

A standalone Neovim module for creating and managing floating windows and splits. It has no third-party dependencies and preserves the window object API from the original configuration module.

## Requirements

Neovim 0.9 or newer. Neovim 0.10+ is required for window footers; on older versions they are omitted as before.

## Installation

Add the repository to Neovim's `runtimepath` using your preferred plugin manager, or clone it into a runtime package directory. The module is loaded with `require("win")`; this plugin does not require a specific plugin manager.

## Setup

Setup is optional. Pass window fields directly:

```lua
require("win").setup({
  position = "float",
  width = 0.8,
  height = 0.8,
})
```

The returned module is callable and creates a window object:

```lua
local win = require("win")({
  position = "bottom",
  height = 12,
  text = "Window content",
  keys = { q = "close" },
})

win:toggle()
win:close()
```

Configuration options, style names (`float`, `help`, `split`, `minimal`), and object methods are documented in the Lua annotations in `lua/win/init.lua`. Common methods include `show`, `hide`, `toggle`, `focus`, `close`, `set_buf`, `on`, `set_title`, `dim`, `size`, `is_floating`, `lines`, and `text`. `win.style.add(name, defaults)` registers a reusable style.

## Original configuration migration

The former `builtin.win` module now forwards to `require("win")`. Existing `Builtin.win(...)`, terminal, and lazygit callers retain their API when this plugin is installed. Configure the new implementation through `require("win").setup(...)` or the existing builtin `win` options. Highlight groups use the `AevreWin*` prefix and can be overridden by the user's theme.
