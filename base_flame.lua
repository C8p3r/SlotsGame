-- base_flame.lua
local Config = require("conf")
local SlotMachine = require("slot_machine") -- Assuming this contains getConsecutiveWins()
local BackgroundRenderer = require("background_renderer")

local BaseFlame = {}

local particle_sys = nil
local particle_sys_edges_left = nil  -- Left edge flames
local particle_sys_edges_right = nil  -- Right edge flames
local particle_texture = nil
local texture_size = 32 -- Smaller texture for subtle base glow
-- (pixelation removed)

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
local WHITE_HOT_START = {0.0, 0.0, 0.0, 0.5} -- Bright Black-Grey
local WHITE_HOT_MID = {0.1, 0.0, 0.1, 0.3}  -- Dark Purple
local WHITE_HOT_END = {0.0, 0.0, 0.0, 0.1}  -- Black fade

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

-- Helper to convert RGB to HSV
local function rgb_to_hsv(rgb)
    local r, g, b = rgb[1], rgb[2], rgb[3]
    local max_val = math.max(r, g, b)
    local min_val = math.min(r, g, b)
    local delta = max_val - min_val
    
    local h = 0
    if delta > 0 then
        if max_val == r then
            h = (g - b) / delta
            if h < 0 then h = h + 6 end
        elseif max_val == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h / 6
    end
    
    local s = max_val > 0 and (delta / max_val) or 0
    local v = max_val
    
    return {h, s, v, rgb[4]}  -- Include alpha
end

-- Helper to convert HSV to RGB
local function hsv_to_rgb(hsv)
    local h, s, v = hsv[1], hsv[2], hsv[3]
    local c = v * s
    local hp = h * 6.0
    local x = c * (1.0 - math.abs(math.fmod(hp, 2.0) - 1.0))
    
    local r, g, b = 0, 0, 0
    if hp < 1.0 then
        r, g, b = c, x, 0
    elseif hp < 2.0 then
        r, g, b = x, c, 0
    elseif hp < 3.0 then
        r, g, b = 0, c, x
    elseif hp < 4.0 then
        r, g, b = 0, x, c
    elseif hp < 5.0 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    
    local m = v - c
    return {r + m, g + m, b + m, hsv[4]}  -- Include alpha
end

-- Helper to shift hue of a color
local function apply_hue(rgb_color, target_hue)
    local hsv = rgb_to_hsv(rgb_color)
    hsv[1] = target_hue
    return hsv_to_rgb(hsv)
end

-- Helper to apply complementary hue and boost brightness for visibility
local function apply_hue_complementary(rgb_color, target_hue)
    local hsv = rgb_to_hsv(rgb_color)
    -- Shift to complementary hue (opposite on color wheel)
    hsv[1] = math.fmod(target_hue + 0.5, 1.0)
    -- Boost saturation and brightness for visibility
    hsv[2] = math.min(1.0, hsv[2] * 1.2)  -- Increase saturation by 20%
    hsv[3] = math.min(1.0, hsv[3] * 1.15)  -- Increase brightness by 15%
    return hsv_to_rgb(hsv)
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
    
    -- Edge particle systems for taller flames at screen edges
    -- Calculate edge width based on screen width (more pronounced on ultrawide)
    local edge_width = math.max(200, game_w * 0.15)  -- 15% of width or 200px, whichever is larger
    
    -- LEFT EDGE FLAMES
    particle_sys_edges_left = love.graphics.newParticleSystem(particle_texture, 2000)
    particle_sys_edges_left:setEmissionArea('borderrectangle', edge_width, 1)
    particle_sys_edges_left:setPosition(edge_width / 2, game_h)  -- Left side
    
    -- RIGHT EDGE FLAMES
    particle_sys_edges_right = love.graphics.newParticleSystem(particle_texture, 2000)
    particle_sys_edges_right:setEmissionArea('borderrectangle', edge_width, 1)
    particle_sys_edges_right:setPosition(game_w - edge_width / 2, game_h)  -- Right side
    
    -- Initialize color states to the BASE color
    current_c_start = BASE_COLOR_START
    current_c_mid = BASE_COLOR_MID
    current_c_end = BASE_COLOR_END
    
    -- Base settings (set to minimums, will be boosted by update)
    particle_sys:setParticleLifetime(1.0, 2.0)
    particle_sys_edges_left:setParticleLifetime(1.2, 2.5)  -- Longer lifetime for edge flames
    particle_sys_edges_right:setParticleLifetime(1.2, 2.5)  -- Longer lifetime for edge flames
    
    -- Start with aggressive horizontal acceleration to ensure corner coverage
    particle_sys:setLinearAcceleration(-150, -50, 150, -100) 
    particle_sys_edges_left:setLinearAcceleration(-400, -150, 50, -250)  -- Aggressive outward/upward on left
    particle_sys_edges_right:setLinearAcceleration(-50, -150, 400, -250)  -- Aggressive outward/upward on right
    
    particle_sys:setSpeed(0, 10)
    particle_sys_edges_left:setSpeed(0, 25)  -- Very fast upward movement for edges
    particle_sys_edges_right:setSpeed(0, 25)  -- Very fast upward movement for edges
    particle_sys:setDirection(-math.pi / 2) 
    particle_sys_edges_left:setDirection(-math.pi / 2) 
    particle_sys_edges_right:setDirection(-math.pi / 2) 
    particle_sys:setSpread(math.pi / 4)
    
    particle_sys:setColors(current_c_start[1], current_c_start[2], current_c_start[3], current_c_start[4], 
                           current_c_mid[1], current_c_mid[2], current_c_mid[3], current_c_mid[4], 
                           current_c_end[1], current_c_end[2], current_c_end[3], current_c_end[4], 
                           0.0, 0.0, 0.0, 0)
    
    -- Initial larger size for better corner visibility
    particle_sys:setSizes(2.0, 3.5, 0.0) 
    particle_sys:setEmissionRate(1000)
    particle_sys:setSpin(0, 0)

    -- no additional canvas or pixelation for base flame
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
            -- POSITIVE STREAK (Shift to Blue Fire and more LICKING flames)
            local multiplier = math.min(10, streak)
            
            -- T aggressively hits 1.0 at streak 2
            local T = math.min(1.0, (streak - 1) / 1.0) 
            
            -- LINEAR SCALING for more controlled growth with more licking effect
            -- Increase emission significantly to create more individual flames
            target_emission = 1500 + (multiplier * 300)
            
            -- Color Interpolation (Orange -> Blue)
            target_c_start = lerp_color(BASE_COLOR_START, BLUE_COLOR_START, T)
            target_c_mid = lerp_color(BASE_COLOR_MID, BLUE_COLOR_MID, T)
            target_c_end = lerp_color(BASE_COLOR_END, BLUE_COLOR_END, T)
            
            -- Physics Scaling - keep particle sizes SMALLER for licking effect
            local mult_factor = 1.0 + (multiplier * 0.05)
            life_base = 0.8 * mult_factor
            accel_y_min = -60 - (multiplier * 15)
            accel_y_max = -120 - (multiplier * 25)
            
            -- LINEAR boost to acceleration spread (more horizontal movement)
            target_accel_x_spread = base_accel_x_spread + (multiplier * 60)
            -- KEEP sizes smaller for more numerous, licking flames instead of larger blobs
            target_start_size = base_start_size + (multiplier * 0.15)
            target_end_size = base_end_size + (multiplier * 0.20) 

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
        
        -- Apply background hue to flame colors
        local bg_hue = BackgroundRenderer.getCurrentHue()
        local hued_c_start = apply_hue_complementary(current_c_start, bg_hue)
        local hued_c_mid = apply_hue_complementary(current_c_mid, bg_hue)
        local hued_c_end = apply_hue_complementary(current_c_end, bg_hue)

        -- 5. Apply Smoothed Properties to Particle System
        particle_sys:setEmissionRate(current_emission)
        particle_sys:setParticleLifetime(life_base, life_base * 1.5)
        
        -- Use the aggressive X spread setting
        particle_sys:setLinearAcceleration(-current_accel_x_spread, accel_y_min, current_accel_x_spread, accel_y_max)
        
        -- Apply dynamic sizes
        particle_sys:setSizes(current_start_size, current_end_size, 0.0)
        
        -- Apply dynamic colors (with background hue applied)
        particle_sys:setColors(
            hued_c_start[1], hued_c_start[2], hued_c_start[3], hued_c_start[4],
            hued_c_mid[1], hued_c_mid[2], hued_c_mid[3], hued_c_mid[4],
            hued_c_end[1], hued_c_end[2], hued_c_end[3], hued_c_end[4],
            0.0, 0.0, 0.0, 0
        )
        
        -- Apply edge flames with exponentially increased intensity
        -- Edge emission scales exponentially with streak
        local abs_streak = math.abs(streak)
        local edge_emission_multiplier = 1.0
        if streak >= 2 then
            -- Exponential scaling: 2x at streak 2, 4x at streak 4, 8x at streak 6, etc.
            edge_emission_multiplier = math.pow(2, (streak - 1) / 2)
        elseif streak <= -2 then
            -- Less intense for negative streaks
            edge_emission_multiplier = 0.6
        else
            edge_emission_multiplier = 0.5
        end
        
        local edge_emission_rate = current_emission * edge_emission_multiplier
        
        particle_sys_edges_left:setEmissionRate(edge_emission_rate)
        particle_sys_edges_left:setParticleLifetime(life_base * 1.4, life_base * 2.2)  -- Longer lived
        particle_sys_edges_left:setLinearAcceleration(-current_accel_x_spread * 1.5, accel_y_min * 1.4, 50, accel_y_max * 1.4)
        particle_sys_edges_left:setSizes(current_start_size * 1.2, current_end_size * 1.4, 0.0)  -- Larger particles
        particle_sys_edges_left:setColors(
            hued_c_start[1], hued_c_start[2], hued_c_start[3], hued_c_start[4],
            hued_c_mid[1], hued_c_mid[2], hued_c_mid[3], hued_c_mid[4],
            hued_c_end[1], hued_c_end[2], hued_c_end[3], hued_c_end[4],
            0.0, 0.0, 0.0, 0
        )
        
        particle_sys_edges_right:setEmissionRate(edge_emission_rate)
        particle_sys_edges_right:setParticleLifetime(life_base * 1.4, life_base * 2.2)  -- Longer lived
        particle_sys_edges_right:setLinearAcceleration(-50, accel_y_min * 1.4, current_accel_x_spread * 1.5, accel_y_max * 1.4)
        particle_sys_edges_right:setSizes(current_start_size * 1.2, current_end_size * 1.4, 0.0)  -- Larger particles
        particle_sys_edges_right:setColors(
            hued_c_start[1], hued_c_start[2], hued_c_start[3], hued_c_start[4],
            hued_c_mid[1], hued_c_mid[2], hued_c_mid[3], hued_c_mid[4],
            hued_c_end[1], hued_c_end[2], hued_c_end[3], hued_c_end[4],
            0.0, 0.0, 0.0, 0
        )
        
        particle_sys:update(dt)
        particle_sys_edges_left:update(dt)
        particle_sys_edges_right:update(dt)
    end
end

function BaseFlame.draw()
    if particle_sys then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 1) 
        love.graphics.draw(particle_sys, 0, 0)  -- Center flames
        love.graphics.draw(particle_sys_edges_left, 0, 0)  -- Left edge flames
        love.graphics.draw(particle_sys_edges_right, 0, 0)  -- Right edge flames
        love.graphics.setBlendMode("alpha")
    end
end

return BaseFlame