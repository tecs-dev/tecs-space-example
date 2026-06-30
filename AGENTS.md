# Agent Guide

This repo is a starter template for building Love2D games with Tecs and Tecs2D in Teal. Treat it as both a playable demo and a reference project for developers who will replace the demo with their own game.

## Quick Commands

- `./tecs help`: show available targets.
- `./tecs run`: build and launch the game. First run downloads Love2D 12 and installs local Tecs/Tecs2D dependencies.
- `./tecs check`: type-check all Teal source files.
- `./tecs build`: compile Teal to `build/` and copy assets/vendor files.
- `./tecs clean`: remove build output.
- `./tecs dev`: prepare local Tecs source for development iteration.
- `./tecs sync-tecs`: reinstall Tecs/Tecs2D from the local checkout.

Run `./tecs check` after source edits. Run `./tecs build` after adding/removing modules or assets. Use `./tecs run` when behavior or rendering needs manual verification.
On Windows, use `lua tecs <target>`.

## Project Shape

- `src/main.tl`: Love2D entry point using `tecs2d.run`.
- `src/conf.tl`: Love2D window/app configuration.
- `tecs`: cross-platform task runner for setup, check, build, run, and cleanup.
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
- `types/`: copied/generated Teal type definitions.
- `src/vendor/`: installed LuaRocks tree.
- `build/`: generated output. Do not hand-edit generated Lua.

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
- F1 toggles the stats overlay.

The player is intentionally treated as a persistent entity rather than a `gameState` entity. If you respawn or restructure the player, preserve or deliberately change that lifecycle behavior.

## Making A Cleaner Slate

This template ships with a full shooter demo. To turn it into a smaller blank project:

1. Keep `src/main.tl`, `src/conf.tl`, `tecs`, `tlconfig.lua`, `types/`, and dependency setup.
2. Replace `src/plugins/game.tl` with a small plugin that registers only the Tecs/Tecs2D plugins you need, creates states if desired, and spawns a camera/HUD/test entity.
3. Trim `src/plugins/shared.tl` down to only components/constants/assets your new game needs.
4. Delete or ignore unused files under `src/plugins/states/`.
5. Remove unused demo assets from `assets/`, but keep license files for any assets that remain.
6. Run `./tecs check`, `./tecs build`, then `./tecs run`.

For an even smaller starting point, keep `tecs2d.run({ game = require("plugins.game") })` in `src/main.tl` and have `plugins.game` return one plugin function that spawns a sprite/text/entity and one named update system.

## Editing Guidance

- Source files are Teal (`.tl`), compiled to Lua by `./tecs build`.
- Keep new comments short and useful; this starter should remain easy to scan.
- Do not edit `build/` directly.
- Do not remove third-party asset credit/license files unless the corresponding asset is removed too.
- If you add new dependencies, install them under `src/vendor` with LuaRocks and update docs if needed.
- If you add new files under `src/`, verify they are included by `./tecs build`.

## CI

GitHub Actions runs `lua tecs check` and `lua tecs build` on Linux, macOS, and Windows. The workflow checks out `tecs-dev/tecs` beside this starter and sets `TECS_DIR` so the template's local Tecs install path is exercised on every platform.

## Useful References

- Public docs: https://tecs.dev
- Love2D wiki: https://love2d.org/wiki/Main_Page
- Teal: https://teal-language.org
