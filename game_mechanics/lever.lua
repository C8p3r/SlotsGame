-- lever.lua
local Config = require("conf")
local SlotMachine = require("game_mechanics.slot_machine") -- Needed for streak info
local BackgroundRenderer = require("systems.background_renderer")
local ParticleSystem = require("systems.particle_system")

local Lever = {}

-- State
local knob_y = 0 
local emitter_y = 0 
local LERP_RATE = 8.0 
local is_dragging = false
local is_auto_pulling = false
local on_trigger_callback = nil
local drag_offset_y = 0

-- Physics
local RETURN_SPEED = 1500 
local PULL_SPEED = 2000   
local TRIGGER_THRESHOLD = 0.85 
local JAM_MOVEMENT_LIMIT = 1/3 -- NEW: Limit movement to 1/3rd when jammed

-- PARTICLE SYSTEM
local particle_sys
local particle_texture
local last_intensity = 0 
local flare_timer = 0.0

-- Current operating properties for smooth transitions
local TRANSITION_RATE = 1.5 -- SMOOTHER TRANSITION
local current_emission = 50
local current_accel_x = 0
local current_accel_y_min = -150
local current_accel_y_max = -250
local current_life_min = 0.5
local current_life_max = 1.0

-- Current color state arrays
local current_c_start = {}
local current_c_mid = {}
local current_c_end = {}

-- FIX: MOVED COLOR DEFINITIONS HERE TO ENSURE GLOBAL SCOPE AVAILABILITY
-- ADJUSTED ALPHAS (4th component) for greater transparency
local COLOR_HOT_START = {1.0, 0.8, 0.2, 0.3} -- Reduced from 0.5
local COLOR_HOT_MID = {1.0, 0.4, 0.0, 0.15} -- Reduced from 0.3
local COLOR_HOT_END = {0.8, 0.1, 0.1, 0.05} -- Reduced from 0.1

local COLOR_BLUE_START = {0.2, 1.0, 1.0, 0.4} -- Reduced from 0.7
local COLOR_BLUE_MID = {0.2, 0.5, 1.0, 0.15} -- Reduced from 0.3
local COLOR_BLUE_END = {0.0, 0.1, 0.5, 0.05} -- Reduced from 0.1

local SMOKE_BASE_START = {0.3, 0.3, 0.3, 0.15} -- Reduced from 0.3
local SMOKE_BASE_MID = {0.1, 0.1, 0.1, 0.1}   -- Reduced from 0.2
local SMOKE_BASE_END = {0.05, 0.05, 0.05, 0.03} -- Reduced from 0.05


local function create_glow_texture()
    local size = 64 
    local data = love.image.newImageData(size, size)
    local center = size / 2
    
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - center) / center
            local dy = (y - center) / center
            local dist = math.sqrt(dx*dx + dy*dy)
            
            local alpha = math.max(0, 1 - dist)
            alpha = alpha * alpha * alpha
            
            data:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    
    return love.graphics.newImage(data)
end

function Lever.load()
    knob_y = 0 
    emitter_y = 0 
    is_dragging = false
    is_auto_pulling = false
    on_trigger_callback = nil
    last_intensity = 0
    flare_timer = 0.0
    
    -- Initialize current color states
    current_c_start = {COLOR_HOT_START[1], COLOR_HOT_START[2], COLOR_HOT_START[3], COLOR_HOT_START[4]}
    current_c_mid = {COLOR_HOT_MID[1], COLOR_HOT_MID[2], COLOR_HOT_MID[3], COLOR_HOT_MID[4]}
    current_c_end = {COLOR_HOT_END[1], COLOR_HOT_END[2], COLOR_HOT_END[3], COLOR_HOT_END[4]}
    
    -- Load particles via consolidated particle system
    ParticleSystem.load()
end

function Lever.trigger(callback)
    if is_dragging or is_auto_pulling or SlotMachine.is_jammed() then return end -- PREVENT AUTO PULL IF JAMMED
    is_auto_pulling = true
    on_trigger_callback = callback
end

-- Interpolates between two colors based on T (0 to 1)
local function lerp_color(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        c1[4] + (c2[4] - c1[4]) * t,
    }
end

-- Helper to smooth value changes
local function smooth_transition(current, target, dt)
    return current + (target - current) * math.min(1.0, TRANSITION_RATE * dt)
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


function Lever.update(dt)
    -- Get reference to particle system
    local particle_sys = ParticleSystem.get_lever_particle_system()
    
    -- 1. Determine maximum allowed lever movement
    local max_movement = Config.LEVER_TRACK_HEIGHT
    if SlotMachine.is_jammed() then
        max_movement = Config.LEVER_TRACK_HEIGHT * JAM_MOVEMENT_LIMIT -- Limit to 1/3rd
    end

    -- 2. Handle Lever Physics (Update knob_y first)
    if is_dragging then
        -- Mouse control, clamped below
    elseif is_auto_pulling then
        knob_y = knob_y + (PULL_SPEED * dt)
        if knob_y >= Config.LEVER_TRACK_HEIGHT then
            knob_y = Config.LEVER_TRACK_HEIGHT
            is_auto_pulling = false
            if on_trigger_callback then
                on_trigger_callback()
                on_trigger_callback = nil
            end
        end
    else
        -- Return physics always applies unless dragging or auto-pulling
        if knob_y > 0 then
            knob_y = knob_y - (RETURN_SPEED * dt)
            if knob_y < 0 then knob_y = 0 end
        end
    end
    
    -- Apply Jam Limit to Knob Y (instantaneous clamp)
    if knob_y > max_movement then
        knob_y = max_movement
    end

    -- 3. Smooth Emitter Position (LERP)
    local lerp_amount = math.min(1.0, LERP_RATE * dt)
    emitter_y = emitter_y + (knob_y - emitter_y) * lerp_amount
    
    -- 4. Determine TARGET Particle System Properties
    local streak = SlotMachine.getConsecutiveWins()
    local abs_streak = math.abs(streak)
    
    local target_emission
    local target_accel_x
    local target_accel_y_min
    local target_accel_y_max
    local target_life_min
    local target_life_max
    
    local target_c_start, target_c_mid, target_c_end
    local current_intensity 
    
    if streak > 0 then
        -- POSITIVE STREAK (FIRE)
        local multiplier = math.min(streak, 20) 
        current_intensity = multiplier
        
        target_emission = 50 + (multiplier * 50) 
        local spread_x = 20 + (multiplier * 5)
        target_accel_x = spread_x
        target_accel_y_min = -200 - (multiplier * 40); target_accel_y_max = -400 - (multiplier * 80)
        target_life_min = 0.8 + (multiplier * 0.05); target_life_max = 1.5 + (multiplier * 0.1)
        
        local T = math.min(1.0, abs_streak / 3.0) 
        target_c_start = lerp_color(COLOR_HOT_START, COLOR_BLUE_START, T)
        target_c_mid = lerp_color(COLOR_HOT_MID, COLOR_BLUE_MID, T)
        target_c_end = lerp_color(COLOR_HOT_END, COLOR_BLUE_END, T)

    elseif streak < 0 then
        -- NEGATIVE STREAK (SMOKE)
        local multiplier = math.min(abs_streak, 10) 
        current_intensity = -multiplier
        
        local T_fading = math.min(1.0, abs_streak / 5.0) 
        target_emission = math.max(10, 150 - (T_fading * 140))
        local spread_x = 30 + (multiplier * 10)
        target_accel_x = spread_x
        target_accel_y_min = -80 - (multiplier * 20); target_accel_y_max = -150 - (multiplier * 40)
        target_life_min = 1.0; target_life_max = 2.0 
        
        -- Use linear interpolation on the alpha based on base smoke alpha
        local start_alpha = SMOKE_BASE_START[4] - (SMOKE_BASE_START[4] - 0.03) * T_fading 
        local mid_alpha = SMOKE_BASE_MID[4] - (SMOKE_BASE_MID[4] - 0.02) * T_fading
        local end_alpha = SMOKE_BASE_END[4]
        
        target_c_start = {SMOKE_BASE_START[1], SMOKE_BASE_START[2], SMOKE_BASE_START[3], start_alpha}
        target_c_mid = {SMOKE_BASE_MID[1], SMOKE_BASE_MID[2], SMOKE_BASE_MID[3], mid_alpha}
        target_c_end = {SMOKE_BASE_END[1], SMOKE_BASE_END[2], SMOKE_BASE_END[3], end_alpha}
        
    else -- streak == 0 (Pilot light/Subdued)
        current_intensity = 0
        target_c_start = COLOR_HOT_START
        target_c_mid = COLOR_HOT_MID
        target_c_end = COLOR_HOT_END
        target_emission = 50
        target_accel_x = 20
        target_accel_y_min = -150
        target_accel_y_max = -250
        target_life_min = 0.5
        target_life_max = 1.0
    end
    
    -- 5. Apply Smoothing (LERP) to Current Properties
    
    current_emission = smooth_transition(current_emission, target_emission, dt)
    current_accel_x = smooth_transition(current_accel_x, target_accel_x, dt)
    current_accel_y_min = smooth_transition(current_accel_y_min, target_accel_y_min, dt)
    current_accel_y_max = smooth_transition(current_accel_y_max, target_accel_y_max, dt)
    current_life_min = smooth_transition(current_life_min, target_life_min, dt)
    current_life_max = smooth_transition(current_life_max, target_life_max, dt)
    
    -- Color array smoothing
    current_c_start = lerp_color(current_c_start, target_c_start, TRANSITION_RATE * dt)
    current_c_mid = lerp_color(current_c_mid, target_c_mid, TRANSITION_RATE * dt)
    current_c_end = lerp_color(current_c_end, target_c_end, TRANSITION_RATE * dt)
    
    -- Apply background hue to lever flame colors (preserves smoke behavior)
    local bg_hue = BackgroundRenderer.getCurrentHue()
    local hued_c_start = apply_hue_complementary(current_c_start, bg_hue)
    local hued_c_mid = apply_hue_complementary(current_c_mid, bg_hue)
    local hued_c_end = apply_hue_complementary(current_c_end, bg_hue)
    
    -- 6. Check for Intensity Jump and Trigger Flare (Masking)
    if math.abs(current_intensity - last_intensity) >= 1 then
         flare_timer = 0.1 
         last_intensity = current_intensity
    end
    
    local final_emission = current_emission
    if flare_timer > 0 then
        flare_timer = flare_timer - dt
        final_emission = final_emission + 300 
    end
    

    -- Set particle colors (Color gradient is calculated instantly for responsiveness)
    particle_sys:setColors(
        hued_c_start[1], hued_c_start[2], hued_c_start[3], hued_c_start[4],
        hued_c_mid[1], hued_c_mid[2], hued_c_mid[3], hued_c_mid[4],
        hued_c_end[1], hued_c_end[2], hued_c_end[3], hued_c_end[4],
        0.1, 0.1, 0.1, 0
    )
    
    -- Apply Smoothed/Transitioned Properties
    particle_sys:setEmissionRate(final_emission)
    -- Need to handle current_accel_x being a spread
    particle_sys:setLinearAcceleration(-current_accel_x, current_accel_y_min, current_accel_x, current_accel_y_max)
    particle_sys:setParticleLifetime(current_life_min, current_life_max)
    
    -- Update Position (Uses SMOOTHED emitter_y)
    local kx = Config.LEVER_TRACK_X + (Config.LEVER_TRACK_WIDTH / 2)
    -- ADJUSTED: Offset emitter position upward by 1/3rd of the knob radius (R/3)
    local ky_offset = -Config.LEVER_KNOB_RADIUS * (1/3)
    local ky_emitter = Config.LEVER_TRACK_Y + emitter_y + ky_offset
    particle_sys:setPosition(kx, ky_emitter)
    
    particle_sys:update(dt)
end

-- Update only particles (called when in MENU to let particles fade out)
function Lever.updateParticles(dt)
    ParticleSystem.update_lever_particles_only(dt)
end

local function get_knob_rect()
    local x = Config.LEVER_TRACK_X + (Config.LEVER_TRACK_WIDTH / 2)
    -- Knob still uses instantaneous knob_y for responsiveness
    local y = Config.LEVER_TRACK_Y + knob_y 
    return x, y
end

function Lever.mousePressed(x, y)
    -- Allow dragging even if jammed (Movement clamping is done in mouseMoved/update)
    local kx, ky = get_knob_rect()
    local dist = math.sqrt((x-kx)^2 + (y-ky)^2)
    
    if dist <= Config.LEVER_KNOB_RADIUS * 1.5 then 
        is_dragging = true
        is_auto_pulling = false 
        drag_offset_y = ky - y 
        return true
    end
    return false
end

function Lever.mouseMoved(x, y)
    if is_dragging then
        local new_y = y + drag_offset_y
        local relative_y = new_y - Config.LEVER_TRACK_Y
        
        -- Determine maximum allowed movement
        local max_movement = Config.LEVER_TRACK_HEIGHT
        if SlotMachine.is_jammed() then
            max_movement = Config.LEVER_TRACK_HEIGHT * JAM_MOVEMENT_LIMIT 
        end
        
        if relative_y < 0 then relative_y = 0 end
        if relative_y > max_movement then relative_y = max_movement end -- CLAMP MOVEMENT

        knob_y = relative_y
    end
end

function Lever.mouseReleased(x, y)
    if is_dragging then
        is_dragging = false
        
        -- If jammed, the release does nothing (no spin trigger, but lever returns via update)
        if SlotMachine.is_jammed() then
             return false
        end
        
        -- Normal spin trigger check
        local pct = knob_y / Config.LEVER_TRACK_HEIGHT
        if pct > TRIGGER_THRESHOLD then
            return true 
        end
    end
    return false
end

function Lever.draw()
    -- 1. Track
    love.graphics.setColor(Config.LEVER_TRACK_COLOR)
    love.graphics.rectangle("fill", Config.LEVER_TRACK_X, Config.LEVER_TRACK_Y, Config.LEVER_TRACK_WIDTH, Config.LEVER_TRACK_HEIGHT, 10, 10)
    
    -- 2. Jam Indicator Line (Draw visual limit when jammed)
    if SlotMachine.is_jammed() then
        local limit_y = Config.LEVER_TRACK_Y + (Config.LEVER_TRACK_HEIGHT * JAM_MOVEMENT_LIMIT)
        love.graphics.setColor(1.0, 0.8, 0.2, 0.5) -- Yellow/Orange for jam
        love.graphics.setLineWidth(3)
        love.graphics.line(Config.LEVER_TRACK_X, limit_y, Config.LEVER_TRACK_X + Config.LEVER_TRACK_WIDTH, limit_y)
        love.graphics.setLineWidth(1)
    end
    
    -- 3. Stem
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", Config.LEVER_TRACK_X + Config.LEVER_TRACK_WIDTH/2 - 2, Config.LEVER_TRACK_Y, 4, Config.LEVER_TRACK_HEIGHT)

    -- 4. Knob Body
    local kx, ky = get_knob_rect()
    love.graphics.setColor(Config.LEVER_KNOB_COLOR)
    love.graphics.circle("fill", kx, ky, Config.LEVER_KNOB_RADIUS)
    
    -- 5. Highlight
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.circle("fill", kx - 8, ky - 8, Config.LEVER_KNOB_RADIUS * 0.3)
end

function Lever.drawParticles()
    ParticleSystem.draw_lever_particles()
end

function Lever.clearParticles()
    ParticleSystem.clear_lever_particles()
end

return Lever