-- Pause-state overlay and input that resumes gameplay.
local tecs <const> = require("tecs")
local input <const> = require("tecs2d.input")
local shared <const> = require("plugins.shared")
local overlay <const> = require("plugins.states.overlay")

return function(world: tecs.World, _gs: shared.GameState)
    overlay.register(world, "paused", "PAUSED", 1.0, 1.0, 1.0)

    local skipFrame = false
    world:observe(0, tecs.builtins.StateEnter, function(e: tecs.builtins.StateEnter)
        if e.state == "paused" then skipFrame = true end
    end)

    world:addSystem({
        name = "PauseInput",
        phase = tecs.phases.Update,
        runIf = function(_dt: number, w: tecs.World, _systemName: string): boolean
            if w:peekState() ~= "paused" then
                return false
            elseif skipFrame then
                skipFrame = false
                return false
            end
            return true
        end,
        run = function()
            if input.isKeyPressed("return") then
                world:popState()
            end
        end
    })
end
