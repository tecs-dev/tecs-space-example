-- Gameplay sub-plugin that drives glitch warnings and visual storm effects.
local tecs <const> = require("tecs")
local render <const> = require("tecs2d.gfx")
local shared <const> = require("plugins.shared")

return function(world: tecs.World, gs: shared.GameState)
    local glitchCam = world.resources[render.PIPELINE]:getCamera()
    local triggerStorm = tecs.runif.both(
        tecs.runif.inState("game"),
        tecs.runif.every(shared.GLITCH_PERIOD)
    )
    local glitchColors = {
        {0.0, 1.0, 1.0},
        {1.0, 0.0, 1.0},
        {1.0, 1.0, 1.0},
        {0.6, 0.2, 1.0},
    }

    world:addSystem({
        name = "GlitchStormTrigger",
        phase = tecs.phases.Update,
        runIf = triggerStorm,
        run = function()
            if gs.glitchElapsed >= 0 then return end
            gs.glitchElapsed = 0.0
            gs.swarmSpawnTimer = 0.0
        end,
    })

    world:addSystem({
        name = "GlitchStorm",
        phase = tecs.phases.Update,
        runIf = function(_dt: number, w: tecs.World, _systemName: string): boolean
            return w:peekState() == "game" and gs.glitchElapsed >= 0
        end,
        run = function(dt: number)
            local wasGlitching = gs.glitchElapsed < shared.GLITCH_WARN
            gs.glitchElapsed = gs.glitchElapsed + dt
            if gs.glitchElapsed >= shared.GLITCH_WARN + shared.GLITCH_SWARM_DURATION then
                gs.glitchElapsed = -1.0
                glitchCam:setPosition(0, 0)
                return
            end

            if gs.glitchElapsed >= shared.GLITCH_WARN then
                if wasGlitching then
                    glitchCam:setPosition(0, 0)
                end
                return
            end

            local jx = (math.random() * 2 - 1) * 8
            local jy = (math.random() * 2 - 1) * 6
            if math.random() < 0.25 then
                jx = jx + (math.random() * 2 - 1) * 40
            end
            glitchCam:setPosition(jx, jy)

            for _ = 1, 6 do
                local by = shared.randomRange(-shared.VIEW_HEIGHT / 2, shared.VIEW_HEIGHT / 2)
                local col = glitchColors[math.random(1, #glitchColors)]
                world:spawn(
                    tecs.builtins.Transform(0, by, 1, shared.UI_LAYER - 1),
                    render.Rectangle(shared.VIEW_WIDTH + 160, shared.randomRange(2, 18), 0),
                    render.Color(col[1], col[2], col[3], shared.randomRange(0.3, 0.85)),
                    render.Unlit,
                    tecs.builtins.TTL(0.06)
                )
            end
        end
    })
end
