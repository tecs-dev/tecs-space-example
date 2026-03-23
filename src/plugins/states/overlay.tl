-- Shared helper for state-enter title overlays with bounce-in text.
local tecs <const> = require("tecs")
local render <const> = require("tecs2d.gfx")
local ui <const> = require("tecs2d.ui")
local tween <const> = require("tecs2d.tween")
local shared <const> = require("plugins.shared")

local record overlay
    register: function(world: tecs.World, state: string, title: string, r: number, g: number, b: number)
end

function overlay.register(world: tecs.World, state: string, title: string, r: number, g: number, b: number)
    local bounceSchedule = tween.timeline()
        :to(0.7, tween.elasticOut, tween.scaleXY, 1.0, 1.0)
        :once()
    local hintBounceSchedule = tween.timeline()
        :to(0.5, tween.elasticOut, tween.scaleXY, 1.0, 1.0)
        :once()

    world:observe(0, tecs.builtins.StateEnter, function(e: tecs.builtins.StateEnter)
        if e.state ~= state then return end

        local textId = world:spawn(
            tecs.builtins.Transform(0, 0, 2, shared.UI_LAYER),
            render.Text(shared.FONT_PATH, title, 3.0, 3.0),
            render.Color(r, g, b, 1.0),
            ui.Anchor(0.5, 0.5, 0, -16)
        )
        local hintId = world:spawn(
            tecs.builtins.Transform(0, 0, 2, shared.UI_LAYER),
            render.Text(shared.FONT_PATH, "PRESS ENTER", 0.5, 0.5),
            render.Color(0.6, 0.6, 0.6, 1.0),
            ui.Anchor(0.5, 0.5, 0, 20)
        )

        local textTransform = world:getMut(textId, tecs.builtins.Transform)
        if textTransform then
            textTransform.scaleX = 0
            textTransform.scaleY = 0
        end

        local hintTransform = world:getMut(hintId, tecs.builtins.Transform)
        if hintTransform then
            hintTransform.scaleX = 0
            hintTransform.scaleY = 0
        end

        bounceSchedule:apply(world, textId)
        hintBounceSchedule:apply(world, hintId, 1.0, 0.15)
    end)
end

return overlay
