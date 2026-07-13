# tecs-space-example

A larger reference game for [Tecs](https://github.com/tecs-dev/tecs), a
high-performance ECS framework for building Love2D games in Teal.

![Space shooter demo](docs/screenshot.png)

## Install Tecs CLI

The Tecs CLI is the only required installation. It includes Teal, Tecs/Tecs2D,
type declarations, and build tooling, and downloads a tested LÖVE 12 runtime
on first use. Lua, LuaRocks, and a compiler toolchain are not required.

### macOS and Linux

```bash
brew install tecs-dev/tap/tecs-cli
```

### Windows

```powershell
scoop bucket add tecs https://github.com/tecs-dev/scoop-bucket
scoop install tecs
```

Open a new terminal after installation.

### Standalone installers

Prefer not to use a package manager?

```bash
curl -fsSL https://github.com/tecs-dev/tecs-cli/releases/latest/download/install.sh | sh
```

```powershell
irm https://github.com/tecs-dev/tecs-cli/releases/latest/download/install.ps1 | iex
```

## Run This Reference Game

```bash
git clone https://github.com/tecs-dev/tecs-space-example.git my-game
cd my-game
tecs run
```

`tecs run` prepares the embedded dependencies, downloads LÖVE 12 into the user
cache when needed, builds the game, and launches the scrolling shooter demo.

For a small new project instead of this larger example, run `tecs new my-game`.

## Project Structure

```
my-game/
├── tlconfig.lua          # Teal configuration
├── src/
│   ├── main.tl           # Game entry point
│   ├── conf.tl           # Love2D configuration
│   └── plugins/
│       ├── game.tl       # Game setup and shared systems
│       ├── shared.tl     # Components, constants, and asset preload
│       └── states/       # Focused state/gameplay plugins
├── assets/               # Images, sounds, fonts
├── build/                # Self-contained, runtime-only output (generated)
└── src/vendor/           # Embedded framework sources and declarations (generated)
```

## Releases

Every `v*` tag is packaged automatically: the Release workflow runs
`tecs integ`, then `tecs dist`, and attaches the `.love` file, the macOS app
bundle, and the Windows build to the
[GitHub release](https://github.com/tecs-dev/tecs-space-example/releases).
This example keeps the MCP server and debugger enabled in those builds to
demonstrate the opt-in.

## Build Targets

| Command              | Description                                          |
|----------------------|------------------------------------------------------|
| `tecs run`           | Build and run the game (runs setup automatically)    |
| `tecs build`         | Compile without running                              |
| `tecs check`         | Type-check all Teal source files (`--json` for tooling) |
| `tecs integ`         | Run `spec/`; `game_lovespec.tl` drives the built game over MCP |
| `tecs clean`         | Remove build artifacts                               |
| `tecs info`          | Show CLI/runtime versions and project status (`--json` for tooling) |
| `tecs agent`         | List bundled agent guides or print one's installed path |
| `tecs completions`   | Print a bash, zsh, or fish completion script         |

## Hot Reload

The reference game enables Tecs2D's snapshot-preserving hot reload by default. Run the
game normally:

```bash
tecs run
```

Then, from another terminal, rebuild whenever you want to reload code/assets:

```bash
tecs build
```

On a successful build, the task runner updates `build/.tecs-reload-stamp`. The
running game polls that single stamp file and restarts Love2D with freshly
loaded modules.

The demo restores the saved ECS snapshot after restart. Tecs2D rebuilds
renderer-owned sprite buckets and physics bodies from durable components during
normal startup/update; the demo also rebinds its local HUD and player references
after `FinishSnapshotLoad`.

You can wire any external watcher to the same stamp convention. The important
rule is to touch the stamp only after a successful rebuild:

```bash
watchexec -w src -w assets 'tecs build'
```

## Demo Controls

The reference demo is a small scrolling shooter:

- **Arrow keys / WASD** - Move the player
- **Space** - Fire
- **Enter** - Start, pause, resume, or restart depending on state
- **ESC** - Quit
- **Ctrl+.** - Toggle stats overlay
- **Ctrl+/** - Toggle the runtime debugger

The camera stays fixed while the playfield scrolls. Enemies, asteroids, powerups,
pause/game-over overlays, and a periodic glitch storm are implemented as Tecs plugins and systems.

## Documentation

- [Tecs Documentation](https://tecs.dev)
- [Love2D Wiki](https://love2d.org/wiki/Main_Page)
- [Teal Language](https://github.com/teal-language/tl)

## License

The project's **code** is released under [MIT No Attribution](LICENSE) (MIT-0): use it as
the starting point for your own game with no attribution required. Make it yours.

### Credits

Bundled demo assets are **not** all covered by MIT-0. Their licenses:

| Asset | Source | License |
|-------|--------|---------|
| `assets/images/` ships, lasers, power-ups, asteroids (`player`, `enemy`, `*Bullet`, `powerup*`, `asteroid*`) | [Space Shooter (Remastered)](https://kenney.nl/assets/space-shooter-redux) by Kenney | [CC0 1.0](assets/images/kenney-license.txt) |
| `assets/images/explosion.*` | [Explosion Spriteanim Sheet Minipack](https://reactorcore.itch.io/explosion-spriteanim-sheet-minipack) by [Reactorcore](http://www.reactorcoregames.com) | CC0 / CC-BY 4.0 — see [credits](assets/images/explosion-minipack-credits.txt) |
| `assets/fonts/press-start-2p.*` | [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) by CodeMan38 | [SIL OFL 1.1](assets/fonts/OFL.txt) |
| `assets/sounds/*.wav` (laser, explosion, hit, pickup) | Generated (sfxr-style), original to this project | MIT-0 |

> [!IMPORTANT]
> The explosion sheet is by **Reactorcore** — keep the credit and ship
> `assets/images/explosion-minipack-credits.txt`. (The pack is listed CC-BY 4.0 but the author
> states CC0 in the comments; either way crediting Reactorcore satisfies the terms.)
>
> The Kenney art is **CC0** (no attribution required). The Press Start 2P font is **SIL OFL**,
> not MIT-0: keep `assets/fonts/OFL.txt` alongside it. Sounds are original to this project (MIT-0).
