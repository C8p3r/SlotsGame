-- main.lua
local Config = require("conf")
local Background = require("systems.background_renderer")
local Slots = require("game_mechanics.slot_machine")
local SlotDraw = require("game_mechanics.slot_draw")
local Lever = require("game_mechanics.lever")
local Buttons = require("ui.buttons")
local BaseFlame = require("systems.base_flame")
local StartScreen = require("ui_screens.start_screen") 
local SlotBorders = require("game_mechanics.slot_borders")
local HomeMenu = require("ui_screens.home_menu")
local SlotSmoke = require("systems.slot_smoke") 
local Settings = require("ui.settings")
local UI = require("ui.ui")
local Difficulty = require("systems.difficulty")
local Keepsakes = require("systems.keepsakes")
local ParticleSystem = require("systems.particle_system")
local Shop = require("ui.shop")
local Failstate = require("ui.failstate")
local UpgradeNode = require("systems.upgrade_node")

local main_canvas
local scale = 1
local offset_x = 0
local offset_y = 0
local game_state = "MENU" -- States: "MENU", "GAME", "PAUSE", "SETTINGS", "HOME_MENU_TO_GAME_TRANSITION"

-- Shop upgrade selection state (persists across frames)
local selected_upgrade_id = nil
local selected_upgrade_box_index = nil
local selected_upgrade_position_x = nil
local selected_upgrade_position_y = nil

-- Display box sell selection state (persists across frames)
local selected_sell_upgrade_id = nil
local selected_sell_upgrade_index = nil  -- Which slot in the display (1, 2, or 3)
local selected_sell_upgrade_position_x = nil
local selected_sell_upgrade_position_y = nil

-- Hover state for tooltips
local hovered_upgrade_index = nil
local hovered_upgrade_id = nil

-- Overlay management for smooth transitions
local overlay_alpha = 0
local overlay_fade_duration = 0.5  -- Duration to fade overlay in/out
local overlay_target_alpha = 0
local overlay_fade_timer = 0

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
    
    -- Get animation timers from HomeMenu
    local entrance_timer, entrance_duration, exit_timer, exit_duration = HomeMenu.get_animation_timers()
    
    -- Draw the main menu (using animation state from HomeMenu)
    HomeMenu.draw(exit_timer, exit_duration)
    
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
    HomeMenu.start_entrance_animation()  -- Start menu entrance animation on startup
    UpgradeNode.load()  -- Load upgrade node system
    update_scale()
end

function love.resize(w, h)
    update_scale()
end

-- Reset all game state for a new game
local function reset_game_state()
    local Slots = require("game_mechanics.slot_machine")
    
    -- Reset slot machine state
    Slots.reset_state()
    
    -- Reset UI animations
    UI.initialize()
    
    -- Clear any particle effects
    Lever.clearParticles()
    
    -- Reset gems currency
    Shop.reset_gems()
    
    -- Reset keepsake splash state
    local state = Slots.getState()
    if state then
        state.keepsake_splash_timer = 0
        state.keepsake_splash_text = ""
    end
    
    print("[RESET] All game state reset for new game")
end

-- Update overlay visibility smoothly
local function update_overlay(dt)
    if overlay_alpha ~= overlay_target_alpha then
        if overlay_alpha < overlay_target_alpha then
            overlay_alpha = math.min(overlay_alpha + (1 / overlay_fade_duration) * dt, overlay_target_alpha)
        else
            overlay_alpha = math.max(overlay_alpha - (1 / overlay_fade_duration) * dt, overlay_target_alpha)
        end
    end
end

-- Set overlay visibility target
local function set_overlay_visible(visible)
    overlay_target_alpha = visible and 1.0 or 0
end

function love.update(dt)
    -- Update overlay state
    update_overlay(dt)
    
    -- Background always updates for the smooth speed transition
    Background.update(dt)
    
    -- Update UI animations regardless of game state
    UI.update(dt)
    
    -- Update menu animations
    HomeMenu.update(dt)
    
    -- Update upgrade nodes (flying animations, shift animations, etc.)
    UpgradeNode.update_flying_upgrades(dt)
    UpgradeNode.update_shift_animations(dt)
    
    -- DEBUG: Print state every 60 frames (once per second at 60fps)
    if love.timer.getTime() % 1 < dt then
        print("[STATE] game_state=" .. game_state .. ", spins=" .. Shop.get_spins_remaining() .. ", bankroll=" .. Slots.getBankroll() .. ", goal=" .. Shop.get_balance_goal())
    end
    
    -- Handle home menu to game transition animation
    if game_state == "HOME_MENU_TO_GAME_TRANSITION" then
        -- Update home menu animations to show the exit animation
        HomeMenu.update(dt)
        
        -- Check if menu exit animation is complete
        if not HomeMenu.is_exit_animating() then
            game_state = "GAME"
            reset_game_state()  -- Reset all game state when starting a new game
        end
    end
    
    if game_state == "GAME" or game_state == "SHOP" then
        Slots.update(dt)
        Lever.update(dt)
        Buttons.update(dt)
        BaseFlame.update(dt)
        SlotBorders.update(dt) 
        SlotSmoke.update(dt)
        Shop.update(dt)  -- Update shop system (gems conversion animation)
        
        -- Check if shop closing animation is complete
        if game_state == "SHOP" and not Shop.is_open() then
            Shop.start_new_round()
            game_state = "GAME"
        end
        
        -- Set up spin callbacks for the next spin (handles both space press and mouse drag)
        -- These are cleared after each spin completes, so we re-set them for the next spin
        -- Only set up callbacks during normal GAME play, not in shop
        if game_state == "GAME" and not Slots.is_spinning() and not Slots.is_block_game_active() and Shop.get_spins_remaining() > 0 then
            -- Set spin start callback if not already set
            Slots.set_spin_start_callback(function()
                print("[SPIN_START_CALLBACK] Spin starting, using a spin")
                print("[SPIN_START_CALLBACK] Spins before use_spin(): " .. Shop.get_spins_remaining())
                Shop.use_spin()
                print("[SPIN_START_CALLBACK] Spins after use_spin(): " .. Shop.get_spins_remaining())
            end)
            
            -- Set spin complete callback if not already set
            Slots.set_spin_complete_callback(function()
                print("[CALLBACK] Spin resolved, bankroll: " .. Slots.getBankroll() .. ", goal: " .. Shop.get_balance_goal())
                if Slots.getBankroll() >= Shop.get_balance_goal() then
                    -- Balance goal met, open shop
                    print("[CALLBACK] Goal met! Opening shop")
                    game_state = "SHOP"
                    Shop.open()
                else
                    print("[CALLBACK] Goal not met yet")
                end
            end)
        end
        
        -- Check if slots stopped spinning to slow background
        if Slots.is_spinning() or Slots.is_block_game_active() then 
            Background.setSpinning(true)
        else
            Background.setSpinning(false)
        end
        
        -- Check if balance goal is met after scoring sequence (whenever not spinning and not in block game)
        if not Slots.is_spinning() and not Slots.is_block_game_active() then
            if Slots.getBankroll() >= Shop.get_balance_goal() and game_state ~= "SHOP" then
                -- Goal was met during play, open shop
                print("[SCORING] Balance goal met during scoring sequence! Bankroll: " .. Slots.getBankroll() .. ", goal: " .. Shop.get_balance_goal())
                game_state = "SHOP"
                Shop.open()
                return  -- Exit update to prevent fallback logic
            end
        end
        
        -- Check if spins ran out and game should end
        if Shop.get_spins_remaining() == 0 and not Slots.is_spinning() and not Slots.is_block_game_active() then
            -- Spins exhausted and no spinning happening
            print("[FALLBACK] Spins exhausted, bankroll: " .. Slots.getBankroll() .. ", goal: " .. Shop.get_balance_goal())
            if Slots.getBankroll() >= Shop.get_balance_goal() and game_state ~= "SHOP" then
                -- Goal was met, open shop
                print("[FALLBACK] Goal met, opening shop")
                game_state = "SHOP"
                Shop.open()
            else
                -- Goal not met, game over - show failstate
                print("[FALLBACK] Goal not met, showing failstate")
                game_state = "FAILSTATE"
                Failstate.initialize()
                Lever.clearParticles()
            end
        end
    end
    
    -- Update failstate if active
    if game_state == "FAILSTATE" then
        set_overlay_visible(true)  -- Keep overlay visible during failstate
        Failstate.update(dt)
        -- Check if fade out is complete
        if Failstate.is_fade_complete() then
            -- Transition to menu while keeping overlay visible
            game_state = "MENU"
            HomeMenu.reset_animations()  -- Reset animation state
            HomeMenu.start_entrance_animation()  -- Start menu entrance animation
            Lever.clearParticles()
        end
    elseif game_state == "MENU" then
        -- Keep overlay visible during menu entrance animation
        if HomeMenu.is_entrance_animating() then
            set_overlay_visible(true)
        else
            set_overlay_visible(false)
        end
    elseif game_state == "GAME" then
        -- Remove overlay when new game starts
        set_overlay_visible(false)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    -- 1. Draw Background Shader (Full Window)
    Background.draw()
    
    -- 2. Draw Full Screen Overlay (For Menu and Pause)
    if (game_state == "MENU" or game_state == "PAUSE" or game_state == "SETTINGS" or game_state == "FAILSTATE") then
        -- Normal overlay for menu/pause/settings states
        love.graphics.setColor(0, 0, 0, 0.9) 
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    
    -- 3. Draw Game Content to Canvas (Only happens in GAME/PAUSE/SETTINGS/HOME_MENU_TO_GAME_TRANSITION)
    if game_state ~= "MENU" then -- Draw base game even under pause/settings and during menu transition
        if main_canvas then
            love.graphics.setCanvas(main_canvas)
            love.graphics.clear(0, 0, 0, 0) 
            
            Slots.draw()
            Lever.draw()
            
            love.graphics.setCanvas()
        end
    end
    
    -- 4. Apply Scaling and Draw Game/Menu Content (Everything inside is scaled)
    -- For failstate, draw full-screen black background first (before push/pop)
    -- Make it very tall to ensure it covers the entire window including any gaps
    if game_state == "FAILSTATE" then
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0, 1.0)
        love.graphics.rectangle("fill", -1000, -1000, w + 2000, h + 2000)
    end
    
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.scale(scale)

    -- Draw overlay behind menu (but in front of game content)
    if overlay_alpha > 0 then
        love.graphics.setColor(0, 0, 0, overlay_alpha)
        love.graphics.rectangle("fill", 0, 0, Config.GAME_WIDTH, Config.GAME_HEIGHT)
    end

    -- 4a. Draw Base Flame (Behind Canvas)
    BaseFlame.draw()
    
    -- Draw Smoke behind the main slots but after base flame
    SlotSmoke.draw()
    
    -- Draw Display Boxes (only in game states, not menu)
    if game_state ~= "MENU" then
        local state = Slots.getState()
        UI.drawDisplayBoxes(state)
        UI.drawBottomOverlays(state)
        local KeepsakeSplash = require("ui_screens.keepsake_splashs")
        KeepsakeSplash.draw(state)
        UpgradeNode.draw()
    end
    
    if game_state == "MENU" then
        draw_menu_content()
    
    elseif game_state == "HOME_MENU_TO_GAME_TRANSITION" then
        -- Draw both the menu animation and the game underneath
        draw_menu_content()
    
    elseif game_state == "GAME" or game_state == "PAUSE" or game_state == "SETTINGS" or game_state == "SHOP" or game_state == "FAILSTATE" then
        -- 4b. Draw Scaled Canvas to Screen (at 0,0 in the transformed space)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(main_canvas, 0, 0)
        
        -- Draw borders on top of the static canvas image
        SlotBorders.draw() 
        
        -- 4c. Draw Knob Particles on Top 
        Lever.drawParticles()
        
        -- 4d. Draw Gems Counter (Always in GAME mode, except MENU)
        if game_state ~= "SETTINGS" then
             Settings.draw_gems_counter(Shop.get_gems())
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
        
        -- 4h. Draw shop menu if open
        if game_state == "SHOP" then
            print("[DRAW] Drawing shop, game_state is: " .. game_state)
            Shop.draw(Slots.getBankroll(), Slots, selected_upgrade_id, selected_upgrade_box_index, selected_upgrade_position_x, selected_upgrade_position_y)
        end
        
        -- 4h. Draw shop menu if open
        if game_state == "SHOP" then
            print("[DRAW] Drawing shop, game_state is: " .. game_state)
            Shop.draw(Slots.getBankroll(), Slots, selected_upgrade_id, selected_upgrade_box_index, selected_upgrade_position_x, selected_upgrade_position_y)
        end
        
        -- 4i. Draw failstate menu if active
        if game_state == "FAILSTATE" then
            Failstate.draw()
        end
        
        -- 4j. Draw upgrades layer on foremost (on top of all game elements)
        UI.drawUpgradesLayer()
        
        -- Draw tooltip and SELL button AFTER upgrades layer so they're on top
        -- Get upgrade box positions for drawing (now populated after drawUpgradesLayer)
        local upgrade_box_positions = UI.get_upgrade_box_positions()
        
        -- Draw tooltip for hovered upgrade
        if hovered_upgrade_id then
            Shop.draw_display_box_tooltip(hovered_upgrade_id, hovered_upgrade_index, upgrade_box_positions)
        end
        
        -- Draw SELL button for selected purchase (available at all stages)
        if selected_sell_upgrade_id then
            Shop.draw_sell_button(selected_sell_upgrade_index, upgrade_box_positions)
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
    
    -- DEBUG: Log ALL clicks with game state (to file)
    local debug_msg = string.format("[DEBUG] CLICK: screen(%.0f, %.0f) -> game(%.0f, %.0f), button=%d, game_state=%s, Shop.is_open()=%s", 
        x, y, gx, gy, button, game_state, tostring(Shop.is_open()))
    print(debug_msg)
    local debug_file = io.open("debug_clicks.log", "a")
    if debug_file then
        debug_file:write(debug_msg .. "\n")
        debug_file:close()
    end
    
    if game_state == "MENU" then
        -- Check if START button was clicked
        if check_start_button_click(gx, gy) then
            HomeMenu.start_exit_animation()  -- Start menu exit animation
            game_state = "HOME_MENU_TO_GAME_TRANSITION"
            Shop.initialize(Slots.getBankroll())  -- Initialize shop system
            UI.initialize()  -- Initialize UI animations
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
    
    if game_state == "SHOP" and button == 1 then
        -- Check if NEXT ROUND button was clicked
        if Shop.check_next_button_click(gx, gy) then
            Shop.close()  -- Start shop closing animation
            return
        end
        
        -- Check if BUY button was clicked
        local slide_offset = Shop.get_slide_offset()
        local popup_action = Shop.check_popup_button_click(gx, gy, selected_upgrade_id, selected_upgrade_box_index, slide_offset)
        if popup_action == "buy" then
            if selected_upgrade_id and selected_upgrade_position_x and selected_upgrade_position_y and UpgradeNode.select_upgrade(selected_upgrade_id) then
                UpgradeNode.add_flying_upgrade(selected_upgrade_id, selected_upgrade_position_x, selected_upgrade_position_y)
                print("[SHOP] Purchased upgrade: " .. selected_upgrade_id)
            end
            selected_upgrade_id = nil
            selected_upgrade_box_index = nil
            selected_upgrade_position_x = nil
            selected_upgrade_position_y = nil
            return
        end
        
        -- Check if upgrade box was clicked to show BUY button or toggle selection
        local box_index, box_x, box_y = Shop.check_upgrade_box_click(gx, gy)
        if box_index then
            local clicked_upgrade_id = UpgradeNode.get_box_upgrade(box_index)
            print(string.format("[MAIN.mousepressed] Upgrade box %d clicked, upgrade_id=%s, current selection=%s", box_index, tostring(clicked_upgrade_id), tostring(selected_upgrade_id)))
            -- If clicking the same upgrade that's already selected, deselect it
            if selected_upgrade_id and selected_upgrade_id == clicked_upgrade_id then
                print("[MAIN.mousepressed] Same upgrade clicked, deselecting")
                selected_upgrade_id = nil
                selected_upgrade_box_index = nil
                selected_upgrade_position_x = nil
                selected_upgrade_position_y = nil
            else
                -- Set the selection to this new upgrade
                print(string.format("[MAIN.mousepressed] Setting selection to upgrade %s", tostring(clicked_upgrade_id)))
                selected_upgrade_id = clicked_upgrade_id
                selected_upgrade_box_index = box_index
                selected_upgrade_position_x = box_x
                selected_upgrade_position_y = box_y
            end
            -- Deselect sell selection when clicking shop boxes
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            return
        end
        
        -- Check if a display box (purchased upgrade) was clicked
        local sell_index = Shop.check_display_box_click(gx, gy, UI.get_upgrade_box_positions())
        if sell_index then
            local selected_upgrades = UpgradeNode.get_selected_upgrades()
            local clicked_upgrade_id = selected_upgrades[sell_index]
            
            print(string.format("[MAIN.mousepressed] Display box %d clicked, upgrade_id=%s, current sell selection=%s", sell_index, tostring(clicked_upgrade_id), tostring(selected_sell_upgrade_id)))
            
            -- If clicking the same upgrade that's already selected for selling, deselect it
            if selected_sell_upgrade_id and selected_sell_upgrade_id == clicked_upgrade_id then
                print("[MAIN.mousepressed] Same sell upgrade clicked, deselecting")
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
            else
                -- Set the sell selection to this upgrade
                print(string.format("[MAIN.mousepressed] Setting sell selection to upgrade %s", tostring(clicked_upgrade_id)))
                selected_sell_upgrade_id = clicked_upgrade_id
                selected_sell_upgrade_index = sell_index
                selected_sell_upgrade_position_x = gx
                selected_sell_upgrade_position_y = gy
            end
            -- Deselect buy selection when clicking display boxes
            selected_upgrade_id = nil
            selected_upgrade_box_index = nil
            selected_upgrade_position_x = nil
            selected_upgrade_position_y = nil
            return
        end
        
        -- Check if SELL button was clicked on a purchased upgrade
        local sell_action = Shop.check_sell_button_click(gx, gy, selected_sell_upgrade_index, UI.get_upgrade_box_positions())
        if sell_action == "sell" then
            if selected_sell_upgrade_id then
                print("[SHOP] Selling upgrade: " .. selected_sell_upgrade_id)
                UpgradeNode.remove_upgrade(selected_sell_upgrade_id)
            end
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            return
        end
        
        -- Click anywhere else in shop deselects
        selected_upgrade_id = nil
        selected_upgrade_box_index = nil
        selected_upgrade_position_x = nil
        selected_upgrade_position_y = nil
        selected_sell_upgrade_id = nil
        selected_sell_upgrade_index = nil
        selected_sell_upgrade_position_x = nil
        selected_sell_upgrade_position_y = nil
        return
    end
    
    -- Check for SELL interactions during normal gameplay (not in shop)
    if game_state == "GAME" and button == 1 then
        -- Check if SELL button was clicked
        local sell_action = Shop.check_sell_button_click(gx, gy, selected_sell_upgrade_index, UI.get_upgrade_box_positions())
        if sell_action == "sell" then
            if selected_sell_upgrade_id then
                print("[GAME] Selling upgrade: " .. selected_sell_upgrade_id)
                UpgradeNode.remove_upgrade(selected_sell_upgrade_id)
            end
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            return
        end
        
        -- Check if a display box (purchased upgrade) was clicked
        local sell_index = Shop.check_display_box_click(gx, gy, UI.get_upgrade_box_positions())
        if sell_index then
            local selected_upgrades = UpgradeNode.get_selected_upgrades()
            local clicked_upgrade_id = selected_upgrades[sell_index]
            
            print(string.format("[MAIN.mousepressed] Display box %d clicked, upgrade_id=%s, current sell selection=%s", sell_index, tostring(clicked_upgrade_id), tostring(selected_sell_upgrade_id)))
            
            -- If clicking the same upgrade that's already selected for selling, deselect it
            if selected_sell_upgrade_id and selected_sell_upgrade_id == clicked_upgrade_id then
                print("[MAIN.mousepressed] Same sell upgrade clicked, deselecting")
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
            else
                -- Set the sell selection to this upgrade
                print(string.format("[MAIN.mousepressed] Setting sell selection to upgrade %s", tostring(clicked_upgrade_id)))
                selected_sell_upgrade_id = clicked_upgrade_id
                selected_sell_upgrade_index = sell_index
                selected_sell_upgrade_position_x = gx
                selected_sell_upgrade_position_y = gy
            end
            return
        end
    end
    
    if game_state == "FAILSTATE" and button == 1 then
        -- Check if "COME BACK SOON" button was clicked
        if Failstate.check_button_click(gx, gy) then
            Failstate.fade_out()
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
        
        -- Check if return to menu button was clicked
        if Settings.check_return_to_menu_click(gx, gy) then
            game_state = "MENU" -- Return to main menu
            Lever.clearParticles()  -- Clear particles when returning to menu
            return
        end
        return
    end

    if game_state == "GAME" and button == 1 then
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

function love.mousemoved(x, y, dx, dy)
    local gx, gy = get_game_coords(x, y)
    
    -- Update hover state for purchased upgrades (active in all game states)
    local upgrade_box_positions = UI.get_upgrade_box_positions()
    
    if upgrade_box_positions and #upgrade_box_positions > 0 then
        hovered_upgrade_index, hovered_upgrade_id = Shop.check_display_box_hover(gx, gy, upgrade_box_positions)
    else
        hovered_upgrade_index = nil
        hovered_upgrade_id = nil
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
        -- Do nothing in menu state - let mouse clicks handle menu interactions
        return

    elseif game_state == "GAME" then
        
        if key == "space" then
            print("[KEYPRESSED] Space key detected in GAME state")
            
            if Slots.is_jammed() then
                Slots.re_splash_jam()
                return
            end
            
            -- Only allow spin if we have spins remaining
            if Shop.get_spins_remaining() <= 0 then
                print("[KEYPRESSED] No spins remaining!")
                return
            end
            
            -- Callbacks are already set in the update loop, just trigger the lever
            print("[KEYPRESSED] Triggering lever and spin")
            Lever.trigger(Slots.start_spin)
            Background.setSpinning(true)
            print("[KEYPRESSED] Spin initiated") 
        else
            Slots.keypressed(key)
        end
    end
end

function love.mousemoved(x, y)
    if game_state == "GAME" then
        local gx, gy = get_game_coords(x, y)
        Lever.mouseMoved(gx, gy)
    end
end