-- Core gameplay state: player control, spawning, collisions, and entity updates.
local tecs <const> = require("tecs")
local render <const> = require("tecs2d.gfx")
local controller <const> = require("tecs2d.controller")
local audio <const> = require("tecs2d.audio")
local assets <const> = require("tecs2d.assets")
local physics <const> = require("tecs2d.physics")
local runif <const> = tecs.runif

local shared <const> = require("plugins.shared")
local glitchPlugin <const> = require("plugins.states.gameplay_glitch")
local pausePlugin <const> = require("plugins.states.gameplay_pause")

local Player <const> = shared.Player
local Bullet <const> = shared.Bullet
local Powerup <const> = shared.Powerup
local EnemyBullet <const> = shared.EnemyBullet
local Enemy <const> = shared.Enemy
local Asteroid <const> = shared.Asteroid

return function(world: tecs.World, gs: shared.GameState)
    local controlManager = world.resources[controller]
    local playerController = controlManager:addController({
        controls = {
            up = {"key:up", "key:w", "button:dpup"},
            down = {"key:down", "key:s", "button:dpdown"},
            left = {"key:left", "key:a", "button:dpleft"},
            right = {"key:right", "key:d", "button:dpright"},
            fire = {"key:space", "button:a"},
        },
    })

    -- Audio
    local audioManager = world.resources[audio]
    local assetManager = world.resources[assets]
    local laserHandle = assetManager:loadAudio("sounds/laser.wav", "static")
    local pickupHandle = assetManager:loadAudio("sounds/pickup.wav", "static")
    local hitHandle = assetManager:loadAudio("sounds/hit.wav", "static")

    -- Queries
    local movementQuery = world:query({name = "PlayerMovement", include = {Player, tecs.builtins.Transform, physics.Collider}})
    local bulletQuery = world:query({name = "PlayerBullets", include = {Bullet, tecs.builtins.Transform}})
    local powerupQuery = world:query({name = "Powerups", include = {Powerup, tecs.builtins.Transform}})
    local enemyQuery = world:query({name = "Enemies", include = {Enemy, tecs.builtins.Transform}})
    local enemyBulletQuery = world:query({name = "EnemyBullets", include = {EnemyBullet, tecs.builtins.Transform}})
    local asteroidQuery = world:query({name = "Asteroids", include = {Asteroid, tecs.builtins.Transform, physics.Collider}})
    local asteroidTimer = shared.ASTEROID_SPAWN_INTERVAL

    -- The bullet sprites are white, so a Color tint gives any bright bolt color
    -- (Unlit keeps them at full brightness). Player = pink, enemy = yellow.
    local PLAYER_BOLT <const> = render.Color(1.0, 0.48, 0.88, 1.0)
    local ENEMY_BOLT <const> = render.Color(1.0, 0.88, 0.36, 1.0)

    -- Helper to spawn a player bullet
    local function spawnBullet(x: number, y: number, offsetX: number, lateralSpeed: number)
        local spr = render.Sprite.fromSheet(shared.playerBulletSheet, "")
        spr:pauseAtStart()
        world:spawn(
            tecs.builtins.Transform(x + offsetX, y - 10, 0.95),
            spr,
            render.Unlit,
            PLAYER_BOLT,
            Bullet({speed = shared.BULLET_SPEED, vx = lateralSpeed or 0}),
            physics.Collider.new({
                shape = "circle",
                radius = 4,
                sensor = true,
                categories = shared.CAT_PLAYER_BULLET,
                mask = shared.MASK_PLAYER_BULLET,
            }),
            physics.RigidBody.new({
                bodyType = "dynamic",
                fixedRotation = true,
                vx = lateralSpeed or 0,
                vy = -shared.BULLET_SPEED,
            })
        )
    end

    -- Helper to spawn an enemy bullet
    local function spawnEnemyBullet(x: number, y: number, vx: number, vy: number)
        local spr = render.Sprite.fromSheet(shared.enemyBulletSheet, "")
        spr:pauseAtStart()
        world:spawn(
            tecs.builtins.Transform(x, y + 10, 0.95),
            spr,
            render.Unlit,
            ENEMY_BOLT,
            EnemyBullet({speed = vy, vx = vx or 0}),
            physics.Collider.new({
                shape = "circle",
                radius = 4,
                sensor = true,
                categories = shared.CAT_ENEMY_BULLET,
                mask = shared.MASK_ENEMY_BULLET,
            }),
            physics.RigidBody.new({
                bodyType = "dynamic",
                fixedRotation = true,
                vx = vx or 0,
                vy = vy,
            })
        )
    end

    -- Spawn powerup at (x, y): weapon (green bolt) or health (red cross), where
    -- the odds of health are `healthChance`. Dropped where an enemy died, then
    -- drifts down. Sprites come from the Kenney power-up set.
    local function spawnPowerup(x: number, y: number, healthChance: number)
        local isHealth = math.random() < healthChance
        local sheet = isHealth and shared.powerupHealthSheet or shared.powerupWeaponSheet
        -- Light tint matches the icon: red for health, green for weapon.
        local cr = isHealth and 1.0 or 0.3
        local cg = isHealth and 0.3 or 1.0
        local cb = isHealth and 0.3 or 0.4
        local spr = render.Sprite.fromSheet(sheet, "")
        spr:pauseAtStart()
        world:spawn(
            tecs.builtins.Transform(x, y, 0.9),
            spr,
            render.Light.new({radius = 60, intensity = 0.8, height = 0.3, r = cr, g = cg, b = cb}),
            Powerup({active = true, isHealth = isHealth}),
            physics.Collider.new({
                shape = "rectangle",
                width = shared.POWERUP_SIZE,
                height = shared.POWERUP_SIZE,
                sensor = true,
                categories = shared.CAT_POWERUP,
                mask = shared.MASK_POWERUP,
            }),
            physics.RigidBody.new({
                bodyType = "dynamic",
                fixedRotation = true,
                vx = 0,
                vy = shared.POWERUP_DRIFT_SPEED,
            })
        )
    end

    -- Spawn an asteroid of a given tier (3 = big, 2 = medium, 1 = small) at
    -- (x, y) drifting with velocity (vx, vy). Bigger tiers have more HP and a
    -- larger hitbox; all spin slowly. attachAsteroidCollision wires up the
    -- shoot-to-split behavior, so it is forward-declared for the recursion.
    local attachAsteroidCollision: function(asteroidId: integer)
    local function spawnAsteroid(tier: integer, x: number, y: number, vx: number, vy: number)
        local sheet: render.SpriteSheet
        local radius: number
        local hp: number
        if tier >= 3 then
            sheet = shared.asteroidBigSheet
            radius = 30
            hp = shared.ASTEROID_BIG_HP
        elseif tier == 2 then
            sheet = shared.asteroidMedSheet
            radius = 18
            hp = shared.ASTEROID_MED_HP
        else
            sheet = shared.asteroidSmallSheet
            radius = 11
            hp = shared.ASTEROID_SMALL_HP
        end
        local spr = render.Sprite.fromSheet(sheet, "")
        spr:pauseAtStart()
        local asteroidId = world:spawn(
            tecs.builtins.Transform(x, y, 0.95),
            spr,
            Asteroid({hp = hp, tier = tier, spin = shared.randomRange(-1.5, 1.5)}),
            physics.Collider.new({
                shape = "circle",
                radius = radius,
                sensor = true,
                categories = shared.CAT_ASTEROID,
                mask = shared.MASK_ASTEROID,
            }),
            -- fixedRotation = false so the body (and thus the synced Transform)
            -- can spin; the spin rate is applied in the asteroid update loop.
            physics.RigidBody.new({
                bodyType = "dynamic",
                fixedRotation = false,
                vx = vx,
                vy = vy,
            })
        )
        attachAsteroidCollision(asteroidId)
    end

    -- Player bullets chip an asteroid's HP; at zero it scores, explodes, and (if
    -- big or medium) splits into two smaller chunks flung sideways.
    attachAsteroidCollision = function(asteroidId: integer)
        world:observe(asteroidId, physics.BeginContact, function(e: physics.BeginContact)
            local ast = world:getMut(asteroidId, Asteroid)
            if not ast then return end
            if world:get(e.other, Bullet) then
                ast.hp = ast.hp - 1
                world:despawn(e.other)
                audioManager:play(hitHandle, {
                    group = "sfx",
                    volume = 0.4,
                    pitchVariance = 0.2,
                    key = "hit",
                })
                if ast.hp <= 0 then
                    gs.score = gs.score + shared.ASTEROID_SCORE
                    gs.updateScoreText()
                    local at = world:get(asteroidId, tecs.builtins.Transform)
                    if at then
                        if ast.tier > 1 then
                            local childTier = ast.tier - 1
                            spawnAsteroid(childTier, at.x - 8, at.y, -shared.randomRange(40, 100), shared.ASTEROID_DRIFT_SPEED)
                            spawnAsteroid(childTier, at.x + 8, at.y, shared.randomRange(40, 100), shared.ASTEROID_DRIFT_SPEED)
                        elseif math.random() < 0.5 then
                            -- Only the smallest asteroids drop powerups, ~50% of the time.
                            spawnPowerup(at.x, at.y, 0.4)
                        end
                        gs.spawnExplosion(at.x, at.y, "rock")
                    end
                    world:despawn(asteroidId)
                else
                    gs.flashHit(asteroidId)
                end
            end
        end)
    end

    -- Per-enemy hit handler: player bullets damage it; death scores.
    local function attachEnemyCollision(enemyId: integer)
        world:observe(enemyId, physics.BeginContact, function(e: physics.BeginContact)
            local enemy = world:getMut(enemyId, Enemy)
            if not enemy then return end

            if world:get(e.other, Bullet) then
                enemy.hp = enemy.hp - 1
                world:despawn(e.other)
                audioManager:play(hitHandle, {
                    group = "sfx",
                    volume = 0.4,
                    pitchVariance = 0.2,
                    key = "hit",
                })
                if enemy.hp <= 0 then
                    enemy.killed = true
                    gs.score = gs.score + shared.ENEMY_KILL_SCORE
                    gs.updateScoreText()
                    -- Enemies no longer drop powerups; those come only from
                    -- shattering small asteroids (see attachAsteroidCollision).
                    world:despawn(enemyId)
                else
                    gs.flashHit(enemyId)
                end
            end
        end)
    end

    -- Spawn an enemy ship at the top of the screen with a random flight path.
    local function spawnEnemy()
        local behaviors: {shared.EnemyBehavior} = {"stationary", "strafe_left", "strafe_right", "wander", "sine"}
        local behavior = behaviors[math.random(1, #behaviors)]
        local x = shared.randomRange(-shared.VIEW_WIDTH / 2 + 60, shared.VIEW_WIDTH / 2 - 60)
        local y = -shared.VIEW_HEIGHT / 2 - shared.randomRange(30, 160)
        local strafeSpeed = shared.ENEMY_STRAFE_SPEED + math.random() * 60

        local enemySprite = render.Sprite.fromSheet(shared.enemySheet, "")
        local enemyId = world:spawn(
            tecs.builtins.Transform(x, y, 0.95),
            enemySprite,
            Enemy({
                hp = shared.ENEMY_HP,
                behavior = behavior,
                fireCooldown = math.random() * 2,
                fireRate = shared.randomRange(shared.ENEMY_FIRE_RATE_MIN, shared.ENEMY_FIRE_RATE_MAX),
                wanderTimer = 0,
                wanderVx = 0,
                wanderVy = 0,
                strafeSpeed = strafeSpeed,
                killed = false,
                swoopTime = 0,
                swoopDir = 0,
            }),
            physics.Collider.new({
                shape = "circle",
                radius = 14,
                sensor = true,
                categories = shared.CAT_ENEMY,
                mask = shared.MASK_ENEMY,
            }),
            physics.RigidBody.new({bodyType = "dynamic", fixedRotation = true})
        )
        attachEnemyCollision(enemyId)
    end

    -- Spawn a line of swooping ships from one side. dir = +1 enters from the
    -- left and sweeps right; dir = -1 enters from the right and sweeps left.
    -- Each ship trails the one ahead by SWOOP_SPACING seconds along the same arc
    -- (computed in the enemy update from swoopTime/swoopDir).
    local function spawnSwoopLine(dir: number, count: integer, speedMult?: number, fireRateMult?: number)
        speedMult = speedMult or 1.0
        fireRateMult = fireRateMult or 1.0
        local w = math.pi / shared.SWOOP_DURATION
        local edge = shared.VIEW_WIDTH / 2 + 60
        for i = 0, count - 1 do
            local t = -i * shared.SWOOP_SPACING
            local x = dir * (shared.SWOOP_HSPEED * speedMult * t - edge)
            local y = shared.SWOOP_TOP + shared.SWOOP_DIP * math.sin(w * t)
            local enemySprite = render.Sprite.fromSheet(shared.enemySheet, "")
            local enemyId = world:spawn(
                tecs.builtins.Transform(x, y, 0.95),
                enemySprite,
                -- Purple tint marks these as the low-HP (2) swoopers, visually
                -- distinct from the tougher standard enemies.
                render.Color(0.8, 0.4, 1.0, 1.0),
                Enemy({
                    hp = 2,
                    behavior = "swoop",
                    fireCooldown = shared.randomRange(0.5, 2.5),
                    -- Swoopers fire much more often than standard enemies (0.42 = shorter interval).
                    fireRate = shared.randomRange(shared.ENEMY_FIRE_RATE_MIN, shared.ENEMY_FIRE_RATE_MAX) * 0.42 * fireRateMult,
                    wanderTimer = 0,
                    wanderVx = 0,
                    wanderVy = 0,
                    strafeSpeed = speedMult,
                    killed = false,
                    swoopTime = t,
                    swoopDir = dir,
                }),
                physics.Collider.new({
                    shape = "circle",
                    radius = 14,
                    sensor = true,
                    categories = shared.CAT_ENEMY,
                    mask = shared.MASK_ENEMY,
                }),
                physics.RigidBody.new({bodyType = "dynamic", fixedRotation = true})
            )
            attachEnemyCollision(enemyId)
        end
    end

    -- StateEnter("game"): register player collision handler
    world:observe(0, tecs.builtins.StateEnter, function(e: tecs.builtins.StateEnter)
        if e.state == "game" then
            gs.registerPlayerCollision()
        end
    end)

    -- Register player collision handler for pickups, enemy bullets, and enemy contact
    gs.registerPlayerCollision = function()
        world:observe(gs.playerId, physics.BeginContact, function(e: physics.BeginContact)
            local otherId = e.other

            local powerup = world:get(otherId, Powerup)
            if powerup then
                if powerup.isHealth then
                    gs.playerHp = math.min(shared.PLAYER_MAX_HP, gs.playerHp + 1)
                    gs.updateHealthText()
                else
                    gs.bulletCount = math.min(shared.MAX_BULLETS, gs.bulletCount + 1)
                end
                gs.score = gs.score + 10
                gs.updateScoreText()
                audioManager:play(pickupHandle, {
                    group = "sfx",
                    volume = 0.6,
                    pitchVariance = 0.1,
                    key = "pickup",
                })
                world:despawn(otherId)
                return
            end

            if world:get(otherId, EnemyBullet) then
                world:despawn(otherId)
                audioManager:play(hitHandle, {
                    group = "sfx",
                    volume = 0.5,
                    pitchVariance = 0.15,
                    key = "hit",
                })
                gs.hurtPlayer()
                return
            end

            local enemy = world:getMut(otherId, Enemy)
            if enemy then
                enemy.killed = true
                gs.score = gs.score + shared.ENEMY_KILL_SCORE
                gs.updateScoreText()
                world:despawn(otherId)
                gs.hurtPlayer()
                return
            end

            -- Flying into an asteroid hurts the player and shatters the rock.
            if world:get(otherId, Asteroid) then
                local at = world:get(otherId, tecs.builtins.Transform)
                world:despawn(otherId)
                if at then gs.spawnExplosion(at.x, at.y, "rock") end
                gs.hurtPlayer()
                return
            end
        end)
    end

    -- Main gameplay system
    world:addSystem({
        name = "PlayerMovement",
        phase = tecs.phases.Update,
        runIf = runif.inState("game"),
        run = function(dt: number)
            if not gs.playerAlive then return end


            -- Fixed-screen bounds (the camera is anchored at the origin).
            local topEdge <const> = -shared.VIEW_HEIGHT / 2 - shared.BUFFER
            local bottomEdge <const> = shared.VIEW_HEIGHT / 2 + shared.BUFFER
            local boundX <const> = shared.VIEW_WIDTH / 2 - shared.PLAYER_MARGIN
            local boundTop <const> = -shared.VIEW_HEIGHT / 2 + shared.PLAYER_MARGIN
            local boundBottom <const> = shared.VIEW_HEIGHT / 2 - shared.PLAYER_MARGIN

            -- Move the player freely around the screen via its body velocity,
            -- clamped to the visible area; read position back from Transform.
            local playerX = 0.0
            local playerY = 0.0
            for archetype, length in movementQuery:iter() do
                local players = archetype:get(Player)
                local transforms = archetype:get(tecs.builtins.Transform)
                local colliders = archetype:get(physics.Collider)
                for i = 1, length do
                    local player = players[i]
                    local transform = transforms[i]

                    local vx = 0.0
                    if playerController:isDown("left") then
                        vx = -player.speed
                    elseif playerController:isDown("right") then
                        vx = player.speed
                    end
                    local vy = 0.0
                    if playerController:isDown("up") then
                        vy = -player.speed
                    elseif playerController:isDown("down") then
                        vy = player.speed
                    end

                    -- Stop at the screen edges instead of pushing past them.
                    if (transform.x <= -boundX and vx < 0) or (transform.x >= boundX and vx > 0) then
                        vx = 0
                    end
                    if (transform.y <= boundTop and vy < 0) or (transform.y >= boundBottom and vy > 0) then
                        vy = 0
                    end

                    local body = colliders[i].body
                    if body then
                        body:setLinearVelocity(vx, vy)
                    end
                    playerX = transform.x
                    playerY = transform.y
                end
            end

            -- Firing: fan out gs.bulletCount parallel bullets, centered.
            gs.fireCooldown = gs.fireCooldown - dt
            if playerController:isDown("fire") and gs.fireCooldown <= 0 then
                local rateBonus = math.max(0, gs.bulletCount - 4)
                local fireRate = math.max(0, shared.BASE_FIRE_RATE * (1.0 - rateBonus * 0.12))
                gs.fireCooldown = fireRate

                audioManager:play(laserHandle, {
                    group = "sfx",
                    volume = 0.25,
                    pitchVariance = 0.15,
                    key = "laser",
                })

                local count = gs.bulletCount
                local spacing = 8.0
                local startOffset = -(count - 1) * spacing / 2
                for k = 0, count - 1 do
                    spawnBullet(playerX, playerY, startOffset + k * spacing, 0)
                end
            end

            -- Spawn enemies periodically.
            gs.distSinceLastEnemy = gs.distSinceLastEnemy + shared.SCROLL_SPEED * dt
            if gs.distSinceLastEnemy >= shared.ENEMY_SPAWN_INTERVAL then
                gs.distSinceLastEnemy = gs.distSinceLastEnemy - shared.ENEMY_SPAWN_INTERVAL
                spawnEnemy()
            end

            -- Spawn big asteroids at the top on a jittered timer; they drift
            -- down, spin, and split when shot (see attachAsteroidCollision).
            asteroidTimer = asteroidTimer - dt
            if asteroidTimer <= 0 then
                asteroidTimer = shared.ASTEROID_SPAWN_INTERVAL + shared.randomRange(-0.8, 1.2)
                local ax = shared.randomRange(-shared.VIEW_WIDTH / 2 + 40, shared.VIEW_WIDTH / 2 - 40)
                local ay = -shared.VIEW_HEIGHT / 2 - shared.randomRange(40, 120)
                spawnAsteroid(3, ax, ay, shared.randomRange(-40, 40), shared.ASTEROID_DRIFT_SPEED)
            end

            -- Swoop ships. During a storm's swarm phase: a steady stream of lone
            -- swoopers from random sides (no formations, no bursts). Otherwise:
            -- the occasional small formation from the left, the right, or both.
            if gs.glitchElapsed >= shared.GLITCH_WARN then
                gs.swarmSpawnTimer = gs.swarmSpawnTimer - dt
                if gs.swarmSpawnTimer <= 0 then
                    gs.swarmSpawnTimer = shared.GLITCH_SWARM_SPAWN_INTERVAL
                    spawnSwoopLine(
                        math.random() < 0.5 and 1 or -1,
                        1,
                        shared.GLITCH_SWOOP_SPEED_MULT,
                        shared.GLITCH_SWOOP_FIRE_RATE_MULT
                    )
                end
            elseif gs.glitchElapsed < 0 then
                gs.formationCooldown = gs.formationCooldown - dt
                if gs.formationCooldown <= 0 then
                    gs.formationCooldown = shared.randomRange(shared.FORMATION_INTERVAL_MIN, shared.FORMATION_INTERVAL_MAX)
                    local pick = math.random(1, 3)
                    if pick == 1 then
                        spawnSwoopLine(1, math.random(shared.SWOOP_COUNT_MIN, shared.SWOOP_COUNT_MAX))
                    elseif pick == 2 then
                        spawnSwoopLine(-1, math.random(shared.SWOOP_COUNT_MIN, shared.SWOOP_COUNT_MAX))
                    else
                        spawnSwoopLine(1, math.random(shared.SWOOP_COUNT_MIN, shared.SWOOP_COUNT_MAX))
                        spawnSwoopLine(-1, math.random(shared.SWOOP_COUNT_MIN, shared.SWOOP_COUNT_MAX))
                    end
                end
            end

            -- Scroll the starfield (shared with the base state).
            gs.scrollStars(dt)

            -- Player bullets fly via their kinematic body velocity (set at
            -- spawn); just despawn them once off the top of the screen.
            for archetype, length, entities in bulletQuery:iter() do
                local transforms = archetype:get(tecs.builtins.Transform)
                for i = 1, length do
                    if transforms[i].y < topEdge - 100 then
                        world:despawn(entities[i])
                    end
                end
            end

            -- Powerups drift downward on their own (velocity set at spawn);
            -- despawn once they pass the bottom of the screen.
            for archetype, length, entities in powerupQuery:iter() do
                local transforms = archetype:get(tecs.builtins.Transform)
                for i = 1, length do
                    if transforms[i].y > bottomEdge + 50 then
                        world:despawn(entities[i])
                    end
                end
            end

            -- Enemies fly varied paths across the screen, all with a baseline
            -- downward drift so they enter from the top and exit the bottom.
            local enemyBoundX <const> = shared.VIEW_WIDTH / 2 - 30
            for archetype, length, entities in enemyQuery:iter() do
                local enemies = archetype:getMut(Enemy)
                local transforms = archetype:get(tecs.builtins.Transform)
                local colliders = archetype:get(physics.Collider)
                for i = 1, length do
                    local enemy = enemies[i]
                    local transform = transforms[i]

                    local vx = 0.0
                    local vy = 0.0
                    if enemy.behavior == "swoop" then
                        -- Scripted arc: constant horizontal sweep, half-sine dip.
                        local w = math.pi / shared.SWOOP_DURATION
                        vx = enemy.swoopDir * shared.SWOOP_HSPEED * enemy.strafeSpeed
                        vy = shared.SWOOP_DIP * w * math.cos(w * enemy.swoopTime) * enemy.strafeSpeed
                        enemy.swoopTime = enemy.swoopTime + dt * enemy.strafeSpeed
                    else
                        vy = shared.ENEMY_DRIFT_SPEED
                        if enemy.behavior == "strafe_left" then
                            vx = -enemy.strafeSpeed
                        elseif enemy.behavior == "strafe_right" then
                            vx = enemy.strafeSpeed
                        elseif enemy.behavior == "wander" then
                            enemy.wanderTimer = enemy.wanderTimer - dt
                            if enemy.wanderTimer <= 0 then
                                enemy.wanderTimer = shared.randomRange(0.5, 2.0)
                                enemy.wanderVx = shared.randomRange(-shared.ENEMY_WANDER_SPEED, shared.ENEMY_WANDER_SPEED)
                                enemy.wanderVy = shared.randomRange(-shared.ENEMY_WANDER_SPEED * 0.3, shared.ENEMY_WANDER_SPEED * 0.3)
                            end
                            vx = enemy.wanderVx
                            vy = shared.ENEMY_DRIFT_SPEED + enemy.wanderVy
                        elseif enemy.behavior == "sine" then
                            enemy.wanderTimer = enemy.wanderTimer + dt
                            vx = shared.ENEMY_SINE_AMPLITUDE * math.cos(enemy.wanderTimer * shared.ENEMY_SINE_FREQ)
                        end

                        -- Bounce lateral motion off the screen sides.
                        if transform.x < -enemyBoundX then
                            if enemy.behavior == "strafe_left" then enemy.behavior = "strafe_right" end
                            if enemy.behavior == "wander" then enemy.wanderVx = math.abs(enemy.wanderVx) end
                            vx = math.abs(vx)
                        elseif transform.x > enemyBoundX then
                            if enemy.behavior == "strafe_right" then enemy.behavior = "strafe_left" end
                            if enemy.behavior == "wander" then enemy.wanderVx = -math.abs(enemy.wanderVx) end
                            vx = -math.abs(vx)
                        end
                    end

                    local body = colliders[i].body
                    if body then
                        body:setLinearVelocity(vx, vy)
                    end

                    -- Shooting
                    enemy.fireCooldown = enemy.fireCooldown - dt
                    if enemy.fireCooldown <= 0 then
                        enemy.fireCooldown = enemy.fireRate + shared.randomRange(-0.5, 0.5)
                        spawnEnemyBullet(transform.x, transform.y, 0, shared.ENEMY_BULLET_SPEED)
                    end

                    -- Despawn: swoopers when their arc completes (off the far
                    -- side), everything else when it drifts off the bottom.
                    if enemy.behavior == "swoop" then
                        if enemy.swoopTime >= shared.SWOOP_DURATION then
                            world:despawn(entities[i])
                        end
                    elseif transform.y > bottomEdge + 100 then
                        world:despawn(entities[i])
                    end
                end
            end

            -- Enemy bullets also fly via their spawn-time velocity; despawn off-screen.
            for archetype, length, entities in enemyBulletQuery:iter() do
                local transforms = archetype:get(tecs.builtins.Transform)
                for i = 1, length do
                    local y = transforms[i].y
                    if y > bottomEdge + 50 or y < topEdge - 50 then
                        world:despawn(entities[i])
                    end
                end
            end

            -- Asteroids drift via their spawn-time velocity; keep their spin
            -- applied (the body owns rotation) and despawn off the bottom.
            for archetype, length, entities in asteroidQuery:iter() do
                local asteroids = archetype:get(Asteroid)
                local transforms = archetype:get(tecs.builtins.Transform)
                local colliders = archetype:get(physics.Collider)
                for i = 1, length do
                    local body = colliders[i].body
                    if body then
                        body:setAngularVelocity(asteroids[i].spin)
                    end
                    if transforms[i].y > bottomEdge + 120 then
                        world:despawn(entities[i])
                    end
                end
            end
        end
    })

    glitchPlugin(world, gs)
    pausePlugin(world, gs)
end
