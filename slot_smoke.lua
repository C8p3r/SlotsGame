-- slot_smoke.lua
local Config = require("conf")

local SlotSmoke = {}
local Slots = nil -- Reference injected by setSlotMachineModule

local SMOKE_PARTICLE_COUNT = 3000
local PARTICLE_TEXTURE_SIZE = 64
local SMOKE_BASE_RATE = 20.0
local SMOKE_MAX_RATE = 200.0
local BREAK_PUFF_EMISSION = 2000 
local BREAK_PUFF_DURATION = 0.1 

local particle_systems = {} 
local particle_texture
local last_streak = 0
local current_puff_timer = 0.0

local current_emission_rate = SMOKE_BASE_RATE
local current_speed_mod = 1.0
local LERP_RATE = 2.0

local function smooth_transition(current, target, dt)
    return current + (target - current) * math.min(1.0, LERP_RATE * dt)
end

local function create_smoke_texture()
    local size = PARTICLE_TEXTURE_SIZE
    local data = love.image.newImageData(size, size)
    local center = size / 2
    
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - center) / center
            local dy = (y - center) / center
            local dist = math.sqrt(dx*dx + dy*dy)
            
            local alpha = math.max(0, 1 - dist)
            alpha = alpha * alpha * alpha * 0.7 
            
            data:setPixel(x, y, 0.5, 0.5, 0.5, alpha) 
        end
    end
    
    return love.graphics.newImage(data)
end

local function create_slot_smoke_system(x_center, slot_y, slot_h)
    local ps = love.graphics.newParticleSystem(particle_texture, SMOKE_PARTICLE_COUNT)
    ps:setPosition(x_center, slot_y) 
    local emitter_width = Config.SLOT_WIDTH / 3 
    ps:setEmissionArea('uniform', emitter_width, slot_h / 8) 
    ps:setParticleLifetime(1.5, 3.0) 
    ps:setLinearAcceleration(-10, -50, 10, -100) 
    ps:setSpeed(10, 30)
    ps:setDirection(-math.pi / 2) 
    ps:setSpread(math.pi / 2)
    ps:setColors(0.8, 0.8, 0.8, 0.25, 0.5, 0.5, 0.5, 0.15, 0.2, 0.2, 0.2, 0.05, 0.0, 0.0, 0.0, 0)
    ps:setSizes(1.5, 3.0, 0.0) 
    ps:setEmissionRate(SMOKE_BASE_RATE)
    return ps
end


function SlotSmoke.load()
    if not particle_texture then
        particle_texture = create_smoke_texture()
    end
    
    local num_slots = Config.SLOT_COUNT
    local total_width = (num_slots * Config.SLOT_WIDTH) + ((num_slots - 1) * Config.SLOT_GAP)
    local start_x = (Config.GAME_WIDTH - total_width) / 2
    local x_walker = start_x
    
    particle_systems = {}
    for i = 1, num_slots do
        local x_center = x_walker + Config.SLOT_WIDTH / 2
        particle_systems[i] = create_slot_smoke_system(x_center, Config.SLOT_Y, Config.SLOT_HEIGHT)
        x_walker = x_walker + Config.SLOT_WIDTH + Config.SLOT_GAP
    end
    
    if Slots then
        last_streak = Slots.getConsecutiveWins()
    end
end

function SlotSmoke.update(dt)
    if not Slots then return end
    local current_streak = Slots.getConsecutiveWins()
    
    if current_streak < 0 and last_streak >= 1 then
        current_puff_timer = BREAK_PUFF_DURATION
    end
    
    local positive_streak = math.max(0, current_streak)
    local max_cap = 10
    local multiplier = math.min(1.0, positive_streak / max_cap)
    
    local target_emission = SMOKE_BASE_RATE + (SMOKE_MAX_RATE * multiplier)
    
    current_emission_rate = smooth_transition(current_emission_rate, target_emission, dt)
    
    local final_emission = current_emission_rate
    
    if current_puff_timer > 0 then
        final_emission = final_emission + BREAK_PUFF_EMISSION 
        current_puff_timer = current_puff_timer - dt
        current_emission_rate = SMOKE_BASE_RATE 
    end
    
    for _, ps in ipairs(particle_systems) do
        ps:setEmissionRate(final_emission)
        ps:update(dt)
    end
    
    last_streak = current_streak
end

function SlotSmoke.draw()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1) 
    for _, ps in ipairs(particle_systems) do
        love.graphics.draw(ps, 0, 0) 
    end
end

function SlotSmoke.setSlotMachineModule(module)
    Slots = module
end

return SlotSmoke