-- main.lua
local Config = require("conf")
local Background = require("background_renderer")
local Slots = require("slot_machine")
local SlotDraw = require("slot_draw")
local Lever = require("lever")
local Buttons = require("ui/buttons")
local BaseFlame = require("base_flame")
local StartScreen = require("ui/start_screen") 
local SlotBorders = require("slot_borders")
local HomeMenu = require("home_menu")
local SlotSmoke = require("slot_smoke") 
local Settings = require("ui/settings")
local UI = require("ui/ui")
local Difficulty = require("difficulty")
local Keepsakes = require("keepsakes")

local main_canvas
local scale = 1
local offset_x = 0
local offset_y = 0
local game_state = "MENU" -- States: "MENU", "GAME", "PAUSE", "SETTINGS", "MENU_EXIT"

-- Menu exit animation
local menu_exit_timer = 0
local menu_exit_duration = 1.0  -- 1.0 seconds for longer animation

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
    
    -- Calculate animation offset (for MENU_EXIT state)
    local anim_progress = 0
    if game_state == "MENU_EXIT" then
        anim_progress = menu_exit_timer / menu_exit_duration
    end
    -- Draw the main menu
    HomeMenu.draw(menu_exit_timer, menu_exit_duration)
    
    -- Draw keepsake tooltip on hover
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    local mouse_x, mouse_y = love.mouse.getPosition()
    local scale = math.min(love.graphics.getWidth() / w, love.graphics.getHeight() / h)
    local game_mouse_x = (mouse_x - (love.graphics.getWidth() - w * scale) / 2) / scale
    local game_mouse_y = (mouse_y - (love.graphics.getHeight() - h * scale) / 2) / scale
    
    local hovered_id = Keepsakes.get_hovered_keepsake(game_mouse_x, game_mouse_y, w * 0.02, h * 0.25 + 50, 96, 32)
    HomeMenu.draw_keepsake_tooltip(hovered_id)
    

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

local function check_difficulty_click(x, y)
    return HomeMenu.check_difficulty_click(x, y)
end


-- Helper to check if START button was clicked
local function check_start_button_click(x, y)
    return HomeMenu.check_start_button_click(x, y)
end


-- Helper to check if keepsake was clicked
local function check_keepsake_click(x, y)
    return HomeMenu.check_keepsake_click(x, y)
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
    start_button_font = love.graphics.newFont(font_file, 100)
    
    Background.load()
    Slots.load()
    Lever.load()
    Buttons.load()
    BaseFlame.load()
    SlotBorders.load() 
    SlotSmoke.load() 
    Settings.load()
    Keepsakes.load()
    HomeMenu.load_fonts()
    update_scale()
end

function love.resize(w, h)
    update_scale()
end

function love.update(dt)
    -- Background always updates for the smooth speed transition
    Background.update(dt)
    
    -- Handle menu exit animation
    if game_state == "MENU_EXIT" then
        menu_exit_timer = menu_exit_timer + dt
        if menu_exit_timer >= menu_exit_duration then
            game_state = "GAME"
            menu_exit_timer = 0
        end
    end
    
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
    
    -- 2. Draw Full Screen Overlay (For Menu and Pause - but NOT for MENU_EXIT, that renders on top at the end)
    if (game_state == "MENU" or game_state == "PAUSE" or game_state == "SETTINGS") then
        -- Normal overlay for menu/pause/settings states
        love.graphics.setColor(0, 0, 0, 0.9) 
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    
    -- 3. Draw Game Content to Canvas (Only happens in GAME/PAUSE/SETTINGS/MENU_EXIT)
    if game_state ~= "MENU" then -- Draw base game even under pause/settings and during menu exit
        if main_canvas then
            love.graphics.setCanvas(main_canvas)
            love.graphics.clear(0, 0, 0, 0) 
            
            Slots.draw()
            Lever.draw()
            
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
    
    -- Draw Display Boxes (only in game states, not menu)
    if game_state ~= "MENU" then
        UI.drawDisplayBoxes()
        UI.drawBottomOverlays()
        local state = Slots.getState()
        local KeepsakeSplash = require("keepsake_splashs")
        KeepsakeSplash.draw(state)
    end
    
    if game_state == "MENU" then
        draw_menu_content()
    
    elseif game_state == "GAME" or game_state == "PAUSE" or game_state == "SETTINGS" or game_state == "MENU_EXIT" then
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
        end
        
        -- 4f. Draw UI Elements (Indicator Boxes, Buttons, Bankroll/Payout)
        local state = Slots.getState()
        UI.drawIndicatorBoxes(state, Slots, SlotDraw.draw_wavy_text, Slots.get_wiggle_modifiers)
        UI.drawButtons(state, Slots, nil, SlotDraw.draw_wavy_text, Slots.get_wiggle_modifiers)
        UI.drawBankrollAndPayout(state, SlotDraw.draw_wavy_text, Slots.get_wiggle_modifiers)
        
        -- 4f-2. Draw lucky box tooltip on hover
        local game_mouse_x, game_mouse_y = love.mouse.getPosition()
        local w, h = love.graphics.getDimensions()
        -- Transform mouse coords to game space if needed
        local lucky_hover = HomeMenu.get_lucky_box_hover(game_mouse_x, game_mouse_y)
        HomeMenu.draw_lucky_box_tooltip(lucky_hover)
        
        -- 4g. Draw the full settings menu overlay (on top of everything else)
        if game_state == "SETTINGS" then
            Settings.draw_menu()
        end
    end
    
    love.graphics.pop()
    
    -- Draw MENU_EXIT overlay on top of everything
    if game_state == "MENU_EXIT" then
        local progress = menu_exit_timer / (menu_exit_duration * 4)  -- 0 to 1
        local w_half = w / 2
        
        -- Easing function for more dramatic movement
        local ease_progress = progress * progress * (3 - 2 * progress)  -- Smoothstep
        
        -- Left half slides left
        local left_offset = ease_progress * (w_half + 100) * 10
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", -left_offset, 0, w_half, h)
        
        -- Right half slides right
        local right_offset = ease_progress * (w_half + 100) * 10
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", w_half + right_offset, 0, w_half, h)
    end
end

local function get_game_coords(x, y)
    return (x - offset_x) / scale, (y - offset_y) / scale
end

function love.mousepressed(x, y, button)
    local gx, gy = get_game_coords(x, y)
    
    if game_state == "MENU" then
        -- Check if START button was clicked
        if check_start_button_click(gx, gy) then
            game_state = "MENU_EXIT"
            menu_exit_timer = 0
            return
        end
        
        -- Check if difficulty button was clicked
        if check_difficulty_click(gx, gy) then
            return
        end
        
        -- Check if keepsake was clicked
        if check_keepsake_click(gx, gy) then
            return
        end
        return
    end
    
    if game_state == "SETTINGS" and button == 1 then
        if Settings.check_close_button(gx, gy) then
            game_state = "GAME" -- Close menu
            return
        end
        
        -- Check if difficulty button was clicked
        if Settings.check_difficulty_click(gx, gy) then
            return
        end
        
        -- Check if keepsake was clicked
        if Settings.check_keepsake_click(gx, gy) then
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
        -- Only allow game start if both difficulty and keepsake are selected
        if Difficulty.is_selected() and Keepsakes.get() then
            game_state = "GAME"
        end
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