local tecs <const> = require("tecs")
local render <const> = require("tecs2d.gfx")
local physics <const> = require("tecs2d.physics")
local assets <const> = require("tecs2d.assets")

-- Components (registered globally at module level)

local record Player is tecs.Component
    speed: number
end

tecs.newComponent({
    name = "Player",
    container = Player,
})

local record Star is tecs.Component
    depth: number -- 0 = far, 1 = near
end

tecs.newComponent({
    name = "Star",
    container = Star,
})

local record Bullet is tecs.Component
    speed: number
    vx: number
end

tecs.newComponent({
    name = "Bullet",
    container = Bullet,
})

local record Powerup is tecs.Component
    active: boolean
    isHealth: boolean
end

tecs.newComponent({
    name = "Powerup",
    container = Powerup,
})

local record EnemyBullet is tecs.Component
    speed: number
    vx: number
end

tecs.newComponent({
    name = "EnemyBullet",
    container = EnemyBullet,
})

local enum EnemyBehavior
    "stationary"
    "strafe_left"
    "strafe_right"
    "wander"
    "sine"
    "swoop"
end

local record Enemy is tecs.Component
    hp: number
    behavior: EnemyBehavior
    fireCooldown: number
    fireRate: number
    wanderTimer: number
    wanderVx: number
    wanderVy: number
    strafeSpeed: number
    killed: boolean
    swoopTime: number   -- elapsed time along the "swoop" path (may start negative)
    swoopDir: number    -- +1 = entered from left, -1 = entered from right
end

tecs.newComponent({
    name = "Enemy",
    container = Enemy,
})

local record Asteroid is tecs.Component
    hp: number
    tier: integer    -- 3 = big, 2 = medium, 1 = small
    spin: number     -- angular velocity in rad/s
end

tecs.newComponent({
    name = "Asteroid",
    container = Asteroid,
})

-- Collision categories
local CAT_PLAYER <const> = physics.categories(1)
local CAT_PLAYER_BULLET <const> = physics.categories(2)
local CAT_ENEMY <const> = physics.categories(3)
local CAT_ENEMY_BULLET <const> = physics.categories(4)
local CAT_POWERUP <const> = physics.categories(5)
local CAT_ASTEROID <const> = physics.categories(6)

-- Masks: what each category collides with
local MASK_PLAYER <const> = physics.categories(3, 4, 5, 6)     -- enemies, enemy bullets, powerups, asteroids
local MASK_PLAYER_BULLET <const> = physics.categories(3, 6)    -- enemies and asteroids
local MASK_ENEMY <const> = physics.categories(1, 2)            -- player, player bullets
local MASK_ENEMY_BULLET <const> = physics.categories(1)        -- player only
local MASK_POWERUP <const> = physics.categories(1)             -- player only
local MASK_ASTEROID <const> = physics.categories(1, 2)         -- player, player bullets

-- Constants
local FORWARD_SPEED_SLOW <const> = 80
local FORWARD_SPEED_BASE <const> = 240
local FORWARD_SPEED_BOOST <const> = 480
local VIEW_WIDTH <const> = 640
local VIEW_HEIGHT <const> = 480
local CAMERA_OFFSET_Y_BASE <const> = -160
local CAMERA_OFFSET_Y_BOOST <const> = -220
local BUFFER <const> = 140
local NUM_STARS <const> = 120
local BULLET_SPEED <const> = 600
local BASE_FIRE_RATE <const> = 0.14
local POWERUP_SIZE <const> = 16
local ENEMY_HP <const> = 10
local ENEMY_FIRE_RATE_MIN <const> = 1.36
local ENEMY_FIRE_RATE_MAX <const> = 3.64
local ENEMY_BULLET_SPEED <const> = 300
local ENEMY_STRAFE_SPEED <const> = 80
local ENEMY_WANDER_SPEED <const> = 60
local ENEMY_SPAWN_INTERVAL <const> = 3120 -- scaled with SCROLL_SPEED so the spawn rate is unchanged
local PLAYER_MAX_HP <const> = 5
local ENEMY_KILL_SCORE <const> = 1000
local POWERUP_SPAWN_INTERVAL <const> = 800

-- Asteroids: drift down on their own, spin, and split into smaller chunks when
-- shot. Tier 3 = big, 2 = medium, 1 = small (small ones just shatter).
local ASTEROID_SPAWN_INTERVAL <const> = 3.2   -- seconds between asteroid spawns
local ASTEROID_DRIFT_SPEED <const> = 95
local ASTEROID_BIG_HP <const> = 4
local ASTEROID_MED_HP <const> = 2
local ASTEROID_SMALL_HP <const> = 1
local ASTEROID_SCORE <const> = 250

-- Weapon: the player fires this many parallel bullets. Starts at START_BULLETS,
-- a weapon powerup adds one (up to MAX_BULLETS), and each hit taken removes one.
local START_BULLETS <const> = 2
local MAX_BULLETS <const> = 8
local POWERUP_DROP_CHANCE <const> = 0.5       -- chance a killed enemy drops a powerup
local POWERUP_DROP_CHANCE_LOW <const> = 0.9   -- higher chance while the player is down to one bullet

-- Fixed auto-scroll model: the camera stays put, the world scrolls downward on
-- its own, and the player roams freely within the view.
local SCROLL_SPEED <const> = 655          -- background scroll (down the screen)
local ENEMY_DRIFT_SPEED <const> = 110     -- enemies' baseline downward drift
local ENEMY_SINE_AMPLITUDE <const> = 150  -- lateral velocity amplitude for "sine" path
local ENEMY_SINE_FREQ <const> = 2.5       -- weave frequency for "sine" path
local POWERUP_DRIFT_SPEED <const> = 130   -- powerups drift down past the player
local PLAYER_MARGIN <const> = 24          -- how close the player may get to a screen edge
local PLAYER_SPAWN_Y <const> = 150        -- player start (lower-center, +y is down)

-- Swoop formation: a line of ships enters from a side, arcs down toward the
-- play field (but stays above a bottom-hugging player), then curves back up and
-- exits the far side. The path is x = constant horizontal sweep, y = half-sine dip.
local SWOOP_HSPEED <const> = 240          -- horizontal sweep speed across the screen
local GLITCH_SWOOP_SPEED_MULT <const> = 1.2
local GLITCH_SWOOP_FIRE_RATE_MULT <const> = 0.8
local SWOOP_DURATION <const> = 3.4        -- seconds from entry to exit (one dip)
local SWOOP_TOP <const> = -200            -- y at entry/exit (near the top)
local SWOOP_DIP <const> = 280             -- how far down the arc dips (lowest y = TOP + DIP)
local SWOOP_COUNT_MIN <const> = 3         -- normal ships per line (randomized MIN..MAX)
local SWOOP_COUNT_MAX <const> = 5
local SWOOP_SPACING <const> = 0.22        -- seconds between ships in the line
local FORMATION_INTERVAL_MIN <const> = 8.0
local FORMATION_INTERVAL_MAX <const> = 16.0

-- Glitch storm: every GLITCH_PERIOD seconds a brief GLITCH_WARN-second screen
-- glitch (a visual cue, the only time it shows) heralds a swarm. For the next
-- GLITCH_SWARM_DURATION seconds a single swooper enters every
-- SWARM_SPAWN_INTERVAL seconds — a steady stream, not bursts of formations.
local GLITCH_PERIOD <const> = 60.0
local GLITCH_WARN <const> = 0.5
local GLITCH_SWARM_DURATION <const> = 15.0
local SWARM_SPAWN_INTERVAL <const> = 0.33
local GLITCH_SWARM_SPAWN_INTERVAL <const> = SWARM_SPAWN_INTERVAL * 0.8

local UI_LAYER <const> = 15
local FONT_PATH <const> = "assets/fonts/press-start-2p.fnt"

-- Utility functions
local function randomRange(min: number, max: number): number
    return min + math.random() * (max - min)
end

local function parallaxFactor(depth: number): number
    return 0.9 - depth * 0.8
end

-- Sprite sheets are loaded by loadAssets once the tecs2d asset manager exists.
local playerSheet: render.SpriteSheet
local enemySheet: render.SpriteSheet
local playerBulletSheet: render.SpriteSheet
local enemyBulletSheet: render.SpriteSheet
local powerupHealthSheet: render.SpriteSheet
local powerupWeaponSheet: render.SpriteSheet
local asteroidBigSheet: render.SpriteSheet
local asteroidMedSheet: render.SpriteSheet
local asteroidSmallSheet: render.SpriteSheet
local explosionSheet: render.SpriteSheet

-- Mutable game state record shared across state plugins
local record GameState
    fireCooldown: number
    bulletCount: number
    score: number
    playerHp: number
    playerAlive: boolean
    playerId: integer
    distSinceLastEnemy: number
    formationCooldown: number
    glitchElapsed: number      -- time into the current storm, or -1 when inactive
    swarmSpawnTimer: number    -- countdown to the next swarm swooper
    currentForwardSpeed: number
    currentCameraOffsetY: number
    lastPlayerX: number
    lastPlayerY: number
    currentDir: string

    -- Function references set by game.tl
    updateScoreText: function()
    updateHealthText: function()
    spawnExplosion: function(x: number, y: number, kind?: string)
    hurtPlayer: function()
    spawnPlayer: function()
    restartGame: function()
    scrollStars: function(dt: number)
    flashHit: function(id: integer)
end

-- Export everything via a module record
local record shared
    -- Components
    Player: Player
    Star: Star
    Bullet: Bullet
    Powerup: Powerup
    EnemyBullet: EnemyBullet
    Enemy: Enemy
    Asteroid: Asteroid

    -- Enums
    type EnemyBehavior = EnemyBehavior

    -- Collision categories
    CAT_PLAYER: integer
    CAT_PLAYER_BULLET: integer
    CAT_ENEMY: integer
    CAT_ENEMY_BULLET: integer
    CAT_POWERUP: integer
    CAT_ASTEROID: integer

    -- Collision masks
    MASK_PLAYER: integer
    MASK_PLAYER_BULLET: integer
    MASK_ENEMY: integer
    MASK_ENEMY_BULLET: integer
    MASK_POWERUP: integer
    MASK_ASTEROID: integer

    -- Constants
    FORWARD_SPEED_SLOW: number
    FORWARD_SPEED_BASE: number
    FORWARD_SPEED_BOOST: number
    VIEW_WIDTH: number
    VIEW_HEIGHT: number
    CAMERA_OFFSET_Y_BASE: number
    CAMERA_OFFSET_Y_BOOST: number
    BUFFER: number
    NUM_STARS: number
    BULLET_SPEED: number
    BASE_FIRE_RATE: number
    POWERUP_SIZE: number
    ENEMY_HP: number
    ENEMY_FIRE_RATE_MIN: number
    ENEMY_FIRE_RATE_MAX: number
    ENEMY_BULLET_SPEED: number
    ENEMY_STRAFE_SPEED: number
    ENEMY_WANDER_SPEED: number
    ENEMY_SPAWN_INTERVAL: number
    PLAYER_MAX_HP: number
    ENEMY_KILL_SCORE: number
    POWERUP_SPAWN_INTERVAL: number
    ASTEROID_SPAWN_INTERVAL: number
    ASTEROID_DRIFT_SPEED: number
    ASTEROID_BIG_HP: number
    ASTEROID_MED_HP: number
    ASTEROID_SMALL_HP: number
    ASTEROID_SCORE: number
    START_BULLETS: number
    MAX_BULLETS: number
    POWERUP_DROP_CHANCE: number
    POWERUP_DROP_CHANCE_LOW: number
    SCROLL_SPEED: number
    ENEMY_DRIFT_SPEED: number
    ENEMY_SINE_AMPLITUDE: number
    ENEMY_SINE_FREQ: number
    POWERUP_DRIFT_SPEED: number
    PLAYER_MARGIN: number
    PLAYER_SPAWN_Y: number
    SWOOP_HSPEED: number
    GLITCH_SWOOP_SPEED_MULT: number
    GLITCH_SWOOP_FIRE_RATE_MULT: number
    SWOOP_DURATION: number
    SWOOP_TOP: number
    SWOOP_DIP: number
    SWOOP_COUNT_MIN: integer
    SWOOP_COUNT_MAX: integer
    SWOOP_SPACING: number
    FORMATION_INTERVAL_MIN: number
    FORMATION_INTERVAL_MAX: number
    GLITCH_PERIOD: number
    GLITCH_WARN: number
    GLITCH_SWARM_DURATION: number
    SWARM_SPAWN_INTERVAL: number
    GLITCH_SWARM_SPAWN_INTERVAL: number
    UI_LAYER: integer
    FONT_PATH: string

    -- Sprite sheets
    playerSheet: render.SpriteSheet
    enemySheet: render.SpriteSheet
    playerBulletSheet: render.SpriteSheet
    enemyBulletSheet: render.SpriteSheet
    powerupHealthSheet: render.SpriteSheet
    powerupWeaponSheet: render.SpriteSheet
    asteroidBigSheet: render.SpriteSheet
    asteroidMedSheet: render.SpriteSheet
    asteroidSmallSheet: render.SpriteSheet
    explosionSheet: render.SpriteSheet

    -- Utility functions
    randomRange: function(min: number, max: number): number
    parallaxFactor: function(depth: number): number
    loadAssets: function(world: tecs.World)

    -- Game state type
    type GameState = GameState

    -- Create a fresh game state
    newGameState: function(): GameState
end

-- Assign values
shared.Player = Player
shared.Star = Star
shared.Bullet = Bullet
shared.Powerup = Powerup
shared.EnemyBullet = EnemyBullet
shared.Enemy = Enemy
shared.Asteroid = Asteroid

shared.CAT_PLAYER = CAT_PLAYER
shared.CAT_PLAYER_BULLET = CAT_PLAYER_BULLET
shared.CAT_ENEMY = CAT_ENEMY
shared.CAT_ENEMY_BULLET = CAT_ENEMY_BULLET
shared.CAT_POWERUP = CAT_POWERUP
shared.CAT_ASTEROID = CAT_ASTEROID

shared.MASK_PLAYER = MASK_PLAYER
shared.MASK_PLAYER_BULLET = MASK_PLAYER_BULLET
shared.MASK_ENEMY = MASK_ENEMY
shared.MASK_ENEMY_BULLET = MASK_ENEMY_BULLET
shared.MASK_POWERUP = MASK_POWERUP
shared.MASK_ASTEROID = MASK_ASTEROID

shared.FORWARD_SPEED_SLOW = FORWARD_SPEED_SLOW
shared.FORWARD_SPEED_BASE = FORWARD_SPEED_BASE
shared.FORWARD_SPEED_BOOST = FORWARD_SPEED_BOOST
shared.VIEW_WIDTH = VIEW_WIDTH
shared.VIEW_HEIGHT = VIEW_HEIGHT
shared.CAMERA_OFFSET_Y_BASE = CAMERA_OFFSET_Y_BASE
shared.CAMERA_OFFSET_Y_BOOST = CAMERA_OFFSET_Y_BOOST
shared.BUFFER = BUFFER
shared.NUM_STARS = NUM_STARS
shared.BULLET_SPEED = BULLET_SPEED
shared.BASE_FIRE_RATE = BASE_FIRE_RATE
shared.POWERUP_SIZE = POWERUP_SIZE
shared.ENEMY_HP = ENEMY_HP
shared.ENEMY_FIRE_RATE_MIN = ENEMY_FIRE_RATE_MIN
shared.ENEMY_FIRE_RATE_MAX = ENEMY_FIRE_RATE_MAX
shared.ENEMY_BULLET_SPEED = ENEMY_BULLET_SPEED
shared.ENEMY_STRAFE_SPEED = ENEMY_STRAFE_SPEED
shared.ENEMY_WANDER_SPEED = ENEMY_WANDER_SPEED
shared.ENEMY_SPAWN_INTERVAL = ENEMY_SPAWN_INTERVAL
shared.PLAYER_MAX_HP = PLAYER_MAX_HP
shared.ENEMY_KILL_SCORE = ENEMY_KILL_SCORE
shared.POWERUP_SPAWN_INTERVAL = POWERUP_SPAWN_INTERVAL
shared.ASTEROID_SPAWN_INTERVAL = ASTEROID_SPAWN_INTERVAL
shared.ASTEROID_DRIFT_SPEED = ASTEROID_DRIFT_SPEED
shared.ASTEROID_BIG_HP = ASTEROID_BIG_HP
shared.ASTEROID_MED_HP = ASTEROID_MED_HP
shared.ASTEROID_SMALL_HP = ASTEROID_SMALL_HP
shared.ASTEROID_SCORE = ASTEROID_SCORE
shared.START_BULLETS = START_BULLETS
shared.MAX_BULLETS = MAX_BULLETS
shared.POWERUP_DROP_CHANCE = POWERUP_DROP_CHANCE
shared.POWERUP_DROP_CHANCE_LOW = POWERUP_DROP_CHANCE_LOW
shared.SCROLL_SPEED = SCROLL_SPEED
shared.ENEMY_DRIFT_SPEED = ENEMY_DRIFT_SPEED
shared.ENEMY_SINE_AMPLITUDE = ENEMY_SINE_AMPLITUDE
shared.ENEMY_SINE_FREQ = ENEMY_SINE_FREQ
shared.POWERUP_DRIFT_SPEED = POWERUP_DRIFT_SPEED
shared.PLAYER_MARGIN = PLAYER_MARGIN
shared.PLAYER_SPAWN_Y = PLAYER_SPAWN_Y
shared.SWOOP_HSPEED = SWOOP_HSPEED
shared.GLITCH_SWOOP_SPEED_MULT = GLITCH_SWOOP_SPEED_MULT
shared.GLITCH_SWOOP_FIRE_RATE_MULT = GLITCH_SWOOP_FIRE_RATE_MULT
shared.SWOOP_DURATION = SWOOP_DURATION
shared.SWOOP_TOP = SWOOP_TOP
shared.SWOOP_DIP = SWOOP_DIP
shared.SWOOP_COUNT_MIN = SWOOP_COUNT_MIN
shared.SWOOP_COUNT_MAX = SWOOP_COUNT_MAX
shared.SWOOP_SPACING = SWOOP_SPACING
shared.FORMATION_INTERVAL_MIN = FORMATION_INTERVAL_MIN
shared.FORMATION_INTERVAL_MAX = FORMATION_INTERVAL_MAX
shared.GLITCH_PERIOD = GLITCH_PERIOD
shared.GLITCH_WARN = GLITCH_WARN
shared.GLITCH_SWARM_DURATION = GLITCH_SWARM_DURATION
shared.SWARM_SPAWN_INTERVAL = SWARM_SPAWN_INTERVAL
shared.GLITCH_SWARM_SPAWN_INTERVAL = GLITCH_SWARM_SPAWN_INTERVAL
shared.UI_LAYER = UI_LAYER
shared.FONT_PATH = FONT_PATH

shared.playerSheet = playerSheet
shared.enemySheet = enemySheet
shared.playerBulletSheet = playerBulletSheet
shared.enemyBulletSheet = enemyBulletSheet
shared.powerupHealthSheet = powerupHealthSheet
shared.powerupWeaponSheet = powerupWeaponSheet
shared.asteroidBigSheet = asteroidBigSheet
shared.asteroidMedSheet = asteroidMedSheet
shared.asteroidSmallSheet = asteroidSmallSheet
shared.explosionSheet = explosionSheet

shared.randomRange = randomRange
shared.parallaxFactor = parallaxFactor

local function pinSheet(handle: assets.Handle<render.SpriteSheet>): render.SpriteSheet
    handle:pin()
    return handle.value
end

function shared.loadAssets(world: tecs.World)
    local manager = world.resources[assets]

    local fontHandle = manager:loadBMFont("fonts/press-start-2p.fnt")
    fontHandle:pin()

    shared.playerSheet = pinSheet(manager:loadStaticSheet("images/player.png"))
    shared.enemySheet = pinSheet(manager:loadStaticSheet("images/enemy.png"))
    shared.playerBulletSheet = pinSheet(manager:loadStaticSheet("images/playerBullet.png"))
    shared.enemyBulletSheet = pinSheet(manager:loadStaticSheet("images/enemyBullet.png"))
    shared.powerupHealthSheet = pinSheet(manager:loadStaticSheet("images/powerupHealth.png"))
    shared.powerupWeaponSheet = pinSheet(manager:loadStaticSheet("images/powerupWeapon.png"))
    shared.asteroidBigSheet = pinSheet(manager:loadStaticSheet("images/asteroidBig.png"))
    shared.asteroidMedSheet = pinSheet(manager:loadStaticSheet("images/asteroidMed.png"))
    shared.asteroidSmallSheet = pinSheet(manager:loadStaticSheet("images/asteroidSmall.png"))
    shared.explosionSheet = pinSheet(manager:loadSpriteSheet("images/explosionAsteroid.png"))
end

function shared.newGameState(): GameState
    return {
        fireCooldown = 0.0,
        bulletCount = START_BULLETS,
        score = 0,
        playerHp = PLAYER_MAX_HP,
        playerAlive = true,
        playerId = 0,
        distSinceLastEnemy = 500.0,
        formationCooldown = 5.0,
        glitchElapsed = -1.0,
        swarmSpawnTimer = 0.0,
        currentForwardSpeed = FORWARD_SPEED_BASE,
        currentCameraOffsetY = CAMERA_OFFSET_Y_BASE,
        lastPlayerX = 0.0,
        lastPlayerY = 0.0,
        currentDir = "idle",
    }
end

return shared
