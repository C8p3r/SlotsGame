-- main.lua
local Config = require("conf")
local UIConfig = require("ui.ui_config")
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
local UpgradeTooltips = require("ui.upgrade_tooltips")

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

-- Drag and drop state for display case upgrades
local dragging_sprite = nil  -- Currently dragged sprite object
local drag_offset_x = 0  -- Offset from sprite center to mouse
local drag_offset_y = 0
local original_drag_index = nil  -- Original index before drag started
local original_drag_x = 0  -- Original x position before drag started
local original_drag_y = 0  -- Original y position before drag started
local potential_drag_sprite = nil  -- Sprite that was clicked (may become drag or click)
local potential_drag_x = 0  -- Initial click x position
local potential_drag_y = 0  -- Initial click y position
local drag_threshold = 10  -- Pixels to move before committing to drag

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
    -- Compute the same horizontal menu offset used during drawing so hover tests match
    local entrance_progress = entrance_duration > 0 and (entrance_timer / entrance_duration) or 1
    local entrance_ease = 1 - (1 - entrance_progress) ^ 3
    local entrance_offset = (1 - entrance_ease) * w

    local exit_progress = exit_duration > 0 and (exit_timer / exit_duration) or 0
    local exit_ease = exit_progress * exit_progress
    local exit_slide_offset = exit_ease * w

    local menu_offset = entrance_offset - exit_slide_offset

    local grid_start_x = w * 0.02 + menu_offset
    local grid_start_y = h * 0.25 + 50

    local hovered_id, ks_x, ks_y, ks_w, ks_h = Keepsakes.get_hovered_keepsake(game_mouse_x, game_mouse_y, grid_start_x, grid_start_y, 96, 32)
    HomeMenu.draw_keepsake_tooltip(hovered_id, ks_x, ks_y, ks_w, ks_h)
    

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
    
    -- Clear purchased upgrades for new game
    UpgradeNode.clear_selected_upgrades()
    
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
    
    -- Update upgrade sprites (handles state transitions and animations)
    UpgradeNode.update(dt)
    
    -- Safety check: ensure all sprites have valid indices and states
    local selected_upgrades = UpgradeNode.get_selected_upgrades()
    for i, sprite in ipairs(selected_upgrades) do
        if not sprite.index or sprite.index < 1 or sprite.index > #selected_upgrades then
            sprite.index = i  -- Force valid index
        end
        
        -- Detect orphaned shifting animations and force completion
        if sprite.state == "shifting" then
            if not sprite.animation_duration or sprite.animation_duration == 0 then
                -- Shift animation has no duration, force it to complete
                sprite.state = "owned"
                sprite.animation_progress = 0
            elseif sprite.animation_progress and sprite.animation_progress > sprite.animation_duration then
                -- Animation exceeded duration, complete it immediately
                sprite.state = "owned"
                sprite.x = sprite.target_x
                sprite.y = sprite.target_y
                sprite.animation_progress = 0
                sprite.animation_duration = 0
            end
        end
    end
    
    -- If dragging sprite is somehow still active but mouse isn't pressed, snap it back
    if dragging_sprite then
        local buttons = love.mouse.isDown(1)
        if not buttons then
            -- Mouse is not pressed, snap the sprite back into place
            UpgradeNode.reposition_owned_upgrades()
            dragging_sprite = nil
            original_drag_index = nil
            original_drag_x = 0
            original_drag_y = 0
        end
    end
    
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
    
    -- Draw Display Boxes (only in game states, not menu, not failstate)
    if game_state ~= "MENU" and game_state ~= "FAILSTATE" then
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
        
        -- 4j. Draw upgrades layer on foremost (on top of all game elements) - NOT in failstate
        if game_state ~= "FAILSTATE" then
            UI.drawUpgradesLayer()
            
            -- Draw SELL button for selected purchase (available at all stages except failstate)
            -- Get upgrade box positions for drawing (now populated after drawUpgradesLayer)
            local upgrade_box_positions = UI.get_upgrade_box_positions()
            if selected_sell_upgrade_id or Shop.is_sell_animating() then
                Shop.draw_sell_button(selected_sell_upgrade_index, upgrade_box_positions)
            end
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
    
    -- Draw tooltips LAST so they always appear on top of everything
    if game_state ~= "MENU_EXIT" then
        local upgrade_box_positions = UI.get_upgrade_box_positions()
        -- Re-apply game-space transform so tooltips (which expect game coords) render correctly
        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)
        love.graphics.scale(scale)
        UpgradeTooltips.draw_all(upgrade_box_positions)
        love.graphics.pop()
    end
end

local function get_game_coords(x, y)
    return (x - offset_x) / scale, (y - offset_y) / scale
end

-- Reorder sprites in selected_upgrades array based on x positions
local function reorder_selected_upgrades()
    local selected_upgrades = UpgradeNode.get_selected_upgrades()
    
    if not selected_upgrades or #selected_upgrades == 0 then
        return
    end
    
    -- Sort by x position (left to right) with current index as tiebreaker for stability
    table.sort(selected_upgrades, function(a, b)
        if math.abs(a.x - b.x) > 5 then  -- Only reorder if x differs by more than 5 pixels
            return a.x < b.x
        end
        -- Use current index as tiebreaker for stability
        return (a.index or 999) < (b.index or 999)
    end)
    
    -- Update indices (1-based, ensure all are valid)
    for i, sprite in ipairs(selected_upgrades) do
        sprite.index = i
    end
end

-- Check if click is on an owned display sprite and mark as potential drag
local function try_start_upgrade_drag(gx, gy)
    local upgrade_box_positions = UI.get_upgrade_box_positions()
    if not upgrade_box_positions then
        return false
    end
    
    for _, box in ipairs(upgrade_box_positions) do
        -- Allow clicking of owned, hovered, or shifting sprites
        if box.sprite and (box.sprite.state == "owned" or box.sprite.state == "hovered" or box.sprite.state == "shifting") then
            -- Check if click is within this sprite's bounding box
            if gx >= box.x and gx < box.x + box.width and
               gy >= box.y and gy < box.y + box.height then
                -- Mark as potential drag (will commit to drag once mouse moves)
                potential_drag_sprite = box.sprite
                potential_drag_x = gx
                potential_drag_y = gy
                return true
            end
        end
    end
    
    return false
end

-- Commit to actual dragging once mouse moves beyond threshold
local function commit_to_drag(gx, gy)
    if not potential_drag_sprite then
        return false
    end
    
    -- Check if mouse has moved beyond the drag threshold
    local dx = math.abs(gx - potential_drag_x)
    local dy = math.abs(gy - potential_drag_y)
    
    if dx > drag_threshold or dy > drag_threshold then
        -- Committed to drag - find the sprite's info
        local upgrade_box_positions = UI.get_upgrade_box_positions()
        if upgrade_box_positions then
            for _, box in ipairs(upgrade_box_positions) do
                if box.sprite == potential_drag_sprite then
                    -- Start actual dragging
                    dragging_sprite = box.sprite
                    original_drag_index = box.index
                    original_drag_x = box.sprite.x
                    original_drag_y = box.sprite.y
                    -- Calculate offset from sprite center to mouse
                    local sprite_center_x = box.x + box.width / 2
                    local sprite_center_y = box.y + box.height / 2
                    drag_offset_x = gx - sprite_center_x
                    drag_offset_y = gy - sprite_center_y
                    
                    potential_drag_sprite = nil
                    return true
                end
            end
        end
    end
    
    return false
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
        -- Handle seed UI clicks first
        if HomeMenu.check_seed_click and HomeMenu.check_seed_click(gx, gy) then
            return
        end

        -- Check if START button was clicked
        if check_start_button_click(gx, gy) then
            HomeMenu.start_exit_animation()  -- Start menu exit animation
            game_state = "HOME_MENU_TO_GAME_TRANSITION"
            -- Apply shop seed settings (if any) before initializing the shop
            local seeded, seed_val = HomeMenu.get_shop_seed_settings()
            if seeded then
                UpgradeNode.set_shop_seed(seed_val)
            else
                UpgradeNode.set_shop_seed(nil)
            end
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

    -- If a sell popup is active, a click should close it unless the click is on the SELL button
    if button == 1 and selected_sell_upgrade_id then
        local is_on_sell_button = Shop.check_sell_button_click(gx, gy, selected_sell_upgrade_index, UI.get_upgrade_box_positions())
        if not is_on_sell_button then
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            Shop.close_sell_popup()
            return
        end
        -- if it is on the sell button, allow normal flow to handle it
    end
    
    -- Try to start dragging a display case sprite (available in all game states)
    if button == 1 and try_start_upgrade_drag(gx, gy) then
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
            if selected_upgrade_id and selected_upgrade_position_x and selected_upgrade_position_y then
                -- Calculate cost and check if player has enough gems BEFORE selecting
                local cost = UpgradeNode.get_buy_cost(selected_upgrade_id)
                local current_gems = Shop.get_gems()

                if current_gems < cost then
                    -- Player can't afford it; ignore the click (do nothing)
                    print(string.format("[SHOP] Buy blocked: upgrade %d costs %d gems, player has %d", selected_upgrade_id, cost, current_gems))
                    return
                end

                -- Enough gems: perform the purchase
                if UpgradeNode.select_upgrade(selected_upgrade_id) then
                    Shop.add_gems(-cost)
                    print(string.format("[SHOP] Purchased upgrade %d for %d gems (remaining: %d)", selected_upgrade_id, cost, Shop.get_gems()))
                    Shop.remove_shop_sprite(selected_upgrade_id)
                    UpgradeNode.reposition_owned_upgrades()
                    UpgradeNode.add_flying_upgrade(selected_upgrade_id, selected_upgrade_position_x, selected_upgrade_position_y)
                end
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
            Shop.close_sell_popup()
            return
        end
        
        -- Check if a display box (purchased upgrade) was clicked
        local sell_index, sell_upgrade_id = Shop.check_display_box_click(gx, gy, UI.get_upgrade_box_positions())
        if sell_index then
            print(string.format("[MAIN.mousepressed] Display box %d clicked, upgrade_id=%s, current sell selection=%s", sell_index, tostring(sell_upgrade_id), tostring(selected_sell_upgrade_id)))
            
            -- If clicking the same upgrade that's already selected for selling, deselect it
            if selected_sell_upgrade_id and selected_sell_upgrade_id == sell_upgrade_id then
                print("[MAIN.mousepressed] Same sell upgrade clicked, deselecting")
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
                Shop.close_sell_popup()
            else
                -- Set the sell selection to this upgrade
                print(string.format("[MAIN.mousepressed] Setting sell selection to upgrade %s", tostring(sell_upgrade_id)))
                selected_sell_upgrade_id = sell_upgrade_id
                selected_sell_upgrade_index = sell_index
                selected_sell_upgrade_position_x = gx
                selected_sell_upgrade_position_y = gy
                Shop.open_sell_popup()
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
                local sell_value = UpgradeNode.get_sell_value(selected_sell_upgrade_id)
                Shop.add_gems(sell_value)
                print(string.format("[SHOP] Sold upgrade %d for %d gems (total gems: %d)", selected_sell_upgrade_id, sell_value, Shop.get_gems()))
                UpgradeNode.remove_upgrade(selected_sell_upgrade_id)
                -- Reposition remaining upgrades after sale
                UpgradeNode.reposition_owned_upgrades()
            end
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            Shop.close_sell_popup()
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
            Shop.close_sell_popup()
        return
    end
    
    -- Check for SELL interactions during normal gameplay (not in shop)
    if game_state == "GAME" and button == 1 then
        -- Check if a display box (purchased upgrade) was clicked
        local sell_index, sell_upgrade_id = Shop.check_display_box_click(gx, gy, UI.get_upgrade_box_positions())
        if sell_index then
            print(string.format("[MAIN.mousepressed GAME] Display box %d clicked, upgrade_id=%s, current sell selection=%s", sell_index, tostring(sell_upgrade_id), tostring(selected_sell_upgrade_id)))
            
            -- If clicking the same upgrade that's already selected for selling, deselect it
            if selected_sell_upgrade_id and selected_sell_upgrade_id == sell_upgrade_id then
                print("[MAIN.mousepressed GAME] Same sell upgrade clicked, deselecting")
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
                Shop.close_sell_popup()
            else
                -- Set the sell selection to this upgrade
                print(string.format("[MAIN.mousepressed GAME] Setting sell selection to upgrade %s", tostring(sell_upgrade_id)))
                selected_sell_upgrade_id = sell_upgrade_id
                selected_sell_upgrade_index = sell_index
                selected_sell_upgrade_position_x = gx
                selected_sell_upgrade_position_y = gy
                Shop.open_sell_popup()
            end
            return
        end
        
        -- Check if SELL button was clicked
        local sell_action = Shop.check_sell_button_click(gx, gy, selected_sell_upgrade_index, UI.get_upgrade_box_positions())
        if sell_action == "sell" then
            if selected_sell_upgrade_id then
                local sell_value = UpgradeNode.get_sell_value(selected_sell_upgrade_id)
                Shop.add_gems(sell_value)
                print(string.format("[GAME] Sold upgrade %d for %d gems (total gems: %d)", selected_sell_upgrade_id, sell_value, Shop.get_gems()))
                UpgradeNode.remove_upgrade(selected_sell_upgrade_id)
                -- Reposition remaining upgrades after sale
                UpgradeNode.reposition_owned_upgrades()
            end
            selected_sell_upgrade_id = nil
            selected_sell_upgrade_index = nil
            selected_sell_upgrade_position_x = nil
            selected_sell_upgrade_position_y = nil
            Shop.close_sell_popup()
            return
        end
        
        -- Check if a display box (purchased upgrade) was clicked
        local sell_index, sell_upgrade_id = Shop.check_display_box_click(gx, gy, UI.get_upgrade_box_positions())
        if sell_index then
            print(string.format("[MAIN.mousepressed] Display box %d clicked, upgrade_id=%s, current sell selection=%s", sell_index, tostring(sell_upgrade_id), tostring(selected_sell_upgrade_id)))
            
            -- If clicking the same upgrade that's already selected for selling, deselect it
            if selected_sell_upgrade_id and selected_sell_upgrade_id == sell_upgrade_id then
                print("[MAIN.mousepressed] Same sell upgrade clicked, deselecting")
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
            else
                -- Set the sell selection to this upgrade
                print(string.format("[MAIN.mousepressed] Setting sell selection to upgrade %s", tostring(sell_upgrade_id)))
                selected_sell_upgrade_id = sell_upgrade_id
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
    
    -- Handle potential drag that never committed (treated as a click)
    if potential_drag_sprite and button == 1 then
        local gx, gy = get_game_coords(x, y)
        
        -- Check if mouse barely moved (not a significant drag)
        local DRAG_THRESHOLD = 10
        local distance_x = math.abs(gx - potential_drag_x)
        local distance_y = math.abs(gy - potential_drag_y)
        local distance = math.sqrt(distance_x * distance_x + distance_y * distance_y)
        
        if distance < DRAG_THRESHOLD then
            -- Treat as click - find the upgrade info and select it
            local upgrade_box_positions = UI.get_upgrade_box_positions()
            if upgrade_box_positions then
                for _, box in ipairs(upgrade_box_positions) do
                    if box.sprite == potential_drag_sprite then
                        -- Select this upgrade to show the sell button
                        selected_sell_upgrade_id = box.upgrade_id
                        selected_sell_upgrade_index = box.index
                        selected_sell_upgrade_position_x = gx
                        selected_sell_upgrade_position_y = gy
                        Shop.open_sell_popup()
                        break
                    end
                end
            end
        end
        
        -- Clear potential drag
        potential_drag_sprite = nil
        return
    end
    
    -- End drag if one is active
    if dragging_sprite and button == 1 then
        -- Validate that the sprite still exists in selected_upgrades
        local found = false
        local selected_upgrades = UpgradeNode.get_selected_upgrades()
        for _, sprite in ipairs(selected_upgrades) do
            if sprite == dragging_sprite then
                found = true
                break
            end
        end
        
        if found then
            -- Step 1: Reorder sprites based on their current x positions (left to right)
            reorder_selected_upgrades()
            
            -- Step 2: Snap all sprites to their correct positions based on new indices
            UpgradeNode.reposition_owned_upgrades()
        end
        
        dragging_sprite = nil
        original_drag_index = nil
        original_drag_x = 0
        original_drag_y = 0
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
    
    -- Check if potential drag should commit to actual drag
    if potential_drag_sprite and not dragging_sprite then
        if commit_to_drag(gx, gy) then
            -- Drag committed, will be handled below
        end
    end
    
    -- Handle dragging of display case sprites
    if dragging_sprite then
        -- Update sprite position to follow mouse (with offset)
        local sprite_center_x = gx - drag_offset_x
        local sprite_center_y = gy - drag_offset_y
        dragging_sprite.x = sprite_center_x - dragging_sprite.display_scale * 32 / 2  -- 32 is base sprite size
        dragging_sprite.y = sprite_center_y - dragging_sprite.display_scale * 32 / 2
        
        -- Reorder sprites in real-time based on current x positions for visual feedback
        reorder_selected_upgrades()
        
        -- Snap non-dragged sprites to their new positions immediately
        local selected_upgrades = UpgradeNode.get_selected_upgrades()
        local flying_sprite_size = 128
        local usable_width = Config.SLOT_WIDTH * UIConfig.DISPLAY_BOX_COUNT
        local spacing_x = usable_width / (5 + 1)
        local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
        local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
        local center_y = box_y + BOX_HEIGHT / 2
        local start_x_box = Config.PADDING_X + 30
        
        for i, sprite in ipairs(selected_upgrades) do
            -- Skip the dragged sprite, let it follow the mouse
            if sprite ~= dragging_sprite then
                sprite.index = i
                local target_x = start_x_box + 10 + spacing_x * i
                local target_y = center_y - flying_sprite_size / 2
                sprite.x = target_x
                sprite.y = target_y
            end
        end
        
        return
    end
    
    -- Update hover state for purchased upgrades (active in all game states)
    local upgrade_box_positions = UI.get_upgrade_box_positions()
    
    if upgrade_box_positions and #upgrade_box_positions > 0 then
        hovered_upgrade_index, hovered_upgrade_id = Shop.check_display_box_hover(gx, gy, upgrade_box_positions)
    else
        hovered_upgrade_index = nil
        hovered_upgrade_id = nil
    end
    
    -- Handle lever mouse movement
    if game_state == "GAME" then
        Lever.mouseMoved(gx, gy)
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
        -- Forward keypresses to menu (allow seed input handling)
        if HomeMenu.keypressed and HomeMenu.keypressed(key) then
            return
        end
        -- Do nothing else in menu state - let mouse clicks handle menu interactions
        return

    elseif game_state == "GAME" then
        
        if key == "space" then
            -- If a sell popup is open, close it on SPACE instead of triggering a spin
            if selected_sell_upgrade_id then
                selected_sell_upgrade_id = nil
                selected_sell_upgrade_index = nil
                selected_sell_upgrade_position_x = nil
                selected_sell_upgrade_position_y = nil
                Shop.close_sell_popup()
                return
            end
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