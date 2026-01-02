-- Vendor path setup (vendor is copied to build/ during build)
package.path = package.path .. ";./vendor/share/lua/5.1/?.lua;./vendor/share/lua/5.1/?/init.lua"
package.cpath = package.cpath .. ";./vendor/lib/lua/5.1/?.so"

local jit <const> = require("jit")
jit.on()

local tecslove <const> = require("tecs.love")

love.run = tecslove.run({
    fps = 60,
    game = require("plugins.game"),
    render = {
        virtualHeight = 384,
        lightingMode = "none",
    },
})
