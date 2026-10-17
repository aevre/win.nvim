# win.nvim

`win.nvim` 是一个独立的 Neovim Lua 模块，用于创建和管理浮动窗口及分屏窗口。没有第三方依赖，也不依赖特定插件管理器。

[English](README.md)

## 环境要求

- Neovim 0.9 或更新版本。
- 窗口 footer 需要 Neovim 0.10 或更新版本；旧版本会忽略 footer。

## 安装

项目托管于 Codeberg：<https://codeberg.org/aevre/win.nvim>。

lazy.nvim：

```lua
{
  "https://codeberg.org/aevre/win.nvim",
}
```

packer.nvim：

```lua
use("https://codeberg.org/aevre/win.nvim")
```

也可以自行克隆仓库并加入 Neovim 的 `runtimepath`。模块名为 `require("win")`。

## 快速开始

```lua
local Win = require("win")

local panel = Win({
  position = "float",
  width = 0.8,
  height = 0.7,
  border = "rounded",
  title = "预览",
  text = { "你好，win.nvim" },
  keys = {
    q = "close",
    ["<Esc>"] = "close",
  },
})

panel:toggle()
```

创建对象时默认立即显示窗口。设置 `show = false` 可先配置实例再打开。使用 `Win.setup({ win = { ... } })` 设置所有实例共享的默认值，并可在 `Win({...})` 中覆盖。

## 配置项

适用时也支持 Neovim `nvim_open_win()` 的标准窗口配置字段，包括 `relative`、`anchor`、`focusable`、`zindex`、`title` 和 `title_pos`。以下是 `win.nvim` 扩展选项。

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `style` | 无 | 合并已注册的样式配置。 |
| `show` | `true` | 构造对象时立即打开窗口。 |
| `position` | `"float"` | `"float"`、`"top"`、`"right"`、`"bottom"`、`"left"` 或 `"current"`。除 float、current 外会创建分屏；`current` 在当前窗口中替换 buffer。 |
| `width`、`height` | float：`0.9`；split：`0.4` | 数字或接收窗口对象的函数。0 到 1 之间表示父窗口尺寸的比例；`0` 表示占满父窗口。分屏的宽高对应分屏方向。 |
| `row`、`col` | 居中 | 浮动窗口位置。0 到 1 之间表示相对位置；负数表示从另一侧边缘偏移。也支持接收窗口对象的函数。 |
| `min_width`、`max_width`、`min_height`、`max_height` | 未设置 | 限制计算后的尺寸范围。 |
| `border` | 继承 Neovim `winborder`，否则为 `"rounded"` | 边框样式、Neovim 边框字符数组、`false` 或 `"none"`。命名样式包括 `single`、`double`、`solid`、`shadow`、`bold`、`vertical`、`horizontal`、`top`、`right`、`bottom`、`left`、`top_bottom`、`hpad` 和 `vpad`。 |
| `relative` | `"editor"` | 浮窗或分屏的父级：`"editor"`、`"win"`、`"cursor"` 或支持的分屏父级。使用 `"win"` 时，通过 `win` 指定父窗口，默认当前窗口。 |
| `enter` | `true` | 打开后进入该窗口。设为 `false` 可保留当前焦点；`focusable = false` 时不能进入。 |
| `minimal` | `true` | 应用内置的精简窗口选项；设为 `false` 保留常规窗口选项。 |
| `backdrop` | float 样式为 `60`；其他情况关闭 | 在浮动窗口后创建调暗背景的窗口。`false` 关闭；数字表示 blend；也可以传表（见下文）。 |
| `buf`、`file` | 未设置 | 复用指定 buffer，或以只读方式打开文件。两者都未设置时创建 scratch buffer。 |
| `text` | 未设置 | scratch buffer 的初始内容，可传字符串、字符串数组或返回以上类型的函数。 |
| `ft`、`scratch_ft` | 未设置 | `ft` 指定语法高亮语言；`scratch_ft` 设置 scratch buffer 的 filetype。`ft` 不覆盖已有 filetype。 |
| `bo`、`wo` | `{}` | buffer-local 和 window-local 选项。`wo.winhighlight` 可使用 highlight 名称到组名的映射表。 |
| `b`、`w` | `{}` | buffer-local 和 window-local 变量。 |
| `keys` | `{ q = "close" }` | buffer-local 按键映射，详见下文。 |
| `actions` | 未设置 | 可由 `keys` 调用的自定义动作。 |
| `footer_keys` | `false` | 在 footer 显示映射；仅 Neovim 0.10+ 支持。`true` 显示所有已配置按键，字符串数组可筛选。 |
| `resize` | `true` | 编辑器尺寸变化时重新计算窗口。 |
| `fixbuf` | `true` | 有其他 buffer 在该窗口打开时，恢复本实例的 buffer。 |
| `stack` | `false` | 相同位置的分屏窗口叠放，而不是继续增加分屏。 |
| `on_buf`、`on_win`、`on_close` | 未设置 | 回调分别在 buffer 配置后、window 配置后和关闭过程中接收窗口对象。 |

`setup()` 会深度合并配置。窗口默认值可放在 `win` 子表中，也可直接放在顶层：

```lua
require("win").setup({
  win = {
    position = "bottom",
    height = 12,
    border = "top",
  },
})
```

## 样式

内置样式为 `float`、`help`、`split` 和 `minimal`。样式作为默认值合并，实例显式配置优先。`minimal = true` 时，除位置样式外还会应用 `minimal` 样式。

```lua
local Win = require("win")
Win.style.add("picker", {
  position = "float",
  width = 0.6,
  height = 0.5,
  border = "single",
})

local picker = Win({ style = "picker", title = "选择条目" })
```

`Win.style.add(name, defaults)` 注册或更新样式；`Win.style.get(name)` 和 `Win.style(name)` 获取样式配置。`Win.resolve(...)` 按相同的优先级解析样式名和配置表。

## 对象方法

模块可直接调用 `Win(opts)`，也提供 `Win.new(opts)`；两者均返回窗口对象。

| 方法 | 说明 |
| --- | --- |
| `show()` | 创建或重新打开窗口，并返回对象。 |
| `hide()` | 关闭窗口但保留 scratch buffer，以便复用。 |
| `close({ buf = false })` | 关闭窗口。默认删除实例自己的 scratch buffer；传 `buf = false` 保留。该选项不会删除用户传入的 buffer。 |
| `toggle()` | 窗口有效时隐藏，否则显示。 |
| `destroy()` | 关闭窗口并清空对象的事件、映射和元数据。 |
| `focus()` | 将有效窗口设为当前窗口。 |
| `valid()`、`win_valid()`、`buf_valid()` | 检查窗口与 buffer 是否有效关联、窗口是否有效、buffer 是否有效。 |
| `set_buf(buf)` | 设置窗口使用的 buffer。 |
| `set_title(title, pos)` | 设置带边框窗口的标题；`pos` 可为 `"left"`、`"center"` 或 `"right"`。 |
| `on(event, callback, opts)` | 注册 autocmd。回调参数为 `(self, event_args)`；`opts.buf = true` 或 `opts.win = true` 可限定到实例的 buffer 或 window。 |
| `size()` | 返回计算后的 `{ width, height }`，包括边框。 |
| `dim(parent?)` | 返回计算后的 `{ width, height, row, col, border }`。 |
| `is_floating()` | 判断当前有效窗口是否为浮动窗口。 |
| `line(n)`、`lines(from?, to?)`、`text(from?, to?)` | 读取 buffer 内容；行号从 1 开始，范围两端均包含。 |
| `update()` | 重新应用选项并重新计算有效浮动窗口的位置和尺寸。 |
| `scroll(up?)`、`hscroll(left)`、`redraw()` | 滚动或重绘窗口。 |
| `action(names)`、`execute(names)` | 解析或执行命名动作。 |
| `toggle_help(opts?)` | 切换帮助窗口，显示 buffer 的 normal/insert 模式映射及描述。 |
| `Win.zindex(opts?)` | 静态辅助函数，返回下一个可用 z-index。 |

关闭后对象可以再次打开。`hide()` 会保留实例的 scratch buffer；`close()` 默认删除该 buffer，也可传 `{ buf = false }` 保留。需要复用对象时不要调用 `destroy()`。

## 按键与动作

`keys` 是从 lhs 到动作名、回调或按键规格的映射。默认模式为 normal；`mode` 可指定单个模式或模式数组。`<Leader>` 和 `<LocalLeader>` 使用当前 Neovim leader 值。

```lua
local panel = require("win")({
  text = "按 x 执行自定义动作",
  keys = {
    q = "close",
    x = { "refresh", desc = "刷新内容", mode = { "n", "i" } },
  },
  actions = {
    refresh = function(self)
      self.opts.text = { "已更新" }
      self:scratch()
    end,
  },
})
```

动作可以是 `function(self) ... end`，也可以是 `{ action = function(self) ... end, desc = "..." }`。动作返回真值会停止动作链；返回字符串会作为通知显示。内置动作名会解析为对象方法，因此可直接使用 `"close"`、`"hide"` 和 `"toggle"`。按键规格也可使用 `vim.keymap.set` 支持的元组 `{ lhs, rhs, opts }`。

## 背景遮罩

`backdrop` 可传 blend 百分比或配置表：

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

配置项为 `bg`（默认 `#000000`）、`blend`（默认 `60`）、`transparent`（默认 `true`）和 `win`（遮罩窗口的配置覆盖项）。只有在浮动窗口、启用 `termguicolors`、blend 不等于 `100`，且当前背景/透明度条件允许时才会创建遮罩。默认 `transparent = true` 且 `Normal` 背景透明时会跳过遮罩。

## 高亮组

插件使用 `AevreWin*` 前缀定义窗口背景、标题/footer、按键、分隔符和遮罩高亮组。可在 colorscheme 加载后定义这些组覆盖外观。也可通过 `wo.winhighlight` 单独覆盖窗口高亮映射。

## 从原配置模块迁移

原来的 `builtin.win` 模块会转发到 `require("win")`。安装该插件后，既有的 `Builtin.win(...)`、terminal 和 lazygit 调用保持兼容。可通过 `require("win").setup(...)` 或原有 builtin `win` 选项配置默认值。
