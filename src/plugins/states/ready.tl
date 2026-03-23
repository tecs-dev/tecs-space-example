-- Ready-state overlay and input that starts a new gameplay run.
local tecs <const> = require("tecs")
local input <const> = require("tecs2d.input")
local shared <const> = require("plugins.shared")
local overlay <const> = require("plugins.states.overlay")

return function(world: tecs.World, _gs: shared.GameState)
    overlay.register(world, "ready", "READY?", 1.0, 0.8, 0.2)

    -- Input: Enter to start game
    world:addSystem({
        name = "ReadyInput",
        phase = tecs.phases.Update,
        runIf = tecs.runif.inState("ready"),
        run = function()
            if input.isKeyPressed("return") or input.isKeyPressed("space") then
                world:popState()         -- pop ready (despawns ready entities)
                world:pushState("game")  -- enter game
            end
        end
    })
end
