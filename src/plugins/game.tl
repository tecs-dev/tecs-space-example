local tecs <const> = require("tecs")
local render <const> = require("tecs2d.gfx")
local debugPlugin <const> = require("tecs2d.debug")
local mcp <const> = require("tecs2d.mcp")
local audio <const> = require("tecs2d.audio")
local assets <const> = require("tecs2d.assets")
local physics <const> = require("tecs2d.physics")
local ui <const> = require("tecs2d.ui")

local shared <const> = require("plugins.shared")
local readyPlugin <const> = require("plugins.states.ready")
local gameplayPlugin <const> = require("plugins.states.gameplay")
local pausedPlugin <const> = require("plugins.states.paused")
local deadPlugin <const> = require("plugins.states.dead")

local Player <const> = shared.Player
local Star <const> = shared.Star
local Enemy <const> = shared.Enemy

-- Marks an entity as flashing white from a recent hit; counts down to removal.
local record HitFlash is tecs.Component
    timer: number
end
tecs.newComponent({ name = "HitFlash", container = HitFlash })

local record ScoreNumber is tecs.Component end
tecs.newComponent({ name = "ScoreNumber", container = ScoreNumber })

local record HealthNumber is tecs.Component end
tecs.newComponent({ name = "HealthNumber", container = HealthNumber })

local function gamePlugin(world: tecs.World)
    local gs = shared.newGameState()

    -- Audio
    local audioManager = world.resources[audio]
    local assetManager = world.resources[assets]
    shared.loadAssets(world)
    local explosionHandle = assetManager:loadAudio("sounds/explosion.wav", "static")

    -- States
    world:createState("base")
    world:createState("ready")
    local GameStateComp = world:createState("game", { onBlur = "pause", onFocus = "resume" })
    world:createState("paused")
    world:createState("dead")
    local gameEntitiesQuery = world:query({name = "GameStateEntities", include = {GameStateComp}})

    -- Push base, then ready
    world:pushState("base")

    -- Forward declarations
    local updateScoreText: function()
    local updateHealthText: function()

    local function resetGame()
        gs.fireCooldown = 0.0
        gs.bulletCount = shared.START_BULLETS
        gs.score = 0
        gs.playerHp = shared.PLAYER_MAX_HP
        gs.playerAlive = true
        gs.distSinceLastEnemy = 0.0
        gs.formationCooldown = 5.0
        gs.glitchElapsed = -1.0
        gs.swarmSpawnTimer = 0.0
        world.resources[render.PIPELINE]:getCamera():setPosition(0, 0)
        gs.currentForwardSpeed = shared.FORWARD_SPEED_BASE
        gs.currentCameraOffsetY = shared.CAMERA_OFFSET_Y_BASE
        gs.lastPlayerX = 0.0
        gs.lastPlayerY = 0.0
    end

    -- Spawn player
    local function spawnPlayer()
        local playerSprite = render.Sprite.fromSheet(shared.playerSheet, "")
        -- Player starts lower-center; the camera is fixed (no CameraTarget), so
        -- the player roams the screen rather than the world scrolling under it.
        gs.playerId = world:spawn(
            tecs.builtins.Key("player"),
            tecs.builtins.Transform(0, shared.PLAYER_SPAWN_Y, 1),
            playerSprite,
            Player({speed = 374}),
            physics.Collider.new({
                shape = "circle",
                radius = 12,
                sensor = true,
                categories = shared.CAT_PLAYER,
                mask = shared.MASK_PLAYER,
            }),
            -- Dynamic (not kinematic) so its sensor generates overlap contacts:
            -- Box2D only fires contacts when at least one body in the pair is
            -- dynamic. Gravity is 0 and we drive it by velocity, so "dynamic"
            -- here behaves kinematically but still collides.
            physics.RigidBody.new({bodyType = "dynamic", fixedRotation = true})
        )
        world:remove(gs.playerId, GameStateComp)
    end
    gs.spawnPlayer = spawnPlayer
    spawnPlayer()

    -- Fix the camera at the world origin; the view never moves.
    world.resources[render.PIPELINE]:getCamera():setPosition(0, 0)

    -- Hit flash: a material that draws a sprite as a solid, fullbright white
    -- silhouette. Attached to an entity for 0.15s when it takes a (non-lethal)
    -- hit, then removed by the HitFlash system below.
    local flashMat <const> = render.newMaterial("hitflash", {
        fragment = [[
            MaterialOutput material(MaterialInput i) {
                MaterialOutput o = standardMaterial(i);
                o.albedo.rgb = vec3(1.0);
                o.lit = 0.0;
                return o;
            }
        ]],
    })
    local function flashHit(id: integer)
        world:set(id, flashMat)
        world:set(id, HitFlash({timer = 0.15}))
    end
    gs.flashHit = flashHit

    local hitFlashQuery = world:query({name = "HitFlashEntities", include = {HitFlash}})
    world:addSystem({
        name = "HitFlashFade",
        phase = tecs.phases.Update,
        run = function(dt: number)
            for archetype, len, entities in hitFlashQuery:iter() do
                local flashes = archetype:getMut(HitFlash)
                for i = 1, len do
                    flashes[i].timer = flashes[i].timer - dt
                    if flashes[i].timer <= 0 then
                        world:remove(entities[i], render.Material)
                        world:remove(entities[i], HitFlash)
                    end
                end
            end
        end,
    })

    -- Explosion: a one-shot sprite animation (Reactorcore minipack) plus a light
    -- flash, removed by a TTL when it finishes. The same fiery burst is used for
    -- ships, the player, and asteroids; `kind == "rock"` only tweaks the light.
    local function spawnExplosion(x: number, y: number, kind?: string)
        local isRock = kind == "rock"
        local spr = render.Sprite.fromSheet(shared.explosionSheet, "explode")
        spr:playOnce("explode")
        world:spawn(
            -- 1.1 scale = ~10% bigger than the sheet's native frame size.
            tecs.builtins.Transform(x, y, 2, 1, 0, 1.1, 1.1),
            spr,
            -- Unlit so the explosion renders at full brightness; the Light below
            -- still illuminates the surrounding scene.
            render.Unlit,
            render.Light.new({
                radius = isRock and 90 or 120,
                intensity = isRock and 1.8 or 2.0,
                height = 0.3,
                r = 1.0,
                g = isRock and 0.75 or 0.6,
                b = isRock and 0.30 or 0.25,
            }),
            tecs.builtins.TTL(0.5)
        )

        audioManager:play(explosionHandle, {
            group = "sfx",
            volume = 0.7,
            pitchVariance = 0.2,
            key = "explosion",
        })
    end
    gs.spawnExplosion = spawnExplosion

    -- Hurt player
    local function hurtPlayer()
        if not gs.playerAlive then return end
        gs.playerHp = gs.playerHp - 1
        updateHealthText()
        gs.bulletCount = 1
        if gs.playerHp <= 0 then
            gs.playerAlive = false
            local pt = world:get(gs.playerId, tecs.builtins.Transform)
            if pt then
                spawnExplosion(pt.x, pt.y)
            end
            world:despawn(gs.playerId)
            world:pushState("dead")
        else
            flashHit(gs.playerId)
        end
    end
    gs.hurtPlayer = hurtPlayer

    -- Explosion on enemy death
    world:observe(0, tecs.builtins.OnDespawn, function(e: tecs.builtins.OnDespawn)
        local enemy = world:get(e.entity, Enemy)
        if enemy and enemy.killed then
            local et = world:get(e.entity, tecs.builtins.Transform)
            if et then
                spawnExplosion(et.x, et.y)
            end
        end
    end)

    -- HUD
    local UI_LAYER <const> = shared.UI_LAYER
    local FONT_PATH <const> = shared.FONT_PATH

    world:spawn(
        tecs.builtins.Transform(0, 0, 1, UI_LAYER),
        render.Text(FONT_PATH, "SCORE", 0.5, 0.5),
        render.Color(0.5, 0.5, 0.5, 1.0),
        render.Pivot(0, 0),
        ui.Anchor(0, 1, 8, -30)
    )
    local scoreNumberId = world:spawn(
        tecs.builtins.Key("hud.score"),
        tecs.builtins.Transform(0, 0, 1, UI_LAYER),
        render.Text(FONT_PATH, "0000", 1.0, 1.0),
        render.Color(1.0, 1.0, 1.0, 1.0),
        render.Pivot(0, 0),
        ui.Anchor(0, 1, 8, -18),
        ScoreNumber()
    )
    world:spawn(
        tecs.builtins.Transform(0, 0, 1, UI_LAYER),
        render.Text(FONT_PATH, "HEALTH", 0.5, 0.5),
        render.Color(0.8, 0.5, 0.6, 1.0),
        render.Pivot(1, 0),
        ui.Anchor(1, 1, -8, -30)
    )
    local healthNumberId = world:spawn(
        tecs.builtins.Key("hud.health"),
        tecs.builtins.Transform(0, 0, 1, UI_LAYER),
        render.Text(FONT_PATH, tostring(shared.PLAYER_MAX_HP), 1.0, 1.0),
        render.Color(1.0, 0.2, 0.2, 1.0),
        render.Pivot(1, 0),
        ui.Anchor(1, 1, -8, -18),
        HealthNumber()
    )

    updateScoreText = function()
        local scoreText = world:getMut(scoreNumberId, render.Text)
        scoreText:setText(string.format("%04d", gs.score as integer))
    end
    gs.updateScoreText = updateScoreText

    updateHealthText = function()
        local healthText = world:getMut(healthNumberId, render.Text)
        healthText:setText(tostring(math.max(0, gs.playerHp)))
    end
    gs.updateHealthText = updateHealthText

    local function rebindRuntimeEntityIds()
        gs.playerId = world:byKey("player") or 0
        scoreNumberId = world:requireKey("hud.score")
        healthNumberId = world:requireKey("hud.health")
        gs.playerAlive = gs.playerId ~= 0 and world:isAlive(gs.playerId)
        updateScoreText()
        updateHealthText()
    end

    world:observe(0, tecs.builtins.OnSnapshotSave, function(ev: tecs.builtins.OnSnapshotSave)
        ev:addData("tecs-space-example.gameState", {
            fireCooldown = gs.fireCooldown,
            bulletCount = gs.bulletCount,
            score = gs.score,
            playerHp = gs.playerHp,
            playerAlive = gs.playerAlive,
            distSinceLastEnemy = gs.distSinceLastEnemy,
            formationCooldown = gs.formationCooldown,
            glitchElapsed = gs.glitchElapsed,
            swarmSpawnTimer = gs.swarmSpawnTimer,
            currentForwardSpeed = gs.currentForwardSpeed,
            currentCameraOffsetY = gs.currentCameraOffsetY,
            lastPlayerX = gs.lastPlayerX,
            lastPlayerY = gs.lastPlayerY,
            currentDir = gs.currentDir,
        })
    end)

    world:observe(0, tecs.builtins.StartSnapshotLoad, function(ev: tecs.builtins.StartSnapshotLoad)
        ev:onData("tecs-space-example.gameState", function(value: any)
            local data = value as {string: any}
            gs.fireCooldown = (data.fireCooldown as number) or gs.fireCooldown
            gs.bulletCount = (data.bulletCount as number) or gs.bulletCount
            gs.score = (data.score as number) or gs.score
            gs.playerHp = (data.playerHp as number) or gs.playerHp
            if data.playerAlive ~= nil then gs.playerAlive = data.playerAlive as boolean end
            gs.distSinceLastEnemy = (data.distSinceLastEnemy as number) or gs.distSinceLastEnemy
            gs.formationCooldown = (data.formationCooldown as number) or gs.formationCooldown
            gs.glitchElapsed = (data.glitchElapsed as number) or gs.glitchElapsed
            gs.swarmSpawnTimer = (data.swarmSpawnTimer as number) or gs.swarmSpawnTimer
            gs.currentForwardSpeed = (data.currentForwardSpeed as number) or gs.currentForwardSpeed
            gs.currentCameraOffsetY = (data.currentCameraOffsetY as number) or gs.currentCameraOffsetY
            gs.lastPlayerX = (data.lastPlayerX as number) or gs.lastPlayerX
            gs.lastPlayerY = (data.lastPlayerY as number) or gs.lastPlayerY
            gs.currentDir = (data.currentDir as string) or gs.currentDir
        end)
    end)

    world:observe(0, tecs.builtins.FinishSnapshotLoad, function()
        rebindRuntimeEntityIds()
    end)

    -- Spawn stars
    local starQuery = world:query({name = "Stars", include = {Star, tecs.builtins.Transform}})
    for _ = 1, shared.NUM_STARS do
        local depth = math.random()
        local size = 0.5 + depth * 2.5
        local brightness = 0.2 + depth * 0.8
        local r = brightness
        local g = brightness
        local b = brightness + (1 - depth) * 0.15
        -- ~30% of stars are distinctly blue rather than white.
        if math.random() < 0.3 then
            r = brightness * 0.4
            g = brightness * 0.65
            b = brightness
        end
        local x = shared.randomRange(-shared.VIEW_WIDTH / 2 - shared.BUFFER, shared.VIEW_WIDTH / 2 + shared.BUFFER)
        local y = shared.randomRange(-shared.VIEW_HEIGHT / 2 - shared.BUFFER, shared.VIEW_HEIGHT / 2 + shared.BUFFER)
        local z = 0.1 + depth * 0.4
        world:spawn(
            tecs.builtins.Transform(x, y, z),
            render.Circle(size),
            -- alpha at 0.75 of brightness = ~25% dimmer stars.
            render.Color(r, g, b, brightness * 0.75),
            Star({depth = depth})
        )
    end

    -- Restart: pop dead, despawn game entities, reset, respawn
    local function restartGame()
        if world:peekState() == "dead" then
            world:popState()
        end

        world:batchDespawn(gameEntitiesQuery)

        local needsRespawn = not gs.playerAlive
        resetGame()
        updateScoreText()
        updateHealthText()
        gs.currentDir = "idle"
        if needsRespawn then
            spawnPlayer()
        end

        for archetype, length in starQuery:iter() do
            local transforms = archetype:getMut(tecs.builtins.Transform)
            for i = 1, length do
                transforms[i].x = shared.randomRange(-shared.VIEW_WIDTH / 2 - shared.BUFFER, shared.VIEW_WIDTH / 2 + shared.BUFFER)
                transforms[i].y = shared.randomRange(-shared.VIEW_HEIGHT / 2 - shared.BUFFER, shared.VIEW_HEIGHT / 2 + shared.BUFFER)
            end
        end
    end
    gs.restartGame = restartGame

    -- Starfield scroll: the background drifts steadily downward on its own to
    -- sell the sense of forward flight. Stars have no physics body, so they stay
    -- Transform-driven. Exposed via gs so the gameplay state reuses it.
    local STAR_TOP <const> = -shared.VIEW_HEIGHT / 2 - shared.BUFFER
    local STAR_BOTTOM <const> = shared.VIEW_HEIGHT / 2 + shared.BUFFER
    local STAR_LEFT <const> = -shared.VIEW_WIDTH / 2 - shared.BUFFER
    local STAR_RIGHT <const> = shared.VIEW_WIDTH / 2 + shared.BUFFER

    local function scrollStars(dt: number)
        for archetype, length in starQuery:iter() do
            local stars = archetype:get(Star)
            local transforms = archetype:getMut(tecs.builtins.Transform)
            for i = 1, length do
                local transform = transforms[i]
                transform.y = transform.y + shared.SCROLL_SPEED * shared.parallaxFactor(stars[i].depth) * dt
                if transform.y > STAR_BOTTOM then
                    transform.y = STAR_TOP - math.random() * shared.BUFFER
                    transform.x = shared.randomRange(STAR_LEFT, STAR_RIGHT)
                end
            end
        end
    end
    gs.scrollStars = scrollStars

    -- Base/ready state: scroll the stars while the player waits. The player
    -- holds position; the gameplay system drives it once "game" starts.
    world:addSystem({
        name = "BaseMovement",
        phase = tecs.phases.Update,
        run = function(dt: number)
            local state = world:peekState()
            if state ~= "base" and state ~= "ready" then return end
            scrollStars(dt)
        end
    })


    -- Freeze physics motion while the game is not the focused state (paused or
    -- dead). Kinematic bodies keep their velocity across world steps, so the
    -- physics step would keep advancing them; we zero velocities on blur and
    -- restore them on focus. Player/enemy velocities are also re-derived by the
    -- movement systems each frame, but bullets are fire-and-forget so restoring
    -- is what keeps them flying after an unpause.
    local colliderQuery = world:query({name = "Colliders", include = {physics.Collider}})
    local frozenVel: {integer: {number}} = {}

    world:observe(0, tecs.builtins.OnSnapshotSave, function(ev: tecs.builtins.OnSnapshotSave)
        ev:addData("tecs-space-example.frozenVel", frozenVel)
    end)

    world:observe(0, tecs.builtins.StartSnapshotLoad, function(ev: tecs.builtins.StartSnapshotLoad)
        ev:onData("tecs-space-example.frozenVel", function(value: any)
            frozenVel = {}
            local saved = value as {any: {number}}
            for rawId, vel in pairs(saved) do
                local id = rawId as integer
                if type(rawId) == "string" then
                    id = tonumber(rawId as string) as integer
                end
                if id and vel then
                    frozenVel[id] = vel
                end
            end
        end)
    end)

    world:observe(0, tecs.builtins.StateBlur, function(e: tecs.builtins.StateBlur)
        if e.state ~= "game" then return end
        for archetype, length, entities in colliderQuery:iter() do
            local colliders = archetype:get(physics.Collider)
            for i = 1, length do
                local body = colliders[i].body
                if body then
                    local vx, vy = body:getLinearVelocity()
                    local av = body:getAngularVelocity()
                    frozenVel[entities[i]] = {vx, vy, av}
                    body:setLinearVelocity(0, 0)
                    body:setAngularVelocity(0)
                end
            end
        end
        -- The player is a persistent base-state entity, so it isn't covered by
        -- the game state's onBlur="pause" (which only tags game-state entities).
        -- Tag it Paused by hand so the engine freezes its sprite animation too.
        if gs.playerAlive then
            world:set(gs.playerId, tecs.builtins.Paused)
        end
    end)

    world:observe(0, tecs.builtins.StateFocus, function(e: tecs.builtins.StateFocus)
        if e.state ~= "game" then return end
        for archetype, length, entities in colliderQuery:iter() do
            local colliders = archetype:get(physics.Collider)
            for i = 1, length do
                local saved = frozenVel[entities[i]]
                local body = colliders[i].body
                if body and saved then
                    body:setLinearVelocity(saved[1], saved[2])
                    body:setAngularVelocity(saved[3] or 0)
                end
            end
        end
        frozenVel = {}
        if gs.playerAlive then
            world:remove(gs.playerId, tecs.builtins.Paused)
        end
    end)

    -- Install state plugins
    readyPlugin(world, gs)
    gameplayPlugin(world, gs)
    pausedPlugin(world, gs)
    deadPlugin(world, gs)

    -- Push ready state after base entities are committed
    world:addSystem({
        name = "InitialReady",
        phase = tecs.phases.Startup,
        run = function()
            world:pushState("ready")
        end
    })
end

return function(world: tecs.World)
    love.physics.setMeter(64)
    local physicsWorld = love.physics.newWorld(0, 0, false)
    world:addPlugin(physics.new({
        world = physicsWorld,
        defaultFixedRotation = true,
        -- Physics owns entity positions (everything moves via kinematic-body
        -- velocity), so interpolate body positions for smooth rendering.
        smoothing = "interpolate",
    }))
    world:addPlugin(mcp.new())
    world:addPlugin(debugPlugin.new())
    world:addPlugin(gamePlugin)
end
