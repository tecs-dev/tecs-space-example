-- Vendor path setup (vendor is copied to build/ during build)
package.path = package.path .. ";./vendor/share/lua/5.1/?.lua;./vendor/share/lua/5.1/?/init.lua"
package.cpath = package.cpath .. ";./vendor/lib/lua/5.1/?.so"

local tecs2d <const> = require("tecs2d")

love.run = tecs2d.run({
    fps = 60,
    game = require("plugins.game"),
    render = {
        virtualHeight = 480,
        lightingMode = "dynamic",
        layers = {
            [15] = {name = "ui", space = "virtual", unlit = true},
        },
    },
})
