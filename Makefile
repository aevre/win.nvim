LUA_FILES := $(shell find lua plugin tests -name '*.lua')
NVIM_BIN ?= nvim

.PHONY: fmt fmt-check lint check test

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)

check: fmt-check lint test

test:
	$(NVIM_BIN) --headless -u NONE --cmd 'set runtimepath+=.' -c 'luafile tests/smoke.lua'
