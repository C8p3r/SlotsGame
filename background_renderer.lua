-- background_renderer.lua
local Config = require("conf")

local BackgroundRenderer = {}
local shader = nil

-- Configuration for Quick Swirl (Constant)
local SWIRL_SPEED = 0.9   -- High, constant speed multiplier for the shader time uniform

-- Configuration for Brightness Control (Interactive)
local BASE_BRIGHTNESS = 0.15 -- Default brightness level (darker base)
local SPIN_BRIGHTNESS = 1.0  -- Brightness when interacting (full bright)
local BRIGHTNESS_LERP_RATE = 4.0 -- Speed of transition between brightness levels
local current_brightness = BASE_BRIGHTNESS
local target_brightness = BASE_BRIGHTNESS


function BackgroundRenderer.load()
    local function load_shader(filename)
        local success, s = pcall(love.graphics.newShader, filename)
        if not success then
            print("Error loading shader " .. filename .. ": " .. s)
            return nil
        end
        return s
    end
    
    shader = load_shader("background_shader.glsl")
    
    -- Initialize brightness
    current_brightness = BASE_BRIGHTNESS
    target_brightness = BASE_BRIGHTNESS
end

-- Function to set the target brightness instead of speed
function BackgroundRenderer.setSpinning(is_spinning)
    if is_spinning then
        target_brightness = SPIN_BRIGHTNESS
    else
        target_brightness = BASE_BRIGHTNESS
    end
end


function BackgroundRenderer.update(dt)
    local current_time = love.timer.getTime()
    local w, h = love.graphics.getDimensions()
    
    -- LERP current_brightness towards target_brightness
    local lerp_amount = math.min(1.0, BRIGHTNESS_LERP_RATE * dt)
    current_brightness = current_brightness + (target_brightness - current_brightness) * lerp_amount
    
    if shader then
        -- 1. Send constant, quick speed (time * multiplier)
        if shader:hasUniform("time") then
            -- This makes the swirl fast by default
            shader:send("time", current_time * SWIRL_SPEED)
        end
        
        -- 2. Send the interpolated brightness uniform
        if shader:hasUniform("u_brightness") then
            -- This controls the color blending
            shader:send("u_brightness", current_brightness)
        end
        
        if shader:hasUniform("resolution") then
            shader:send("resolution", {w, h})
        end
    end
end

function BackgroundRenderer.draw()
    -- Draws a full-screen rectangle with the shader
    local w, h = love.graphics.getDimensions()
    
    if shader then
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setShader()
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

return BackgroundRenderer