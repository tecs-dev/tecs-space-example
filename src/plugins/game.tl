local tecs <const> = require("tecs")
local tecslove <const> = require("tecs.love")
local render <const> = require("tecs.gfx")
local controller <const> = require("tecs.controller")
local input <const> = require("tecs.input")
local stats <const> = require("tecs.stats")
local mcp <const> = require("tecs.mcp")

local record Player is tecs.Component
    speed: number
end

tecs.newComponent({
    name = "Player",
    container = Player,
})

local function gamePlugin(world: tecs.World)
    -- Create controller with keyboard bindings
    local controlManager = world.resources[controller]
    local playerController = controlManager:addController({
        controls = {
            up = {"key:up", "key:w"},
            down = {"key:down", "key:s"},
            left = {"key:left", "key:a"},
            right = {"key:right", "key:d"},
        }
    })

    -- Spawn some static reference objects (grid of gray squares)
    for x = -400, 400, 100 do
        for y = -300, 300, 100 do
            world:spawn(
                tecs.builtins.Transform(x, y),
                render.Rectangle(16, 16),
                render.Color(0.3, 0.3, 0.3, 1)
            )
        end
    end

    -- Spawn player at center of world
    world:spawn(
        tecs.builtins.Transform(0, 0, 1),
        render.Rectangle(16, 16),
        render.Color(0, 0.8, 1, 1),
        render.CameraTarget(),
        Player({speed = 300})
    )

    -- Movement system
    local movementQuery = world:query({include = {Player, tecs.builtins.Transform}})
    world:addSystem({
        name = "PlayerMovement",
        phase = tecs.phases.Update,
        run = function(dt: number)
            for archetype, length in movementQuery() do
                local players = archetype[Player]
                local transforms = archetype[tecs.builtins.Transform]
                for i = 1, length do
                    local player = players[i]
                    local transform = transforms[i]
                    local speed = player.speed * dt
                    if playerController:isDown("left") then
                        transform.x = transform.x - speed
                    end
                    if playerController:isDown("right") then
                        transform.x = transform.x + speed
                    end
                    if playerController:isDown("up") then
                        transform.y = transform.y - speed
                    end
                    if playerController:isDown("down") then
                        transform.y = transform.y + speed
                    end
                end
            end
        end
    })

    -- Quit on escape
    world:addSystem({
        name = "QuitHandler",
        phase = tecs.phases.Update,
        run = function()
            if input.isKeyPressed("escape") then
                tecslove.quit(0)
            end
        end
    })
end

-- Main plugin that composes all sub-plugins
return function(world: tecs.World)
    world:addPlugin(mcp.new())
    world:addPlugin(gamePlugin)
    world:addPlugin(stats.newStatsPlugin())
end
