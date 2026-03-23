-- Gameplay sub-plugin that handles entering the paused state.
local tecs <const> = require("tecs")
local input <const> = require("tecs2d.input")
local shared <const> = require("plugins.shared")

return function(world: tecs.World, _gs: shared.GameState)
    local skipFrame = false

    world:observe(0, tecs.builtins.StateFocus, function(e: tecs.builtins.StateFocus)
        if e.state == "game" then skipFrame = true end
    end)

    world:observe(0, tecs.builtins.StateEnter, function(e: tecs.builtins.StateEnter)
        if e.state == "game" then skipFrame = true end
    end)

    world:addSystem({
        name = "GameplayPauseInput",
        phase = tecs.phases.Update,
        runIf = function(_dt: number, w: tecs.World, _systemName: string): boolean
            if w:peekState() ~= "game" then
                return false
            elseif skipFrame then
                skipFrame = false
                return false
            end
            return true
        end,
        run = function()
            if input.isKeyPressed("return") then
                world:pushState("paused")
            end
        end
    })
end
