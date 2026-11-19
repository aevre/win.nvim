LUA_FILES := $(shell find lua plugin tests -name '*.lua')
NVIM_BIN ?= nvim

.PHONY: fmt fmt-check lint check test health

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)

check: fmt-check lint test health

test:
	$(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'luafile tests/smoke.lua'

health:
	$(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'checkhealth win' -c 'lua vim.wait(1000); assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("win.nvim", 1, true))' -c 'qa!'
