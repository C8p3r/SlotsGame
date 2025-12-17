-- particle_system.lua
-- Consolidated particle system for all game effects (lever, flames, etc.)
local Config = require("conf")

local ParticleSystem = {}

-- ===== LEVER PARTICLES =====
local lever_particle_sys = nil
local lever_particle_texture = nil
local lever_last_intensity = 0
local lever_flare_timer = 0.0

-- Lever particle state
local lever_current_emission = 50
local lever_current_accel_x = 0
local lever_current_accel_y_min = -150
local lever_current_accel_y_max = -250
local lever_current_life_min = 0.5
local lever_current_life_max = 1.0

local lever_current_c_start = {}
local lever_current_c_mid = {}
local lever_current_c_end = {}

-- Lever colors
local LEVER_COLOR_HOT_START = {1.0, 0.8, 0.2, 0.3}
local LEVER_COLOR_HOT_MID = {1.0, 0.4, 0.0, 0.15}
local LEVER_COLOR_HOT_END = {0.8, 0.1, 0.1, 0.05}

local LEVER_COLOR_BLUE_START = {0.2, 1.0, 1.0, 0.4}
local LEVER_COLOR_BLUE_MID = {0.2, 0.5, 1.0, 0.15}
local LEVER_COLOR_BLUE_END = {0.0, 0.1, 0.5, 0.05}

local LEVER_SMOKE_BASE_START = {0.3, 0.3, 0.3, 0.15}
local LEVER_SMOKE_BASE_MID = {0.1, 0.1, 0.1, 0.1}
local LEVER_SMOKE_BASE_END = {0.05, 0.05, 0.05, 0.03}

-- ===== FLAME PARTICLES =====
local flame_particle_sys = nil
local flame_particle_sys_edges_left = nil
local flame_particle_sys_edges_right = nil
local flame_particle_texture = nil

local flame_current_emission = 1000
local flame_current_accel_x_spread = 150
local flame_current_start_size = 2.0
local flame_current_end_size = 3.5

local flame_current_c_start = {}
local flame_current_c_mid = {}
local flame_current_c_end = {}

-- Base colors for flames
local FLAME_BASE_COLOR_START = {0.8, 0.4, 0.1, 0.4}
local FLAME_BASE_COLOR_MID = {0.5, 0.2, 0.1, 0.2}
local FLAME_BASE_COLOR_END = {0.2, 0.1, 0.05, 0.05}

local FLAME_WHITE_HOT_START = {0.0, 0.0, 0.0, 0.5}
local FLAME_WHITE_HOT_MID = {0.1, 0.0, 0.1, 0.3}
local FLAME_WHITE_HOT_END = {0.0, 0.0, 0.0, 0.1}

local FLAME_BLUE_COLOR_START = {0.2, 0.8, 1.0, 0.6}
local FLAME_BLUE_COLOR_MID = {0.1, 0.4, 0.8, 0.3}
local FLAME_BLUE_COLOR_END = {0.05, 0.1, 0.3, 0.1}

local FLAME_SMOKE_COLOR_START = {0.2, 0.2, 0.2, 0.1}
local FLAME_SMOKE_COLOR_MID = {0.1, 0.1, 0.1, 0.05}
local FLAME_SMOKE_COLOR_END = {0.05, 0.05, 0.05, 0.01}

-- ===== TEXTURE CREATION =====
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

local function create_small_glow_texture()
    local size = 32
    local data = love.image.newImageData(size, size)
    local center = size / 2
    
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - center) / center
            local dy = (y - center) / center
            local dist = math.sqrt(dx*dx + dy*dy)
            
            local alpha = math.max(0, 1 - dist)
            alpha = alpha * alpha
            
            data:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    
    return love.graphics.newImage(data)
end

-- ===== INITIALIZATION =====
function ParticleSystem.load()
    -- Initialize lever particles
    lever_particle_texture = create_glow_texture()
    lever_particle_sys = love.graphics.newParticleSystem(lever_particle_texture, 200)
    lever_particle_sys:setParticleLifetime(lever_current_life_min, lever_current_life_max)
    lever_particle_sys:setEmissionRate(lever_current_emission)
    
    local R = Config.LEVER_KNOB_RADIUS
    lever_particle_sys:setEmissionArea('ellipse', R * (2/3), R * (1/3))
    
    lever_particle_sys:setSpeed(20, 80)
    lever_particle_sys:setDirection(-math.pi / 2)
    lever_particle_sys:setSpread(0.5)
    
    lever_current_c_start = {LEVER_COLOR_HOT_START[1], LEVER_COLOR_HOT_START[2], LEVER_COLOR_HOT_START[3], LEVER_COLOR_HOT_START[4]}
    lever_current_c_mid = {LEVER_COLOR_HOT_MID[1], LEVER_COLOR_HOT_MID[2], LEVER_COLOR_HOT_MID[3], LEVER_COLOR_HOT_MID[4]}
    lever_current_c_end = {LEVER_COLOR_HOT_END[1], LEVER_COLOR_HOT_END[2], LEVER_COLOR_HOT_END[3], LEVER_COLOR_HOT_END[4]}
    
    lever_particle_sys:setColors(lever_current_c_start[1], lever_current_c_start[2], lever_current_c_start[3], lever_current_c_start[4],
                                 lever_current_c_mid[1], lever_current_c_mid[2], lever_current_c_mid[3], lever_current_c_mid[4],
                                 lever_current_c_end[1], lever_current_c_end[2], lever_current_c_end[3], lever_current_c_end[4],
                                 0.1, 0.1, 0.1, 0)
    
    lever_particle_sys:setSizes(1.5, 2.5, 0.5)
    lever_particle_sys:setSpin(0, 3)
    
    -- Initialize flame particles
    flame_particle_texture = create_small_glow_texture()
    flame_particle_sys = love.graphics.newParticleSystem(flame_particle_texture, 5000)
    flame_particle_sys:setParticleLifetime(0.8, 1.2)
    flame_particle_sys:setEmissionRate(flame_current_emission)
    flame_particle_sys:setSpeed(100, 300)
    flame_particle_sys:setDirection(-math.pi / 2)
    flame_particle_sys:setSpread(0.8)
    flame_particle_sys:setLinearAcceleration(-flame_current_accel_x_spread, -400, flame_current_accel_x_spread, -50)
    
    flame_current_c_start = {FLAME_BASE_COLOR_START[1], FLAME_BASE_COLOR_START[2], FLAME_BASE_COLOR_START[3], FLAME_BASE_COLOR_START[4]}
    flame_current_c_mid = {FLAME_BASE_COLOR_MID[1], FLAME_BASE_COLOR_MID[2], FLAME_BASE_COLOR_MID[3], FLAME_BASE_COLOR_MID[4]}
    flame_current_c_end = {FLAME_BASE_COLOR_END[1], FLAME_BASE_COLOR_END[2], FLAME_BASE_COLOR_END[3], FLAME_BASE_COLOR_END[4]}
    
    flame_particle_sys:setColors(flame_current_c_start[1], flame_current_c_start[2], flame_current_c_start[3], flame_current_c_start[4],
                                 flame_current_c_mid[1], flame_current_c_mid[2], flame_current_c_mid[3], flame_current_c_mid[4],
                                 flame_current_c_end[1], flame_current_c_end[2], flame_current_c_end[3], flame_current_c_end[4],
                                 0.05, 0.05, 0.05, 0)
    
    flame_particle_sys:setSizes(flame_current_start_size, flame_current_end_size)
    
    -- Edge flame particles
    flame_particle_sys_edges_left = love.graphics.newParticleSystem(flame_particle_texture, 2000)
    flame_particle_sys_edges_left:setParticleLifetime(0.8, 1.2)
    flame_particle_sys_edges_left:setEmissionRate(300)
    flame_particle_sys_edges_left:setSpeed(80, 250)
    flame_particle_sys_edges_left:setDirection(-math.pi / 2)
    flame_particle_sys_edges_left:setSpread(1.2)
    flame_particle_sys_edges_left:setLinearAcceleration(-100, -400, 50, -50)
    flame_particle_sys_edges_left:setColors(flame_current_c_start[1], flame_current_c_start[2], flame_current_c_start[3], flame_current_c_start[4],
                                            flame_current_c_mid[1], flame_current_c_mid[2], flame_current_c_mid[3], flame_current_c_mid[4],
                                            flame_current_c_end[1], flame_current_c_end[2], flame_current_c_end[3], flame_current_c_end[4],
                                            0.05, 0.05, 0.05, 0)
    flame_particle_sys_edges_left:setSizes(flame_current_start_size, flame_current_end_size)
    
    flame_particle_sys_edges_right = love.graphics.newParticleSystem(flame_particle_texture, 2000)
    flame_particle_sys_edges_right:setParticleLifetime(0.8, 1.2)
    flame_particle_sys_edges_right:setEmissionRate(300)
    flame_particle_sys_edges_right:setSpeed(80, 250)
    flame_particle_sys_edges_right:setDirection(-math.pi / 2)
    flame_particle_sys_edges_right:setSpread(1.2)
    flame_particle_sys_edges_right:setLinearAcceleration(-50, -400, 100, -50)
    flame_particle_sys_edges_right:setColors(flame_current_c_start[1], flame_current_c_start[2], flame_current_c_start[3], flame_current_c_start[4],
                                             flame_current_c_mid[1], flame_current_c_mid[2], flame_current_c_mid[3], flame_current_c_mid[4],
                                             flame_current_c_end[1], flame_current_c_end[2], flame_current_c_end[3], flame_current_c_end[4],
                                             0.05, 0.05, 0.05, 0)
    flame_particle_sys_edges_right:setSizes(flame_current_start_size, flame_current_end_size)
end

-- ===== LEVER PARTICLE FUNCTIONS =====
function ParticleSystem.update_lever_particles(dt, knob_intensity, knob_y, emitter_y)
    if not lever_particle_sys then return end
    
    -- Smooth intensity transitions
    local target_emission = knob_intensity * 100
    lever_current_emission = lever_current_emission + (target_emission - lever_current_emission) * 0.08
    lever_particle_sys:setEmissionRate(math.max(0, lever_current_emission))
    
    -- Update position
    local kx = Config.LEVER_TRACK_X + (Config.LEVER_TRACK_WIDTH / 2)
    local ky_offset = -Config.LEVER_KNOB_RADIUS * (1/3)
    local ky_emitter = Config.LEVER_TRACK_Y + emitter_y + ky_offset
    lever_particle_sys:setPosition(kx, ky_emitter)
    
    lever_particle_sys:update(dt)
end

function ParticleSystem.draw_lever_particles()
    if lever_particle_sys then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(lever_particle_sys, 0, 0)
        love.graphics.setBlendMode("alpha")
    end
end

function ParticleSystem.update_lever_particles_only(dt)
    if lever_particle_sys then
        lever_particle_sys:update(dt)
    end
end

function ParticleSystem.clear_lever_particles()
    if lever_particle_sys then
        lever_particle_sys:stop()  -- Stop emitting
        lever_particle_sys:reset()  -- Remove all existing particles
    end
end

function ParticleSystem.get_lever_particle_system()
    return lever_particle_sys
end

-- ===== FLAME PARTICLE FUNCTIONS =====
function ParticleSystem.update_flame_particles(dt, win_count, streak, base_y)
    if not flame_particle_sys then return end
    
    -- Update main flame particles
    flame_particle_sys:setPosition(Config.GAME_WIDTH / 2, base_y)
    
    -- Edge particles
    local edge_distance = 180
    flame_particle_sys_edges_left:setPosition(Config.GAME_WIDTH / 2 - edge_distance, base_y)
    flame_particle_sys_edges_right:setPosition(Config.GAME_WIDTH / 2 + edge_distance, base_y)
    
    flame_particle_sys:update(dt)
    flame_particle_sys_edges_left:update(dt)
    flame_particle_sys_edges_right:update(dt)
end

function ParticleSystem.draw_flame_particles()
    if flame_particle_sys then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(flame_particle_sys, 0, 0)
        love.graphics.draw(flame_particle_sys_edges_left, 0, 0)
        love.graphics.draw(flame_particle_sys_edges_right, 0, 0)
        love.graphics.setBlendMode("alpha")
    end
end

function ParticleSystem.set_flame_emission(rate)
    if flame_particle_sys then
        flame_particle_sys:setEmissionRate(rate)
        flame_particle_sys_edges_left:setEmissionRate(rate * 0.3)
        flame_particle_sys_edges_right:setEmissionRate(rate * 0.3)
    end
end

return ParticleSystem
