# tecs-starter

A project template for building Love2D games with [Tecs](https://github.com/tecs-dev/tecs),
a high-performance ECS framework.

![Space shooter demo](docs/screenshot.png)

## Prerequisites

Install these tools before using this template:

1. **Lua** - Any recent Lua that can run `tecs`
2. **LuaRocks** - Lua package manager ([installation](https://github.com/luarocks/luarocks/blob/main/docs/download.md))
3. **Teal** - Typed Lua compiler

```bash
luarocks install tl
```

## Quick Start

```bash
git clone https://github.com/tecs-dev/tecs-starter.git my-game
cd my-game
./tecs run
```

That's it! The first run automatically downloads Love2D 12, type definitions, and
installs both the `tecs` and `tecs2d` rocks from your local Tecs checkout. You should see a scrolling shooter demo.

## Project Structure

```
my-game/
├── tecs                  # Cross-platform build orchestration
├── tlconfig.lua          # Teal configuration
├── src/
│   ├── main.tl           # Game entry point
│   ├── conf.tl           # Love2D configuration
│   └── plugins/
│       ├── game.tl       # Game setup and shared systems
│       ├── shared.tl     # Components, constants, and asset preload
│       └── states/       # Focused state/gameplay plugins
├── assets/               # Images, sounds, fonts
├── types/                # Type definitions (generated)
├── build/                # Compiled output (generated)
└── src/vendor/           # Installed rocks and dependencies (generated)
```

## Build Targets

Commands are shown with `./tecs` for Unix-like systems. On Windows, use `lua tecs <target>`.

| Command             | Description                                          |
|---------------------|------------------------------------------------------|
| `./tecs run`       | Build and run the game (runs setup automatically)    |
| `./tecs build`     | Compile without running                              |
| `./tecs check`     | Type-check all Teal source files                     |
| `./tecs clean`     | Remove build artifacts                               |
| `./tecs love12`    | Re-download Love2D 12                                |

## Managing Dependencies

```bash
# Add a package
luarocks install --tree=src/vendor --lua-version=5.1 penlight

# Add a specific version
luarocks install --tree=src/vendor --lua-version=5.1 penlight 1.14.0
```

## Demo Controls

The starter demo is a small scrolling shooter:

- **Arrow keys / WASD** - Move the player
- **Space** - Fire
- **Enter** - Start, pause, resume, or restart depending on state
- **ESC** - Quit
- **F1** - Toggle stats overlay

The camera stays fixed while the playfield scrolls. Enemies, asteroids, powerups,
pause/game-over overlays, and a periodic glitch storm are implemented as Tecs plugins and systems.

## Documentation

- [Tecs Documentation](https://tecs.dev)
- [Love2D Wiki](https://love2d.org/wiki/Main_Page)
- [Teal Language](https://github.com/teal-language/tl)

## License

The template's **code** is released under [MIT No Attribution](LICENSE) (MIT-0): use it as
the starting point for your own game with no attribution required. Make it yours.

### Credits

Bundled demo assets are **not** all covered by MIT-0. Their licenses:

| Asset | Source | License |
|-------|--------|---------|
| `assets/images/` ships, lasers, power-ups, asteroids (`player`, `enemy`, `*Bullet`, `powerup*`, `asteroid*`) | [Space Shooter (Remastered)](https://kenney.nl/assets/space-shooter-redux) by Kenney | [CC0 1.0](assets/images/kenney-license.txt) |
| `assets/images/explosion.*` | [Explosion Spriteanim Sheet Minipack](https://reactorcore.itch.io/explosion-spriteanim-sheet-minipack) by [Reactorcore](http://www.reactorcoregames.com) | CC0 / CC-BY 4.0 — see [credits](assets/images/explosion-minipack-credits.txt) |
| `assets/fonts/press-start-2p.*` | [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) by CodeMan38 | [SIL OFL 1.1](assets/fonts/OFL.txt) |
| `assets/sounds/*.wav` (laser, explosion, hit, pickup) | Generated (sfxr-style), original to this template | MIT-0 |

> [!IMPORTANT]
> The explosion sheet is by **Reactorcore** — keep the credit and ship
> `assets/images/explosion-minipack-credits.txt`. (The pack is listed CC-BY 4.0 but the author
> states CC0 in the comments; either way crediting Reactorcore satisfies the terms.)
>
> The Kenney art is **CC0** (no attribution required). The Press Start 2P font is **SIL OFL**,
> not MIT-0: keep `assets/fonts/OFL.txt` alongside it. Sounds are original to this template (MIT-0).
