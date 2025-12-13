-- base_flame.lua
local Config = require("conf")
local SlotMachine = require("slot_machine") -- Assuming this contains getConsecutiveWins()

local BaseFlame = {}

local particle_sys = nil
local particle_texture = nil
local texture_size = 32 -- Smaller texture for subtle base glow

-- NEW: Smoothing parameters
local SMOOTH_RATE = 3.0 -- Rate of smoothing (3.0 is moderate smoothing)
local current_emission = 1000
local current_accel_x_spread = 150
local current_start_size = 2.0
local current_end_size = 3.5

-- Base colors will be initialized dynamically
local current_c_start = {}
local current_c_mid = {}
local current_c_end = {}


-- BASE COLORS FOR INTERPOLATION
-- Orange/Red Base (Streak 0)
local BASE_COLOR_START = {0.8, 0.4, 0.1, 0.4}
local BASE_COLOR_MID = {0.5, 0.2, 0.1, 0.2}
local BASE_COLOR_END = {0.2, 0.1, 0.05, 0.05}

-- WHITE HOT TARGET (Streak 1 specific)
local WHITE_HOT_START = {1.0, 1.0, 0.8, 0.5} -- Bright White-Yellow
local WHITE_HOT_MID = {1.0, 0.8, 0.3, 0.3}  -- Light Orange
local WHITE_HOT_END = {0.8, 0.2, 0.1, 0.1}  -- Red/Pink fade

-- Blue Shift Target (Positive Streak Max)
local BLUE_COLOR_START = {0.2, 0.8, 1.0, 0.6} -- Cyan/Blue core
local BLUE_COLOR_MID = {0.1, 0.4, 0.8, 0.3}
local BLUE_COLOR_END = {0.05, 0.1, 0.3, 0.1}

-- Smoke Shift Target (Negative Streak Max)
local SMOKE_COLOR_START = {0.2, 0.2, 0.2, 0.1} -- Dark grey, very translucent
local SMOKE_COLOR_MID = {0.1, 0.1, 0.1, 0.05}
local SMOKE_COLOR_END = {0.05, 0.05, 0.05, 0.01}

-- Interpolates between two colors based on T (0 to 1)
local function lerp_color(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        c1[4] + (c2[4] - c1[4]) * t,
    }
end

-- Helper for smoothing scalar values
local function smooth_transition(current, target, dt)
    return current + (target - current) * math.min(1.0, SMOOTH_RATE * dt)
end

-- Helper to create a soft circle texture programmatically
local function create_glow_texture()
    local size = texture_size 
    local data = love.image.newImageData(size, size)
    local center = size / 2
    
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - center) / center
            local dy = (y - center) / center
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Softer Cubic falloff
            local alpha = math.max(0, 1 - dist)
            alpha = alpha * alpha * alpha
            
            data:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    
    return love.graphics.newImage(data)
end

function BaseFlame.load()
    if not particle_texture then
        particle_texture = create_glow_texture()
    end
    
    local game_w = Config.GAME_WIDTH
    local game_h = Config.GAME_HEIGHT
    
    particle_sys = love.graphics.newParticleSystem(particle_texture, 2000) 
    
    particle_sys:setEmissionArea('borderrectangle', game_w, 1) 
    particle_sys:setPosition(game_w / 2, game_h) 
    
    -- Initialize color states to the BASE color
    current_c_start = BASE_COLOR_START
    current_c_mid = BASE_COLOR_MID
    current_c_end = BASE_COLOR_END
    
    -- Base settings (set to minimums, will be boosted by update)
    particle_sys:setParticleLifetime(1.0, 2.0)
    
    -- Start with aggressive horizontal acceleration to ensure corner coverage
    particle_sys:setLinearAcceleration(-150, -50, 150, -100) 
    
    particle_sys:setSpeed(0, 10)
    particle_sys:setDirection(-math.pi / 2) 
    particle_sys:setSpread(math.pi / 4)
    
    particle_sys:setColors(current_c_start[1], current_c_start[2], current_c_start[3], current_c_start[4], 
                           current_c_mid[1], current_c_mid[2], current_c_mid[3], current_c_mid[4], 
                           current_c_end[1], current_c_end[2], current_c_end[3], current_c_end[4], 
                           0.0, 0.0, 0.0, 0)
    
    -- Initial larger size for better corner visibility
    particle_sys:setSizes(2.0, 3.5, 0.0) 
    particle_sys:setEmissionRate(1000)
    particle_sys:setSpin(0, 0)
end

function BaseFlame.update(dt)
    if particle_sys then
        local streak = SlotMachine.getConsecutiveWins() or 0
        local abs_streak = math.abs(streak)
        
        -- Target Properties (Calculated Instantly)
        local target_emission
        local target_accel_x_spread 
        local target_start_size
        local target_end_size
        
        local life_base, accel_y_min, accel_y_max
        local target_c_start, target_c_mid, target_c_end
        
        -- Base horizontal acceleration for corner dominance
        local base_accel_x_spread = 150 
        local base_start_size = 2.0
        local base_end_size = 3.5
        
        if streak >= 2 then
            -- POSITIVE STREAK (Shift to Blue Fire and EXPONENTIAL increase)
            local multiplier = math.min(10, streak)
            
            -- T aggressively hits 1.0 at streak 2
            local T = math.min(1.0, (streak - 1) / 1.0) 
            
            -- EXPONENTIAL SCALING
            local exp_boost = multiplier * multiplier * 0.5 
            
            target_emission = 1000 + (multiplier * 200)
            
            -- Color Interpolation (Orange -> Blue)
            target_c_start = lerp_color(BASE_COLOR_START, BLUE_COLOR_START, T)
            target_c_mid = lerp_color(BASE_COLOR_MID, BLUE_COLOR_MID, T)
            target_c_end = lerp_color(BASE_COLOR_END, BLUE_COLOR_END, T)
            
            -- Physics Scaling
            local mult_factor = 1.0 + (multiplier * 0.1)
            life_base = 1.0 * mult_factor
            accel_y_min = -50 - (multiplier * 20)
            accel_y_max = -100 - (multiplier * 40)
            
            -- Apply EXPONENTIAL boost
            target_accel_x_spread = base_accel_x_spread + (multiplier * 50) + exp_boost * 30 
            target_start_size = base_start_size + (multiplier * 0.3) + exp_boost * 0.2 
            target_end_size = base_end_size + (multiplier * 0.5) + exp_boost * 0.4 

        elseif streak == 1 then
             -- STREAK 1: WHITE HOT
            target_emission = 1500 
            life_base = 1.2
            accel_y_min = -80
            accel_y_max = -150
            target_accel_x_spread = 200 
            
            target_c_start = WHITE_HOT_START
            target_c_mid = WHITE_HOT_MID
            target_c_end = WHITE_HOT_END
            
            target_start_size = 2.5
            target_end_size = 4.0

        elseif streak <= -2 then
            -- NEGATIVE STREAK (Shift to Translucent Smoke)
            local multiplier = math.min(10, abs_streak)
            
            -- T aggressively hits 1.0 at streak -2
            local T = math.min(1.0, (abs_streak - 1) / 1.0)
            
            target_emission = 1000 + (multiplier * 50) 
            
            -- Color Interpolation (Orange -> Smoke Grey)
            target_c_start = lerp_color(BASE_COLOR_START, SMOKE_COLOR_START, T)
            target_c_mid = lerp_color(BASE_COLOR_MID, SMOKE_COLOR_MID, T)
            target_c_end = lerp_color(BASE_COLOR_END, SMOKE_COLOR_END, T)

            -- Physics Scaling (Slightly slower, longer lived smoke)
            life_base = 1.0 + (multiplier * 0.2)
            accel_y_min = -30 - (multiplier * 10)
            accel_y_max = -80 - (multiplier * 20)
            
            target_accel_x_spread = 100 + (multiplier * 30)
            target_start_size = base_start_size
            target_end_size = base_end_size

        else -- Streak is -1, 0 (Base orange/red)
            target_emission = 1000
            life_base = 1.0
            accel_y_min = -50
            accel_y_max = -100
            target_c_start = BASE_COLOR_START
            target_c_mid = BASE_COLOR_MID
            target_c_end = BASE_COLOR_END
            
            target_accel_x_spread = base_accel_x_spread
            target_start_size = base_start_size
            target_end_size = base_end_size
        end
        
        -- 4. Apply Smoothing (LERP) to all properties
        
        -- Scalar smoothing
        current_emission = smooth_transition(current_emission, target_emission, dt)
        current_accel_x_spread = smooth_transition(current_accel_x_spread, target_accel_x_spread, dt)
        current_start_size = smooth_transition(current_start_size, target_start_size, dt)
        current_end_size = smooth_transition(current_end_size, target_end_size, dt)
        
        -- Color array smoothing
        current_c_start = lerp_color(current_c_start, target_c_start, SMOOTH_RATE * dt)
        current_c_mid = lerp_color(current_c_mid, target_c_mid, SMOOTH_RATE * dt)
        current_c_end = lerp_color(current_c_end, target_c_end, SMOOTH_RATE * dt)
        

        -- 5. Apply Smoothed Properties to Particle System
        particle_sys:setEmissionRate(current_emission)
        particle_sys:setParticleLifetime(life_base, life_base * 1.5)
        
        -- Use the aggressive X spread setting
        particle_sys:setLinearAcceleration(-current_accel_x_spread, accel_y_min, current_accel_x_spread, accel_y_max)
        
        -- Apply dynamic sizes
        particle_sys:setSizes(current_start_size, current_end_size, 0.0)
        
        -- Apply dynamic colors
        particle_sys:setColors(
            current_c_start[1], current_c_start[2], current_c_start[3], current_c_start[4],
            current_c_mid[1], current_c_mid[2], current_c_mid[3], current_c_mid[4],
            current_c_end[1], current_c_end[2], current_c_end[3], current_c_end[4],
            0.0, 0.0, 0.0, 0
        )
        
        particle_sys:update(dt)
    end
end

function BaseFlame.draw()
    if particle_sys then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 1) 
        love.graphics.draw(particle_sys, 0, 0) 
        love.graphics.setBlendMode("alpha")
    end
end

return BaseFlame