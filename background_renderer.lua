-- background_renderer.lua
local Config = require("conf")

local BackgroundRenderer = {}
local shader = nil
local dummyImage = nil
local background_canvas = nil
local greyscale_shader = nil
local pixelate_shader = nil
local pixel_canvas = nil

-- Configuration for Quick Swirl (Constant)
local SWIRL_SPEED = 0.9

-- Configuration for Brightness Control (Interactive)
-- Base brightness raised to ensure visibility of the oil spill effect
local BASE_BRIGHTNESS = 0.45
local SPIN_BRIGHTNESS = 0.25
local BRIGHTNESS_LERP_RATE = 4.0
local current_brightness = BASE_BRIGHTNESS
local target_brightness = BASE_BRIGHTNESS

-- Hue cycling based on streak (cyan to orange)
local hue_offset = 0.0
local target_hue_offset = 0.0
local HUE_MIN = 0.5   -- Cyan (180° on color wheel)
local HUE_MAX = 0.06  -- Orange (30° on color wheel)
local STREAK_LEVELS = 20  -- Map 0-20 streak to hue range
local HUE_LERP_RATE = 2.0  -- Smooth transition rate

-- --- EMBEDDED GLSL SHADER SOURCE ---
local shaderSource = [[
    #ifdef VERTEX
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        return transform_projection * vertex_position;
    }
    #endif

    #ifdef PIXEL
    uniform float time;
    uniform vec2 resolution;
    uniform float u_brightness;
    uniform float hue_offset;

    // --- NOISE FUNCTIONS ---
    float hash(float n) { return fract(sin(n) * 43758.5453); }
    float hash(vec2 p) { return fract(sin(dot(p, vec2(15.79, 93.85))) * 43758.5453); }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
    }

    float fbm(vec2 p) {
        float f = 0.0;
        f += 0.5000 * noise(p); p *= 2.02;
        f += 0.2500 * noise(p); p *= 2.03;
        f += 0.1250 * noise(p); p *= 2.01;
        f += 0.0625 * noise(p);
        return f;
    }

    // HSL (Hue, Saturation, Lightness) to RGB Conversion
    vec3 hsv2rgb(vec3 c) {
        vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }

    // Shader entry point
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = screen_coords.xy / resolution.xy;
        
        vec2 p = uv * 3.0; 
        
        vec2 displacement = vec2(
            fbm(p + vec2(time * 0.1, time * 0.05)),
            fbm(p + vec2(time * -0.05, time * 0.1))
        );
        
        float turb = fbm(p + displacement * 2.0);

        // Hue is directly set based on streak level (orange to cyan)
        float hue = hue_offset;
        float saturation = 1.0;
        
        // u_brightness ranges from 0.45 (base) to 1.0 (spin).
        float max_interaction_lightness = u_brightness; 

        float pattern_modulation = pow(turb, 0.5); 
        
        // High minimum ensures no black screen issue.
        float GUARANTEED_MIN_VALUE = 0.3; 
        float value = mix(GUARANTEED_MIN_VALUE, max_interaction_lightness, pattern_modulation);
        
        value = clamp(value, 0.0, 1.0);
        
        vec3 final_color = hsv2rgb(vec3(hue, saturation, value));
        
        float shimmer = 0.1 * sin(turb * 50.0 + time * 5.0); 
        final_color += shimmer;
        
        vec2 center_uv = uv - 0.5;
        float border_mask = 1.0 - pow(length(center_uv * 1.5), 2.0);
        
        return vec4(final_color * border_mask, 1.0);
    }
    #endif
]]
-- --- END EMBEDDED SHADER SOURCE ---


function BackgroundRenderer.load()
    local success, s = pcall(love.graphics.newShader, shaderSource)
    if not success then
        print("Error compiling embedded shader: " .. s)
        print("Shader source length: " .. #shaderSource)
        shader = nil
    else
        shader = s
        print("Shader compiled successfully!")
    end

    -- create greyscale shader used when drawing desaturated slot areas
    local ok, gs = pcall(love.graphics.newShader, "shaders/greyscale_shader.glsl")
    if ok then
        greyscale_shader = gs
    else
        greyscale_shader = nil
        print("Warning: failed to load greyscale shader: " .. tostring(gs))
    end

    -- create pixelate shader (optional)
    local pk, ps = pcall(love.graphics.newShader, "shaders/pixelate_shader.glsl")
    if pk then
        pixelate_shader = ps
    else
        pixelate_shader = nil
        -- not fatal
    end

    current_brightness = BASE_BRIGHTNESS
    target_brightness = BASE_BRIGHTNESS

    -- create dummy white image used by the shader drawing
    local imgData = love.image.newImageData(1, 1)
    imgData:setPixel(0, 0, 255, 255, 255, 255)
    dummyImage = love.graphics.newImage(imgData)

    -- create background canvas sized to the current window
    local w, h = love.graphics.getDimensions()
    background_canvas = love.graphics.newCanvas(w, h)
    if pixelate_shader then
        pixel_canvas = love.graphics.newCanvas(w, h)
    end
end

-- Function to set the target brightness and swirl speed during spin
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
    
    -- Lerp brightness
    local brightness_lerp_amount = math.min(1.0, BRIGHTNESS_LERP_RATE * dt)
    current_brightness = current_brightness + (target_brightness - current_brightness) * brightness_lerp_amount
    
    -- Lerp hue towards target
    local hue_lerp_amount = math.min(1.0, HUE_LERP_RATE * dt)
    hue_offset = hue_offset + (target_hue_offset - hue_offset) * hue_lerp_amount
    
    if shader then
        if shader:hasUniform("time") then
            shader:send("time", current_time * SWIRL_SPEED)
        end
        
        if shader:hasUniform("u_brightness") then
            shader:send("u_brightness", current_brightness)
        end
        
        if shader:hasUniform("hue_offset") then
            shader:send("hue_offset", hue_offset)
        end
        
        if shader:hasUniform("resolution") then
            shader:send("resolution", {w, h})
        end
    end
end

function BackgroundRenderer.draw()
    local w, h = love.graphics.getDimensions()

    -- recreate canvas if window resized
    if not background_canvas or background_canvas:getWidth() ~= w or background_canvas:getHeight() ~= h then
        background_canvas = love.graphics.newCanvas(w, h)
    end

    if shader and dummyImage then
        -- render background shader to the offscreen canvas
        local prev = love.graphics.getCanvas()
        love.graphics.setCanvas(background_canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(dummyImage, 0, 0, 0, w, h)
        love.graphics.setShader()
        love.graphics.setCanvas(prev)
        -- optionally render a pixelated copy into pixel_canvas
        if pixelate_shader and pixel_canvas then
            if pixel_canvas:getWidth() ~= w or pixel_canvas:getHeight() ~= h then
                pixel_canvas = love.graphics.newCanvas(w, h)
            end
            local prev2 = love.graphics.getCanvas()
            love.graphics.setCanvas(pixel_canvas)
            love.graphics.clear(0, 0, 0, 1)
            pixelate_shader:send("texSize", {background_canvas:getWidth(), background_canvas:getHeight()})
            pixelate_shader:send("pixelSize", 6.0)
            love.graphics.setShader(pixelate_shader)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(background_canvas, 0, 0)
            love.graphics.setShader()
            love.graphics.setCanvas(prev2)

            -- draw the pixelated background canvas to the screen
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(pixel_canvas, 0, 0)
        else
            -- draw the full-color background canvas to the screen
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(background_canvas, 0, 0)
        end
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

-- Draw the desaturated background only inside slot rectangles
function BackgroundRenderer.drawDesaturatedSlots(start_x, slot_y_pos, slot_width, slot_height, slot_gap, num_slots)
    if not background_canvas then return end
    if not greyscale_shader then return end
    -- Send shader parameters: texture size, blur radius and desaturation amount
    local source_canvas = pixel_canvas or background_canvas
    greyscale_shader:send("texSize", {source_canvas:getWidth(), source_canvas:getHeight()})
    greyscale_shader:send("blurRadius", 3.0)
    greyscale_shader:send("desat", 0.9)

    love.graphics.setShader(greyscale_shader)
    love.graphics.setColor(1, 1, 1)
    for i = 1, num_slots do
        local x = start_x + (i-1) * (slot_width + slot_gap)
        love.graphics.setScissor(x, slot_y_pos, slot_width, slot_height)
        love.graphics.draw(source_canvas, 0, 0)
        love.graphics.setScissor()
    end
    love.graphics.setShader()
end

function BackgroundRenderer.setStreakHue(streak)
    -- Map streak (0-20+) to hue range (orange to cyan)
    local hue_progress = math.min(1.0, streak / STREAK_LEVELS)
    target_hue_offset = HUE_MIN + (HUE_MAX - HUE_MIN) * hue_progress
end

function BackgroundRenderer.getCurrentHue()
    return hue_offset
end

return BackgroundRenderer