LUA_FILES := $(shell find lua -name '*.lua')

.PHONY: fmt fmt-check lint check

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)

check: fmt-check lint
