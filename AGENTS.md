# Agent Guide

This repo is a larger reference game for building with Tecs and Tecs2D in Teal. Treat it as a playable demo and a source of patterns; use `tecs new` when creating a small new project.

## Quick Commands

- `tecs help`: show available commands.
- `tecs run`: build and launch the game. First run downloads Love2D 12 and prepares the embedded Tecs/Tecs2D dependencies.
- `tecs check`: type-check all Teal source files. Add `--json` for machine-readable diagnostics.
- `tecs build`: compile Teal to `build/` and copy assets/vendor files.
- `tecs integ`: compile `spec/**/*.tl` and run it with the bundled busted runner;
  `spec/game_lovespec.tl` boots the built game under real LÖVE and drives it over MCP.
  Not headless; macOS and Linux only.
- `tecs add <rock>[@version]` / `tecs remove <rock>` / `tecs update`: vendor pure-Lua rocks
  (and their Teal type declarations) from luarocks.org into `src/vendor/`. The committed
  `tecs-rocks.lua` records them; check/build restore missing rocks from it.
- `tecs info --json`: CLI/runtime versions and project status for tooling.
- `tecs clean`: remove build output.
- `tecs dev`: prepare local Tecs source for development iteration.

Run `tecs check` after source edits. Run `tecs build` after adding/removing modules or assets. Use `tecs run` when behavior or rendering needs manual verification.

## Project Shape

- `src/main.tl`: Love2D entry point using `tecs2d.run`.
- `src/conf.tl`: Love2D window/app configuration.
- The installed `tecs` command owns setup, checking, builds, runs, and cleanup.
- `src/plugins/game.tl`: top-level game plugin, state setup, persistent HUD/starfield/player setup, shared systems.
- `src/plugins/shared.tl`: game-specific components, constants, asset preload, and mutable game-state record.
- `src/plugins/states/`: focused state plugins.
  - `ready.tl`: ready screen input.
  - `gameplay.tl`: core gameplay systems, spawning, collisions, movement.
  - `gameplay_glitch.tl`: glitch storm trigger/effects.
  - `gameplay_pause.tl`: gameplay pause input.
  - `paused.tl`: pause screen input.
  - `dead.tl`: game-over input.
  - `overlay.tl`: shared title overlay helper.
- `assets/`: bundled demo assets. Keep license files with assets.
- Teal declarations and framework sources are copied into `src/vendor/` from the CLI payload.
- `src/vendor/`: CLI-prepared framework sources and declarations; do not treat it as project-owned source.
- `build/`: self-contained runtime output. Development-only Teal sources are pruned; do not hand-edit it.

## Tecs/Tecs2D Patterns To Preserve

- Add game logic through plugins. Keep plugins focused and testable when possible.
- Create queries once during plugin setup, then reuse them in systems.
- Give persistent queries and systems names so MCP/debug tools are readable.
- Use `archetype:get` for read-only columns and `archetype:getMut` when writing column data.
- Use `world:getMut(entity, Component)` when mutating a component fetched by entity ID.
- Prefer `world:batchDespawn`, `batchSet`, or `batchRemove` for bulk entity/component changes.
- Use `tecs.runif.*` predicates for simple scheduling/state gates; use custom predicates when combining state checks with local flags.
- Let `tecs2d.run` own the Love2D loop. Do not add manual `love.update`/`love.draw` callbacks unless intentionally replacing the engine loop.
- Use `world.resources[...]` for global/shared services instead of Lua globals.
- Load game assets through `tecs2d.assets` where practical; pin assets that should stay resident for the demo.
- Be careful with state auto-tags: entities spawned while a state is on top receive that state's component and may be affected by state lifecycle policies.

## Current Demo Notes

The demo is a fixed-camera scrolling shooter:

- Arrow keys/WASD move the player.
- Space fires.
- Enter starts, pauses/resumes, or restarts depending on state.
- Escape quits.
- Ctrl+. toggles the stats overlay.
- Ctrl+/ toggles the runtime debugger.

The player is intentionally treated as a persistent entity rather than a `gameState` entity. If you respawn or restructure the player, preserve or deliberately change that lifecycle behavior.

## Making A Cleaner Slate

This repository ships with a full shooter demo. For a genuinely small project, run `tecs new my-game`. To reduce this demo in place:

1. Keep `src/main.tl`, `src/conf.tl`, and `tlconfig.lua`.
2. Replace `src/plugins/game.tl` with a small plugin that registers only the Tecs/Tecs2D plugins you need, creates states if desired, and spawns a camera/HUD/test entity.
3. Trim `src/plugins/shared.tl` down to only components/constants/assets your new game needs.
4. Delete or ignore unused files under `src/plugins/states/`.
5. Remove unused demo assets from `assets/`, but keep license files for any assets that remain.
6. Run `tecs check`, `tecs build`, then `tecs run`.

For an even smaller starting point, keep `tecs2d.run({ game = require("plugins.game") })` in `src/main.tl` and have `plugins.game` return one plugin function that spawns a sprite/text/entity and one named update system.

## Editing Guidance

- Source files are Teal (`.tl`), compiled to Lua by `tecs build`.
- Keep new comments short and useful; this reference project should remain easy to scan.
- Do not edit `build/` directly.
- Do not remove third-party asset credit/license files unless the corresponding asset is removed too.
- Vendor third-party pure-Lua rocks with `tecs add <rock>` (never a LuaRocks installation);
  commit the generated `tecs-rocks.lua`. Keep project-owned Teal modules under `src/`.
- If you add new files under `src/`, verify they are included by `tecs build`.

## CI

GitHub Actions installs the latest published Tecs CLI — via Homebrew on macOS,
Scoop on Windows, and the standalone installer script on Linux, so every
distribution channel stays covered — and runs `tecs check` and `tecs build` on
all three platforms. No system Lua, LuaRocks, or compiler toolchain is
installed by the workflow.

## Useful References

- Public docs: https://tecs.dev
- Love2D wiki: https://love2d.org/wiki/Main_Page
- Teal: https://teal-language.org
