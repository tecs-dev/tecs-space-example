-- Game-over state overlay and input that restarts the game.
local tecs <const> = require("tecs")
local input <const> = require("tecs2d.input")
local shared <const> = require("plugins.shared")
local overlay <const> = require("plugins.states.overlay")

return function(world: tecs.World, gs: shared.GameState)
    overlay.register(world, "dead", "GAME OVER", 1.0, 0.2, 0.2)

    local skipFrame = false
    world:observe(0, tecs.builtins.StateEnter, function(e: tecs.builtins.StateEnter)
        if e.state == "dead" then skipFrame = true end
    end)

    world:addSystem({
        name = "DeadInput",
        phase = tecs.phases.Update,
        runIf = function(_dt: number, w: tecs.World, _systemName: string): boolean
            if w:peekState() ~= "dead" then
                return false
            elseif skipFrame then
                skipFrame = false
                return false
            end
            return true
        end,
        run = function()
            if input.isKeyPressed("return") or input.isKeyPressed("space") then
                gs.restartGame()
            end
        end
    })
end
