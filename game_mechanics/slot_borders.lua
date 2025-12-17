-- slot_borders.lua
local Config = require("conf")

local SlotBorders = {}
local Slots = nil -- Reference injected by setSlotMachineModule

local JITTER_BASE_RANGE = 2.0  
local MAX_STREAK_RANGE = 20.0  
local MAX_LINE_WIDTH = 6.0     
local NUM_SEGMENTS = 14        
local BORDER_LINE_OFFSET = 1.0 
local NUM_ARCS = 4             

-- Parameters for discrete, slow flicker update
local CHAOS_UPDATE_INTERVAL = 1/2 
local RARE_BOLT_CHANCE_PER_SLOT = 0.005 

local flicker_timer = 0.0
local chaos_time = 0.0 

-- LERP Smoothing parameters
local LERP_RATE = 3.0 

-- Current (smoothed) state variables
local current_jitter_range = JITTER_BASE_RANGE
local current_line_width = 1.0
local current_speed_mod = 1.0

local function smooth_transition(current, target, dt)
    return current + (target - current) * math.min(1.0, LERP_RATE * dt)
end

local function get_target_intensity_mods(streak)
    local positive_streak = math.max(0, streak)
    local max_cap = 5
    local multiplier = math.min(1.0, positive_streak / max_cap)
    
    local jitter_range = JITTER_BASE_RANGE + (MAX_STREAK_RANGE * multiplier)
    local line_width = 1.0 + (MAX_LINE_WIDTH * multiplier)
    
    local speed_mod = 1.0 + (multiplier * 1.5) 
    
    return jitter_range, line_width, speed_mod
end

local function draw_electric_circle(cx, cy, radius, jitter_range, line_width, speed_mod, override_color)
    love.graphics.setLineJoin('miter')
    
    local time_base = chaos_time * speed_mod 
    local num_circle_segments = 30 
    
    for arc_index = 1, NUM_ARCS do
        local arc_seed = love.math.random(1000)
        local arc_width = line_width / (arc_index * 0.8) 
        local arc_jitter = jitter_range * (0.5 + love.math.random() * 0.5) 
        local arc_time = time_base + arc_seed * 0.1
        
        love.graphics.setLineWidth(arc_width)
        
        local points = {}
        
        for i = 0, num_circle_segments do
            local angle = (i / num_circle_segments) * math.pi * 2
            
            local offset_t = arc_time + i * 0.2 + love.math.random() * 2.0
            
            local jitter = (math.sin(offset_t) + love.math.noise(offset_t, i, arc_seed) * 1.5) * arc_jitter * 0.8
            local r = radius + jitter
            
            local x = cx + math.cos(angle) * r
            local y = cy + math.sin(angle) * r
            
            table.insert(points, x)
            table.insert(points, y)
        end
        
        -- Closing the loop for the circle to avoid gaps
        -- Re-add first point to close the loop smoothly if segment count is high enough to mask noise discontinuity
        -- Since noise is not periodic here, there will be a seam.
        -- For this visual style, a small seam is acceptable chaos, or we could blend the noise.
        -- We will just ensure the line strip is drawn open.
        
        if override_color then
             love.graphics.setColor(override_color)
        else
            local r = 0.5 + love.math.random() * 0.3
            local g = 0.8 + love.math.random() * 0.2
            local b = 1.0
            local alpha = 0.5 + love.math.random() * 0.5
            love.graphics.setColor(r, g, b, alpha) 
        end
        
        love.graphics.line(points)
    end
end

local function draw_single_bolt(x, y, w, h, jitter_magnitude, width, color)
    love.graphics.setLineWidth(width)
    love.graphics.setLineJoin('miter')
    love.graphics.setColor(color)
    
    local time = love.timer.getTime() * 8.0 
    local offset = BORDER_LINE_OFFSET 
    
    local base_corners = {
        {x + offset, y + offset}, 
        {x + w - offset, y + offset}, 
        {x + w - offset, y + h - offset}, 
        {x + offset, y + h - offset}, 
        {x + offset, y + offset}
    }
    
    local side = love.math.random(1, 4)
    local p1 = base_corners[side]
    local p2 = base_corners[side + 1]
    
    local dx = p2[1] - p1[1]
    local dy = p2[2] - p1[2]
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end
    
    local points = {}
    table.insert(points, p1[1])
    table.insert(points, p1[2])
    
    local nx = -dy / len 
    local ny = dx / len  
    
    local num_bolt_segments = 25 
    
    for i = 1, num_bolt_segments do
        local t = i / num_bolt_segments
        local current_x = p1[1] + dx * t
        local current_y = p1[2] + dy * t
        local jitter = (math.sin(time + i * 2.0) + love.math.noise(time, i * 0.1, x) * 1.5) * jitter_magnitude * 0.5
        current_x = current_x + nx * jitter
        current_y = current_y + ny * jitter
        table.insert(points, current_x)
        table.insert(points, current_y)
    end
    
    love.graphics.line(points)
end

local function draw_electric_border(x, y, w, h)
    local jitter_range = current_jitter_range
    local line_width = current_line_width
    local speed_mod = current_speed_mod

    love.graphics.setLineJoin('miter')
    
    local time_base = chaos_time * speed_mod 
    local offset = BORDER_LINE_OFFSET 
    
    local base_corners = {
        {x + offset, y + offset}, 
        {x + w - offset, y + offset}, 
        {x + w - offset, y + h - offset}, 
        {x + offset, y + h - offset}, 
        {x + offset, y + offset}
    }
    
    for arc_index = 1, NUM_ARCS do
        local arc_seed = love.math.random(1000)
        local arc_width = line_width / (arc_index * 0.8) 
        local arc_jitter = jitter_range * (0.5 + love.math.random() * 0.5) 
        local arc_time = time_base + arc_seed * 0.1
        
        love.graphics.setLineWidth(arc_width)
        
        for side = 1, 4 do
            local p1 = base_corners[side]
            local p2 = base_corners[side + 1]
            local dx = p2[1] - p1[1]
            local dy = p2[2] - p1[2]
            local len = math.sqrt(dx*dx + dy*dy)
            
            if len == 0 then goto continue end
            
            local points = {}
            table.insert(points, p1[1])
            table.insert(points, p1[2])
            
            local nx = -dy / len 
            local ny = dx / len  
            
            for i = 1, NUM_SEGMENTS do
                local t = i / NUM_SEGMENTS
                local current_x = p1[1] + dx * t
                local current_y = p1[2] + dy * t
                local offset_t = arc_time + i * 0.5 + love.math.random() * 2.0
                local jitter = (math.sin(offset_t) + love.math.noise(offset_t, i, arc_seed) * 1.5) * arc_jitter * 0.5
                current_x = current_x + nx * jitter
                current_y = current_y + ny * jitter
                table.insert(points, current_x)
                table.insert(points, current_y)
            end
            
            local r = 0.5 + love.math.random() * 0.3
            local g = 0.8 + love.math.random() * 0.2
            local b = 1.0
            local alpha = 0.5 + love.math.random() * 0.5
            love.graphics.setColor(r, g, b, alpha) 
            love.graphics.line(points)
            
            ::continue::
        end
    end
end

function SlotBorders.load()
    local jitter, width, speed = get_target_intensity_mods(0)
    current_jitter_range = jitter
    current_line_width = width
    current_speed_mod = speed
    flicker_timer = 0.0
    chaos_time = love.timer.getTime()
end

function SlotBorders.update(dt)
    flicker_timer = flicker_timer + dt
    if flicker_timer >= CHAOS_UPDATE_INTERVAL then
        chaos_time = chaos_time + CHAOS_UPDATE_INTERVAL 
        flicker_timer = flicker_timer % CHAOS_UPDATE_INTERVAL
    end
    
    local streak = 0
    if Slots then
        streak = Slots.getConsecutiveWins()
    end
    
    local target_jitter_range, target_line_width, target_speed_mod = get_target_intensity_mods(streak)
    
    local lerp_amount = math.min(1.0, LERP_RATE * dt)
    current_jitter_range = current_jitter_range + (target_jitter_range - current_jitter_range) * lerp_amount
    current_line_width = current_line_width + (target_line_width - current_line_width) * lerp_amount
    current_speed_mod = current_speed_mod + (target_speed_mod - current_speed_mod) * lerp_amount
end

function SlotBorders.draw_electric_circle(cx, cy, radius, streak, color)
    local jitter_range, line_width, speed_mod = get_target_intensity_mods(streak)
    draw_electric_circle(cx, cy, radius, jitter_range, line_width, speed_mod, color)
end

function SlotBorders.draw()
    if not Slots then return end -- Safety check
    local num_slots = Config.SLOT_COUNT
    local total_width = (num_slots * Config.SLOT_WIDTH) + ((num_slots - 1) * Config.SLOT_GAP)
    local start_x = (Config.GAME_WIDTH - total_width) / 2
    
    love.graphics.setBlendMode("add") 
    
    local x_walker = start_x
    for i = 1, num_slots do
        local x = x_walker
        local y = Config.SLOT_Y
        local w = Config.SLOT_WIDTH
        local h = Config.SLOT_HEIGHT
        
        draw_electric_border(x, y, w, h)
        
        if love.math.random() < RARE_BOLT_CHANCE_PER_SLOT then
            local current_jitter = current_jitter_range 
            local current_width = current_line_width
            local purple_color = {0.8, 0.2, 1.0, 0.7} 
            draw_single_bolt(x, y, w, h, current_jitter, current_width, purple_color)
        end
        
        x_walker = x_walker + Config.SLOT_WIDTH + Config.SLOT_GAP
    end
    
    love.graphics.setBlendMode("alpha") 
    love.graphics.setLineWidth(1)       
    love.graphics.setColor(1, 1, 1, 1)  
end

function SlotBorders.setSlotMachineModule(module)
    Slots = module
end

return SlotBorders