.PHONY: help run build clean reset love12 sync-tecs
.SILENT: clean reset

# Platform detection
UNAME_S := $(shell uname -s)

# Love2D 12 binary location
LOVE12_DIR := $(CURDIR)/.love12
ifeq ($(UNAME_S),Darwin)
    LOVE12_BIN := $(LOVE12_DIR)/love.app/Contents/MacOS/love
else ifeq ($(UNAME_S),Linux)
    LOVE12_BIN := $(LOVE12_DIR)/love
else
    LOVE12_BIN := $(LOVE12_DIR)/love.exe
endif

# Always use local Love2D 12 (auto-downloaded by make build)
LOVE := $(LOVE12_BIN)

# Tecs project directory (for development sync)
TECS_DIR ?= $(HOME)/projects/tecs
VENDOR_LUA := src/vendor/share/lua/5.1

# LUA_PATH for tl gen to find type definitions
TL_PATH := types/?.d.tl;\
           types/string/?.d.tl;\
           types/table/?.d.tl;\
           $(VENDOR_LUA)/?.tl;\
           $(VENDOR_LUA)/?/init.tl

# Asset patterns to exclude from build (space-separated)
EXCLUDE_ASSETS := *.ase *.aseprite

# Source files (exclude vendor - those are pre-compiled)
SOURCE_TEAL := $(shell find src -path src/vendor -prune -o -type f -name "*.tl" ! -name "*.d.tl" -print 2>/dev/null)
EXCLUDE_ARGS := $(foreach pat,$(EXCLUDE_ASSETS),! -name "$(pat)")
SOURCE_ASSETS := $(shell find assets -type f $(EXCLUDE_ARGS) 2>/dev/null)

# Generated files (src/foo.tl -> build/foo.lua)
GENERATED_LUA := $(patsubst src/%.tl,build/%.lua,$(SOURCE_TEAL))

# All build outputs
ALL_FILES := $(GENERATED_LUA) build/assets build/vendor

# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  run        Build and run the game (runs setup automatically)"
	@echo "  build      Compile without running"
	@echo "  clean      Remove build artifacts"
	@echo "  reset      Clean everything, including dependencies and Love2D"
	@echo "  love12     Re-download Love2D 12"
	@echo ""
	@echo "Example:"
	@echo "  make run   # Build and play"

# Auto-setup: copy type definitions from tecs project
types/love2d.d.tl:
	@echo "Copying type definitions from $(TECS_DIR)..."
	@mkdir -p types
	@rsync -a --exclude='busted.d.tl' --exclude='luassert' $(TECS_DIR)/types/ types/

# Auto-setup: install tecs dependency
$(VENDOR_LUA)/tecs/init.lua:
	@echo "Installing tecs..."
	@luarocks install --tree=src/vendor --lua-version=5.1 $(TECS_DIR)/build/tecs.tl-dev-1.rockspec

# Auto-setup: download Love2D 12
$(LOVE12_BIN):
	@$(MAKE) --no-print-directory love12

# Build: compile only changed files (auto-runs setup if needed)
build: $(LOVE12_BIN) types/love2d.d.tl $(VENDOR_LUA)/tecs/init.lua $(ALL_FILES)

# Pattern rule for compiling .tl -> .lua
build/%.lua: src/%.tl tlconfig.lua
	@mkdir -p $(dir $@)
	@LUA_PATH="$(TL_PATH)" tl gen $< -o $@

# Copy assets when changed (excluding EXCLUDE_ASSETS patterns)
build/assets: $(SOURCE_ASSETS)
	@mkdir -p build/assets
	@rsync -a --delete $(foreach pat,$(EXCLUDE_ASSETS),--exclude="$(pat)") assets/ build/assets/

# Copy vendor and symlink tecs for Love2D asset access (shaders, etc.)
build/vendor: src/vendor
	@mkdir -p build
	@rm -rf build/vendor
	@cp -r src/vendor build/
	@ln -sfn vendor/share/lua/5.1/tecs build/tecs
	@ln -sfn vendor/share/lua/5.1/tecs/assets/internal build/internal

# Build and run
run: build
	@cd build && $(LOVE) .

# Remove build artifacts
clean:
	rm -rf build

# Clean everything, including dependencies and Love2D
reset:
	rm -rf build types src/vendor $(LOVE12_DIR)

# Nightly build URLs (via nightly.link for unauthenticated access)
NIGHTLY_BASE := https://nightly.link/love2d/love/workflows/main/main

# Download Love2D 12 nightly (nightly.link wraps artifacts in a double-zip)
love12:
	@rm -rf $(LOVE12_DIR)
	@mkdir -p $(LOVE12_DIR)
ifeq ($(UNAME_S),Darwin)
	@echo "Downloading Love2D 12 for macOS..."
	@curl -sL -o $(LOVE12_DIR)/outer.zip $(NIGHTLY_BASE)/love-macos.zip
	@cd $(LOVE12_DIR) && unzip -q outer.zip && unzip -q love-macos.zip && rm -f outer.zip love-macos.zip
else ifeq ($(UNAME_S),Linux)
	@echo "Downloading Love2D 12 for Linux..."
	@curl -sL -o $(LOVE12_DIR)/outer.zip $(NIGHTLY_BASE)/love-linux-X64.AppImage.zip
	@cd $(LOVE12_DIR) && unzip -q outer.zip && rm -f outer.zip && mv love-* love && chmod +x love
else
	@echo "Downloading Love2D 12 for Windows..."
	@curl -sL -o $(LOVE12_DIR)/outer.zip $(NIGHTLY_BASE)/love-windows-x64.zip
	@cd $(LOVE12_DIR) && unzip -q outer.zip && rm -f outer.zip
endif
	@echo "Love2D 12 installed to $(LOVE12_DIR)/"

# Reinstall tecs from local rockspec (for development)
sync-tecs:
	@echo "Reinstalling tecs from $(TECS_DIR)..."
	@test -f "$(TECS_DIR)/build/tecs.tl-dev-1.rockspec" || (echo "Error: rockspec not found. Run 'make build' in tecs first." && exit 1)
	@rsync -a --exclude='busted.d.tl' --exclude='luassert' $(TECS_DIR)/types/ types/
	@luarocks install --tree=src/vendor --lua-version=5.1 --force $(TECS_DIR)/build/tecs.tl-dev-1.rockspec
	@echo "Sync complete!"
