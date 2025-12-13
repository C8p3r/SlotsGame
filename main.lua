-- main.lua
local Config = require("conf")
local Background = require("background_renderer")
local Slots = require("slot_machine")
local Lever = require("lever")
local Buttons = require("buttons")
local BaseFlame = require("base_flame")
local StartScreen = require("start_screen") 
local SlotBorders = require("slot_borders")
local SlotSmoke = require("slot_smoke") 
local Settings = require("settings") 

local main_canvas
local scale = 1
local offset_x = 0
local offset_y = 0
local game_state = "MENU" -- States: "MENU", "GAME", "PAUSE", "SETTINGS"

local title_font
local prompt_font

local function update_scale()
    local w, h = love.graphics.getDimensions()
    local sx = w / Config.GAME_WIDTH
    local sy = h / Config.GAME_HEIGHT
    scale = math.min(sx, sy)
    offset_x = (w - (Config.GAME_WIDTH * scale)) / 2
    offset_y = (h - (Config.GAME_HEIGHT * scale)) / 2
end

-- Helper to draw menu text WITHIN the scaled (virtual) space
local function draw_menu_content()
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw Title
    love.graphics.setFont(title_font)
    local title_text = StartScreen.TITLE_TEXT -- USE CONFIG
    local tw = title_font:getWidth(title_text)
    local tx = w / 2 - tw / 2
    local ty = h * 0.3
    
    -- Simple neon effect for the title
    love.graphics.setColor(0, 0.8, 1, 0.5)
    love.graphics.print(title_text, tx + 3, ty + 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(title_text, tx, ty)
    
    -- Draw Prompt
    love.graphics.setFont(prompt_font)
    local prompt_text = StartScreen.PROMPT_TEXT -- USE CONFIG
    local pw = prompt_font:getWidth(prompt_text)
    local px = w / 2 - pw / 2
    local py = h * 0.7
    
    -- Pulsing alpha effect for prompt
    local pulse_alpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
    love.graphics.setColor(1, 1, 1, pulse_alpha)
    love.graphics.print(prompt_text, px, py)
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setFont(Slots.info_font)
    local inst_text = "Bankroll: $" .. Config.INITIAL_BANKROLL .. " | Goal: Maintain the streak!"
    local iw = Slots.info_font:getWidth(inst_text)
    love.graphics.print(inst_text, w / 2 - iw / 2, h * 0.9)
end

-- Helper to draw pause menu text WITHIN the scaled (virtual) space
local function draw_pause_content()
    love.graphics.setFont(title_font)
    local text = StartScreen.PAUSE_TITLE -- USE CONFIG
    local tw = title_font:getWidth(text)
    local tx = Config.GAME_WIDTH / 2 - tw / 2
    local ty = Config.GAME_HEIGHT * 0.4
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, tx, ty)
    
    love.graphics.setFont(prompt_font)
    local prompt = StartScreen.PAUSE_PROMPT -- USE CONFIG
    local pw = prompt_font:getWidth(prompt)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(prompt, Config.GAME_WIDTH / 2 - pw / 2, Config.GAME_HEIGHT * 0.6)
end


function love.load()
    love.window.setTitle("Sprite Slot Machine")
    love.window.setMode(Config.GAME_WIDTH, Config.GAME_HEIGHT, {
        resizable = true,
        minwidth = 400,
        minheight = 300
    })
    
    main_canvas = love.graphics.newCanvas(Config.GAME_WIDTH, Config.GAME_HEIGHT)
    main_canvas:setFilter("linear", "linear") 
    
    local font_file = "splashfont.otf"
    
    -- Load Title and Prompt using the splash font
    title_font = love.graphics.newFont(font_file, StartScreen.TITLE_SIZE)
    prompt_font = love.graphics.newFont(font_file, StartScreen.PROMPT_SIZE)
    
    Background.load()
    Slots.load()
    Lever.load()
    Buttons.load()
    BaseFlame.load()
    SlotBorders.load() 
    SlotSmoke.load() 
    Settings.load() -- Line 114
    update_scale()
end

function love.resize(w, h)
    update_scale()
end

function love.update(dt)
    -- Background always updates for the smooth speed transition
    Background.update(dt)
    
    if game_state == "GAME" then
        Slots.update(dt)
        Lever.update(dt)
        Buttons.update(dt)
        BaseFlame.update(dt)
        SlotBorders.update(dt) 
        SlotSmoke.update(dt) 
        
        -- Check if slots stopped spinning to slow background
        if Slots.is_spinning() or Slots.is_block_game_active() then 
            Background.setSpinning(true)
        else
            Background.setSpinning(false)
        end
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    -- 1. Draw Background Shader (Full Window)
    Background.draw()
    
    -- 2. Draw Full Screen Overlay (For Menu and Pause)
    if game_state == "MENU" or game_state == "PAUSE" or game_state == "SETTINGS" then
        love.graphics.setColor(0, 0, 0, 0.9) 
        love.graphics.rectangle("fill", 0, 0, w, h) -- Overlay fills ENTIRE screen (using w, h)
    end
    
    -- 3. Draw Game Content to Canvas (Only happens in GAME/PAUSE/SETTINGS)
    if game_state ~= "MENU" then -- Draw base game even under pause/settings
        if main_canvas then
            love.graphics.setCanvas(main_canvas)
            love.graphics.clear(0, 0, 0, 0) 
            
            Slots.draw()
            Lever.draw()
            Buttons.draw()
            
            love.graphics.setCanvas()
        end
    end
    
    -- 4. Apply Scaling and Draw Game/Menu Content (Everything inside is scaled)
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.scale(scale)

    -- 4a. Draw Base Flame (Behind Canvas)
    BaseFlame.draw()
    
    -- Draw Smoke behind the main slots but after base flame
    SlotSmoke.draw()
    
    if game_state == "MENU" then
        draw_menu_content()
    
    elseif game_state == "GAME" or game_state == "PAUSE" or game_state == "SETTINGS" then
        -- 4b. Draw Scaled Canvas to Screen (at 0,0 in the transformed space)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(main_canvas, 0, 0)
        
        -- Draw borders on top of the static canvas image
        SlotBorders.draw() 
        
        -- 4c. Draw Knob Particles on Top 
        Lever.drawParticles()
        
        -- 4d. Draw Settings Button (Always in GAME mode, except MENU)
        if game_state ~= "SETTINGS" then
             Settings.draw_settings_button()
        end
        
        if game_state == "PAUSE" then
            draw_pause_content()
        elseif game_state == "SETTINGS" then
            -- 4e. Draw the full settings menu overlay
            Settings.draw_menu()
        end
    end
    
    love.graphics.pop()
end

local function get_game_coords(x, y)
    return (x - offset_x) / scale, (y - offset_y) / scale
end

function love.mousepressed(x, y, button)
    local gx, gy = get_game_coords(x, y)
    
    if game_state == "MENU" then
        game_state = "GAME" 
        return
    end
    
    if game_state == "SETTINGS" and button == 1 then
        if Settings.check_close_button(gx, gy) then
            game_state = "GAME" -- Close menu
            return
        end
        return
    end

    if button == 1 and game_state == "GAME" then
        
        -- Check if settings button is pressed
        if Settings.check_settings_button(gx, gy) then
            game_state = "SETTINGS"
            return
        end
        
        -- Check for QTE Click
        if Slots.check_qte_click(gx, gy) then
            -- If handled, return immediately to consume click
            return
        end
        
        -- NEW: Check if a betting button was pressed (and handle animation state)
        if Buttons.mousePressed(gx, gy) then
            return
        end
        
        -- Lever interaction is allowed even if jammed (handled in Lever.mousePressed)
        if Lever.mousePressed(gx, gy) then
            return
        end
        
    end
end

function love.mousemoved(x, y, dx, dy)
    if game_state == "GAME" then
        local gx, gy = get_game_coords(x, y)
        Lever.mouseMoved(gx, gy)
    end
end

function love.mousereleased(x, y, button)
    if game_state == "MENU" or game_state == "PAUSE" or game_state == "SETTINGS" then
        return
    end

    if button == 1 and game_state == "GAME" then
        local gx, gy = get_game_coords(x, y)
        
        -- Handle button release to reset visual animation state
        -- NOTE: Buttons.mouseReleased returns true if a button was active, 
        -- but we only return early if the lever triggers a spin.
        Buttons.mouseReleased(gx, gy) 
        
        -- Handle lever release first
        if Lever.mouseReleased(gx, gy) then
            -- If the spin was triggered, start the process
            Slots.start_spin()
            Background.setSpinning(true) 
            return
        end
    end
end

function love.keypressed(key)
    if key == "f11" then
        local is_fs = love.window.getFullscreen()
        love.window.setFullscreen(not is_fs)
        update_scale()
    
    elseif key == "escape" then
        if game_state == "SETTINGS" then
            game_state = "GAME"
        elseif game_state == "GAME" then
            game_state = "PAUSE"
        elseif game_state == "PAUSE" then
            game_state = "GAME"
        end
        return

    elseif game_state == "MENU" then
        game_state = "GAME"
        return

    elseif game_state == "GAME" then
        
        if key == "space" then
            
            if Slots.is_jammed() then
                Slots.re_splash_jam()
                return
            end
            
            Lever.trigger(Slots.start_spin)
            Background.setSpinning(true) 
        else
            Slots.keypressed(key)
        end
    end
end