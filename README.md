# tecs-starter

A project template for building Love2D games with [Tecs](https://github.com/tecs-dev/tecs),
a high-performance ECS framework.

## Prerequisites

Install these tools before using this template:

1. **LuaRocks** - Lua package manager ([installation](https://github.com/luarocks/luarocks/blob/main/docs/download.md))
2. **Teal** - Typed Lua compiler

```bash
luarocks install tl
```

## Quick Start

```bash
git clone https://github.com/tecs-dev/tecs-starter.git my-game
cd my-game
make run
```

That's it! The first run automatically downloads Love2D 12, type definitions, and
dependencies. You should see a demo with a movable player.

## Project Structure

```
my-game/
├── Makefile              # Build orchestration
├── tlconfig.lua          # Teal configuration
├── src/
│   ├── main.tl           # Game entry point
│   ├── conf.tl           # Love2D configuration
│   └── plugins/
│       └── game.tl       # Game logic
├── assets/               # Images, sounds, fonts
├── types/                # Type definitions (generated)
├── build/                # Compiled output (generated)
└── src/vendor/           # Dependencies (generated)
```

## Make Targets

| Command             | Description                                          |
|---------------------|------------------------------------------------------|
| `make run`          | Build and run the game (runs setup automatically)    |
| `make build`        | Compile without running                              |
| `make clean`        | Remove build artifacts                               |
| `make reset`        | Clean everything, including dependencies and Love2D  |
| `make love12`       | Re-download Love2D 12                                |

## Managing Dependencies

```bash
# Add a package
luarocks install --tree=src/vendor --lua-version=5.1 penlight

# Add a specific version
luarocks install --tree=src/vendor --lua-version=5.1 penlight 1.14.0
```

## Demo Controls

The starter demo includes a simple player that you can control:

- **Arrow keys / WASD** - Move the player
- **ESC** - Quit
- **F1** - Toggle stats overlay

The camera follows the player as they move.

## Documentation

- [Tecs Documentation](https://tecs.dev)
- [Love2D Wiki](https://love2d.org/wiki/Main_Page)
- [Teal Language](https://github.com/teal-language/tl)

## License

MIT License

Copyright (c) 2026 Michael Dowling

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
