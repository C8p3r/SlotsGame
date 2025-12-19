-- shop.lua
-- Shop menu system for round progression and spin allocation
local Config = require("conf")
local UIConfig = require("ui.ui_config")
local UpgradeNode = require("systems.upgrade_node")
local UpgradeSprite = require("systems.upgrade_sprite")
local UpgradeTooltips = require("ui.upgrade_tooltips")
local Settings = require("ui.settings")

local Shop = {}

-- Global shop text vertical offset (negative = move up)
local TEXT_Y_OFFSET = -15

local function shop_print(text, x, y)
    if not text then return end
    love.graphics.print(text, x, y + TEXT_Y_OFFSET)
end

local function shop_printf(text, x, y, limit, align)
    love.graphics.printf(text, x, y + TEXT_Y_OFFSET, limit, align)
end

-- Shop state
local is_open = false
local current_round = 0
local spins_remaining = 0
local balance_goal = 0
local spins_per_round = 100
local base_balance_goal = 1000
local goal_multiplier = 1.5  -- Increase goal by 50% each round

-- Shop sprites for all 50 upgrades
local shop_sprites = {}  -- Sprites for unpurchased upgrades in shop

-- Shop animation state
local shop_entrance_timer = 0
local shop_entrance_duration = 0.6
local is_shop_entering = false
local is_shop_closing = false

-- Gems currency (secondary currency in shops)
local gems = 0
local gems_gained = 0  -- Gems gained in the current round
local conversion_rate = 1  -- 1 excess spin = 1 gem
local converting_gems = 0  -- Gems currently being converted (animated)
local gem_conversion_timer = 0
local gem_conversion_duration = 0.5

-- Shop menu dimensions
local SHOP_W = Config.GAME_WIDTH * 0.77  -- Wide to cover all slots
local SHOP_H = Config.GAME_HEIGHT * 0.5
local SHOP_X = (Config.GAME_WIDTH - SHOP_W) / 2
local SHOP_Y = (Config.GAME_HEIGHT - SHOP_H) / 2 + 92  -- Move down 100px

-- UI Assets
local ui_assets = nil
local gem_icon_quad = nil  -- Second row, second column quad
local upgrade_units_image = nil
local upgrade_units_quads = {}  -- Table to store all upgrade icon quads
local invert_shader = nil

-- Gem splash particle state
local gem_splashes = {}
local last_spend_invert_timer = 0
-- Upgrade icon splash particles (spawn small copies of the sold upgrade)
local upgrade_splashes = {}

-- Popup animation state (for BUY and SELL popups)
local buy_popup_state = "closed"  -- "closed" | "open"
local buy_popup_timer = 0
local buy_popup_duration = 0.0
local last_selected_upgrade_id = nil
local last_selected_upgrade_box_index = nil

local sell_popup_state = "closed"
local sell_popup_timer = 0
local sell_popup_duration = 0.0
local last_selected_sell_index = nil
-- forward declare popup timer advancer so Shop.update can call it
local advance_popup_timers

-- Easing helper (ease-out cubic)
local function ease_out_cubic(t)
    return 1 - math.pow(1 - t, 3)
end

-- Unified popup visual parameters
local POPUP_SLIDE_PIXELS = 16
local POPUP_MIN_ALPHA = 0.35

-- Load UI assets for gem icon
local function load_ui_assets()
    if not ui_assets then
        ui_assets = love.graphics.newImage("assets/UI_assets.png")
        -- Assuming 4 columns per row, second row second column = quad index 6
        -- Row 2, Col 2: (row-1) * cols + col = (2-1) * 4 + 2 = 6
        local quad_width = 32
        local quad_height = 32
        local cols = 4
        local col = 2
        local row = 2
        local x = (col - 1) * quad_width
        local y = (row - 1) * quad_height
        gem_icon_quad = love.graphics.newQuad(x, y, quad_width, quad_height, ui_assets:getDimensions())
    end
    -- Try to load invert shader for spent visuals
    if not invert_shader then
        local ok, src
        local f = io.open("shaders/invert_rgb_shader.glsl", "r")
        if f then
            src = f:read("*a")
            f:close()
            local success, shader_or_err = pcall(love.graphics.newShader, src)
            if success then
                invert_shader = shader_or_err
            else
                print("[SHOP] Failed to load invert shader: " .. tostring(shader_or_err))
                invert_shader = nil
            end
        end
    end
    
    -- Load upgrade units image
    if not upgrade_units_image then
        upgrade_units_image = love.graphics.newImage("assets/upgrade_units_UI.png")
        upgrade_units_image:setFilter("nearest", "nearest")  -- Crisp pixel rendering
        
        -- Create quads for all 32x32 icons from the 160x320 grid
        local icon_size = 32
        local cols = 5  -- 160 / 32 = 5 columns
        local rows = 10  -- 320 / 32 = 10 rows
        
        for row = 0, rows - 1 do
            for col = 0, cols - 1 do
                local x = col * icon_size
                local y = row * icon_size
                table.insert(upgrade_units_quads, love.graphics.newQuad(x, y, icon_size, icon_size, upgrade_units_image:getDimensions()))
            end
        end
    end
end

-- Convert screen mouse coords to game-space coords (respecting current scale/offset)
local function get_game_mouse()
    local sx, sy = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    local s = math.min(w / Config.GAME_WIDTH, h / Config.GAME_HEIGHT)
    local ox = (w - Config.GAME_WIDTH * s) / 2
    local oy = (h - Config.GAME_HEIGHT * s) / 2
    return (sx - ox) / s, (sy - oy) / s
end

function Shop.initialize(initial_bankroll)
    current_round = 1
    spins_remaining = spins_per_round
    balance_goal = base_balance_goal
    is_open = false
    
    -- Initialize shop sprites for all 50 upgrades
    shop_sprites = {}
    for upgrade_id = 1, 50 do
        table.insert(shop_sprites, UpgradeSprite.create(upgrade_id, "available"))
    end

    -- Clear purchased tracker for new game
    UpgradeNode.clear_purchased_this_round()

    print("[SHOP.INITIALIZE] Shop initialized! spins_remaining: " .. spins_remaining .. ", balance_goal: " .. balance_goal)
end

-- Start a new round (advance round counter and reset shop state)
function Shop.start_new_round()
    current_round = current_round + 1
    spins_remaining = spins_per_round
    balance_goal = math.floor(base_balance_goal * (goal_multiplier ^ (current_round - 1)))
    is_open = true

    -- Clear purchased tracker for new round
    UpgradeNode.clear_purchased_this_round()

    -- Reset bankroll to initial amount for the new round if slot machine state exists
    local SlotMachine = require("game_mechanics.slot_machine")
    local state = SlotMachine.getState()
    if state then
        state.bankroll = Config.INITIAL_BANKROLL
    end
end

-- Open the shop (entrance animation and generate shop offerings)
function Shop.open()
    is_open = true
    is_shop_entering = true
    is_shop_closing = false
    shop_entrance_timer = 0

    -- Generate shop upgrades; allow upgrades to increase offered items
    local UpgradeEffects = require("systems.upgrade_effects")
    local shop_mods = UpgradeEffects.get_shop_mods()
    local count = 3 + (shop_mods and (shop_mods.extra_items or 0) or 0)
    UpgradeNode.generate_shop_upgrades(count)

    -- Convert excess spins to gems immediately (allow upgrades to modify conversion)
    local excess_spins = spins_remaining - 0
    local UpgradeEffects2 = require("systems.upgrade_effects")
    local currency_mods = UpgradeEffects2.get_currency_mods()
    local conv_mult = currency_mods and currency_mods.gem_conversion_mult or 1.0
    if excess_spins > 0 then
        gems_gained = math.floor(excess_spins * conversion_rate * conv_mult)
        gems = gems + gems_gained
        print("[SHOP] Added " .. gems_gained .. " gems! Total gems: " .. gems)
    else
        gems_gained = 0
    end
end
function Shop.close()
    is_shop_closing = true
    is_shop_entering = false
    shop_entrance_timer = shop_entrance_duration  -- Start from end, count down
end

-- Get the current slide offset for click detection
function Shop.get_slide_offset()
    local animation_progress = shop_entrance_duration > 0 and (shop_entrance_timer / shop_entrance_duration) or 1
    local ease_progress = 1 - (1 - animation_progress) ^ 3
    return (1 - ease_progress) * Config.GAME_HEIGHT
end

function Shop.is_open()
    return is_open or is_shop_entering or is_shop_closing
end

function Shop.get_spins_remaining()
    return spins_remaining
end

function Shop.get_shop_sprites()
    return shop_sprites
end

function Shop.update_shop_sprites(dt)
    -- Update all shop sprite states (handle hover animations, etc)
    for _, sprite in ipairs(shop_sprites) do
        UpgradeSprite.update(sprite, dt)
    end
end

function Shop.set_shop_sprite_hover(upgrade_id, is_hovered)
    -- Find and update the hover state of a shop sprite
    for _, sprite in ipairs(shop_sprites) do
        if sprite.upgrade_id == upgrade_id then
            UpgradeSprite.set_hovered(sprite, is_hovered)
            break
        end
    end
end

function Shop.remove_shop_sprite(upgrade_id)
    -- Remove a sprite from the shop (after purchase)
    for i, sprite in ipairs(shop_sprites) do
        if sprite.upgrade_id == upgrade_id then
            table.remove(shop_sprites, i)
            break
        end
    end
    -- Mark as purchased this round so it won't reappear if sold
    UpgradeNode.mark_purchased(upgrade_id)
end

function Shop.get_gems()
    return gems
end

function Shop.add_gems(amount)
    gems = gems + amount
    if amount > 0 then
        print(string.format("[SHOP] Added %d gems (total: %d)", amount, gems))
    else
        print(string.format("[SHOP] Removed %d gems (total: %d)", -amount, gems))
    end
    -- Spawn gem splash particles at the gems UI element center
    local gx, gy = Settings.get_gems_ui_position()
    -- use that center as spawn origin
    Shop.spawn_gem_splash(amount, gx, gy, amount < 0)
end


function Shop.spawn_gem_splash(amount, x, y, spent)
    local count = math.min(12, math.max(6, math.floor(math.abs(amount))))
    for i = 1, count do
        local angle = math.rad(math.random(240, 300)) + (math.random() - 0.5) * 0.6
        local speed = math.random(80, 220)
        local vx = math.cos(angle) * speed * (0.6 + math.random() * 0.8)
        local vy = math.sin(angle) * speed * (0.6 + math.random() * 0.8)
        table.insert(gem_splashes, {
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            ttl = 0.9 + math.random() * 0.6,
            age = 0,
            rot = math.random() * math.pi * 2,
            spin = (math.random() - 0.5) * 6,
            scale = 0.6 + math.random() * 0.9,
            spent = spent,
            alpha = 1
        })
    end
    if spent then
        last_spend_invert_timer = 0.35
    end
end

function Shop.spawn_upgrade_splash(upgrade_id, x, y, count)
    count = count or 6
    if not upgrade_units_quads or #upgrade_units_quads == 0 then return end
    for i = 1, count do
        local angle = math.rad(math.random(0, 360))
        local speed = math.random(60, 220)
        local vx = math.cos(angle) * speed * (0.5 + math.random() * 0.8)
        local vy = math.sin(angle) * speed * (0.5 + math.random() * 0.8)
        table.insert(upgrade_splashes, {
            x = x or 0,
            y = y or 0,
            vx = vx,
            vy = vy,
            ttl = 0.6 + math.random() * 0.5,
            age = 0,
            rot = math.random() * math.pi * 2,
            spin = (math.random() - 0.5) * 6,
            scale = 0.5 + math.random() * 0.6,
            quad_index = upgrade_id,
            alpha = 1
        })
    end
end

function Shop.reset_gems()
    gems = 0
    converting_gems = 0
    gem_conversion_timer = 0
    print("[SHOP] Gems reset to 0")
end



function Shop.use_spin()
    print("[SHOP.USE_SPIN] Called! Current spins_remaining: " .. spins_remaining)
    if spins_remaining > 0 then
        spins_remaining = spins_remaining - 1
        print("[SHOP.USE_SPIN] Spin used! New spins_remaining: " .. spins_remaining)
        return true
    end
    print("[SHOP.USE_SPIN] No spins available! spins_remaining: " .. spins_remaining)
    return false
end

function Shop.get_balance_goal()
    return balance_goal
end

function Shop.get_current_round()
    return current_round
end

function Shop.get_spins_per_round()
    return spins_per_round
end

function Shop.update(dt)
    -- Update shop animation
    if is_shop_entering then
        shop_entrance_timer = shop_entrance_timer + dt
        if shop_entrance_timer >= shop_entrance_duration then
            shop_entrance_timer = shop_entrance_duration
            is_shop_entering = false
        end
    elseif is_shop_closing then
        shop_entrance_timer = shop_entrance_timer - dt
        if shop_entrance_timer <= 0 then
            shop_entrance_timer = 0
            is_shop_closing = false
            is_open = false
        end
    end
    -- Update gem splashes
    if last_spend_invert_timer > 0 then
        last_spend_invert_timer = math.max(0, last_spend_invert_timer - dt)
    end
    for i = #gem_splashes, 1, -1 do
        local p = gem_splashes[i]
        p.age = p.age + dt
        if p.age >= p.ttl then
            table.remove(gem_splashes, i)
        else
            -- simple physics
            p.vy = p.vy + 500 * dt  -- gravity
            p.vx = p.vx * (1 - math.min(dt * 3, 0.9))
            p.vy = p.vy * (1 - math.min(dt * 1.5, 0.9))
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.spin * dt
            p.alpha = 1 - (p.age / p.ttl)
        end
    end
    -- Update upgrade splashes
    for i = #upgrade_splashes, 1, -1 do
        local p = upgrade_splashes[i]
        p.age = p.age + dt
        if p.age >= p.ttl then
            table.remove(upgrade_splashes, i)
        else
            p.vy = p.vy + 600 * dt
            p.vx = p.vx * (1 - math.min(dt * 2.5, 0.9))
            p.vy = p.vy * (1 - math.min(dt * 1.2, 0.9))
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.spin * dt
            p.alpha = 1 - (p.age / p.ttl)
        end
    end
    -- Advance popup timers for BUY/SELL animations
    advance_popup_timers(dt)
end

-- Advance popup animation timers
advance_popup_timers = function(dt)
    -- Popups are instant now; ensure timers reflect state
    buy_popup_timer = (buy_popup_state == "open") and 1 or 0
    sell_popup_timer = (sell_popup_state == "open") and 1 or 0
end

-- Expose helper so draw loop can query sell animation active state
function Shop.is_sell_animating()
    return sell_popup_state ~= "closed"
end

-- Programmatically open/close the sell popup (called from main input handlers)
function Shop.open_sell_popup()
    sell_popup_state = "open"
    sell_popup_timer = 1
end

function Shop.close_sell_popup()
    sell_popup_state = "closed"
    sell_popup_timer = 0
end

-- Force the BUY popup to begin exiting (public API for external callers)
function Shop.force_close_buy_popup()
    buy_popup_state = "closed"
    buy_popup_timer = 0
end

function Shop.check_next_button_click(x, y)
    local button_width = 200
    local button_height = 50
    local button_x = SHOP_X + (SHOP_W - button_width) / 2
    local button_y = SHOP_Y + SHOP_H - 330  -- Moved up 250px total
    
    return x >= button_x and x <= button_x + button_width and
           y >= button_y and y <= button_y + button_height
end

-- Check which upgrade box was clicked (1-3)
function Shop.check_upgrade_box_click(x, y)
    -- NOTE: x, y are game coordinates, NOT screen coordinates
    -- The hover detection uses raw screen mouse position, which works
    -- So we should NOT adjust for slide_offset here
    
    local log_msg = string.format("[SHOP.check_upgrade_box_click] x=%.0f, y=%.0f", x, y)
    print(log_msg)
    local debug_file = io.open("debug_clicks.log", "a")
    if debug_file then debug_file:write(log_msg .. "\n"); debug_file:close() end
    
    local box_width = 200
    local box_height = 150
    local stats_y = SHOP_Y + 80
    local line_height = 30
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200  -- Center the 3 boxes, moved left 200px total
    local box_gap = 20
    
    log_msg = string.format("[SHOP.check_upgrade_box_click] box_y_pos=%.0f, box_start_x=%.0f, box_width=%.0f, box_height=%.0f", box_y_pos, box_start_x, box_width, box_height)
    print(log_msg)
    debug_file = io.open("debug_clicks.log", "a")
    if debug_file then debug_file:write(log_msg .. "\n"); debug_file:close() end
    
    for i = 1, 3 do
        local box_x = box_start_x + (i - 1) * (box_width + box_gap)
        log_msg = string.format("[SHOP.check_upgrade_box_click] Box %d: x in [%.0f, %.0f], y in [%.0f, %.0f]", i, box_x, box_x + box_width, box_y_pos, box_y_pos + box_height)
        print(log_msg)
        debug_file = io.open("debug_clicks.log", "a")
        if debug_file then debug_file:write(log_msg .. "\n"); debug_file:close() end
        if x >= box_x and x <= box_x + box_width and
           y >= box_y_pos and y <= box_y_pos + box_height then
            -- Just return the box index - let main.lua handle setting selection state
            local upgrade_id = UpgradeNode.get_box_upgrade(i)
            log_msg = string.format("[SHOP] Box %d matched! upgrade_id=%s", i, tostring(upgrade_id))
            print(log_msg)
            debug_file = io.open("debug_clicks.log", "a")
            if debug_file then debug_file:write(log_msg .. "\n"); debug_file:close() end
            if upgrade_id and not UpgradeNode.is_purchased_this_round(upgrade_id) then
                -- Only return if upgrade hasn't been purchased this round
                -- Return box index and position - main.lua will set the selection state
                return i, box_x + box_width / 2, box_y_pos + box_height / 2
            end
        end
    end
    print("[SHOP.check_upgrade_box_click] No box matched")
    return nil
end

-- Helper function to draw text with wavy/jumping effect
local function draw_wavy_shop_text(text, x, y, font, color)
    if not text or text == "" then return end
    love.graphics.setFont(font)
    love.graphics.setColor(color)
    local time = love.timer.getTime()
    
    -- Intermittent effect - only apply when this oscillates
    local effect_intensity = math.max(0, math.sin(time * 1.5))  -- Turns on/off in cycles
    
    -- Only draw with wavy effect if intensity > 0.2
    if effect_intensity < 0.2 then
        -- Draw normal text when effect is off
        shop_print(text, x, y)
        return
    end
    
    local cursor_x = x
    local base_y = y + TEXT_Y_OFFSET
    local frequency = 0.6  -- Much shorter wavelength
    local speed = 4.0      -- How fast the wave moves
    local amplitude = 2.0 * effect_intensity  -- Amplitude scales with effect intensity
    
    for i = 1, #text do
        local char = text:sub(i, i)
        -- Create a jumping effect where letters jump one at a time
        local wave_y = math.sin(time * speed + i * frequency) * amplitude
        love.graphics.print(char, cursor_x, base_y + wave_y)
        cursor_x = cursor_x + font:getWidth(char)
    end
end

function Shop.draw(current_bankroll, SlotMachine, selected_upgrade_id, selected_upgrade_box_index, selected_upgrade_position_x, selected_upgrade_position_y)
    if not is_open and not is_shop_entering and not is_shop_closing then return end
    
    -- DEBUG: Log shop state at draw time
    local log_msg = string.format("[SHOP.draw] selected_upgrade_id=%s, selected_upgrade_box_index=%s", 
        tostring(selected_upgrade_id), tostring(selected_upgrade_box_index))
    print(log_msg)
    local debug_file = io.open("debug_clicks.log", "a")
    if debug_file then debug_file:write(log_msg .. "\n"); debug_file:close() end
    
    load_ui_assets()  -- Ensure UI assets are loaded
    
    -- Calculate slide animation (0 to 1 for entrance, 1 to 0 for exit)
    local animation_progress = shop_entrance_duration > 0 and (shop_entrance_timer / shop_entrance_duration) or 1
    -- Easing: ease-out cubic for entrance
    local ease_progress = 1 - (1 - animation_progress) ^ 3
    
    -- Slide up from bottom: start below screen, slide to final position
    local slide_offset = (1 - ease_progress) * Config.GAME_HEIGHT

    -- Detect selection change for BUY popup and switch instantly (no animation)
    if selected_upgrade_id ~= last_selected_upgrade_id then
        if selected_upgrade_id then
            buy_popup_state = "open"
            buy_popup_timer = 1
        else
            buy_popup_state = "closed"
            buy_popup_timer = 0
        end
    end
    
    love.graphics.push()
    
    -- Apply slide animation translation
    love.graphics.translate(0, slide_offset)
    
    -- Draw shop menu background (no background overlay)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", SHOP_X, SHOP_Y, SHOP_W, SHOP_H, 10, 10)
    
    -- Draw border
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", SHOP_X, SHOP_Y, SHOP_W, SHOP_H, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Draw title
    love.graphics.setColor(1, 1, 0, 1)
    local title_font = love.graphics.newFont("splashfont.otf", 28)
    love.graphics.setFont(title_font)
    local title = "ROUND " .. current_round
    local title_w = title_font:getWidth(title)
    shop_print(title, SHOP_X + (SHOP_W - title_w) / 2, SHOP_Y + 35)
    
    -- Draw stats section
    love.graphics.setColor(1, 1, 1, 1)
    local stats_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(stats_font)
    
    local stats_x = SHOP_X + 40
    local stats_y = SHOP_Y + 80
    local line_height = 30
    
    -- Spins remaining
    love.graphics.setColor(0.2, 1, 0.2, 1)  -- Green
    shop_print("SPINS REMAINING: " .. spins_remaining, stats_x, stats_y)
    
    -- Current balance
    love.graphics.setColor(0.8, 0.8, 0.2, 1)  -- Gold
    shop_print("CURRENT BALANCE: $" .. string.format("%.0f", current_bankroll), stats_x, stats_y + line_height)
    
    -- Next balance goal (for the upcoming round)
    local next_balance_goal = math.floor(base_balance_goal * (goal_multiplier ^ current_round))
    love.graphics.setColor(1, 0.4, 0.4, 1)  -- Red/Pink
    shop_print("NEXT GOAL: $" .. string.format("%.0f", next_balance_goal), stats_x, stats_y + line_height * 2)
    
    -- Gems gained this round
    if gems_gained > 0 then
        love.graphics.setColor(0.2, 1, 0.8, 1)  -- Bright cyan
        shop_print("GEMS GAINED: +" .. gems_gained, stats_x, stats_y + line_height * 3)
    end
    
    -- Draw 3 display boxes (same size as game display boxes)
    local box_width = 200
    local box_height = 150
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200  -- Center the 3 boxes, moved left 200px total
    local box_gap = 20
    
    -- Calculate the total span box dimensions
    local total_box_width = (box_width * 3) + (box_gap * 2)
    local large_box_x = box_start_x
    local large_box_y = box_y_pos
    
    -- Draw one large box spanning all 3 upgrade positions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", large_box_x, large_box_y, total_box_width, box_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Get mouse position (in game-space) for hover detection so scaling/resizing works
    local game_mouse_x, game_mouse_y = get_game_mouse()
    local hovered_box = nil

    -- gem splashes are drawn later (Shop.draw_gem_splashes) so they remain on top
    
    for i = 1, 3 do
        local box_x = box_start_x + (i - 1) * (box_width + box_gap)
        -- NOTE: mouse_y is in screen space, but we need to compare against screen position
        -- The boxes are drawn at (box_x, box_y_pos) but visually offset by slide_offset
        -- So screen position is (box_x, box_y_pos + slide_offset)
        local screen_box_y = box_y_pos + slide_offset
        local is_hovered = game_mouse_x >= box_x and game_mouse_x <= box_x + box_width and
                   game_mouse_y >= screen_box_y and game_mouse_y <= screen_box_y + box_height
        
        if is_hovered then
            hovered_box = i
        end
        
        -- Draw transparent center area for icon positioning
        local center_x = box_x + box_width / 2
        local center_y = box_y_pos + box_height / 2
        local actual_icon_size = 128  -- 32 pixels * 4 scale
        local icon_x = center_x - actual_icon_size / 2
        local icon_y = center_y - actual_icon_size / 2
        
        -- Add sinusoidal drift animation (varies by box index)
        local drift_x = math.sin(love.timer.getTime() * 2 + i) * 8
        local drift_y = math.sin(love.timer.getTime() * 1.5 + i + 1) * 6
        icon_x = icon_x + drift_x
        icon_y = icon_y + drift_y
        
        -- Draw the assigned upgrade icon in the center
        local upgrade_id = UpgradeNode.get_box_upgrade(i)
        
        -- Add floating up/down animation when selected
        if upgrade_id == selected_upgrade_id then
            local float_offset = math.sin(love.timer.getTime() * 3) * 5 - 10  -- Float up 10px from base
            icon_y = icon_y + float_offset
        end
        
        -- Check if this upgrade has been selected (currently flying or already in display box)
        local selected_upgrades = UpgradeNode.get_selected_upgrades()
        local is_selected = false
        for _, sprite in ipairs(selected_upgrades) do
            if sprite.upgrade_id == upgrade_id then
                is_selected = true
                break
            end
        end
        
        -- Check if this upgrade was purchased earlier this round (don't show even if sold)
        local is_purchased_this_round = UpgradeNode.is_purchased_this_round(upgrade_id) or false
        
        -- Only draw the upgrade icon if it hasn't been selected yet and wasn't purchased this round
        if upgrade_id and upgrade_units_image and upgrade_units_quads[upgrade_id] and not is_selected and not is_purchased_this_round then
            local upgrade_quad = upgrade_units_quads[upgrade_id]
            love.graphics.setColor(1, 1, 1, 1)
            -- Scale the 32x32 icon to 128x128 (4x scale)
            love.graphics.draw(upgrade_units_image, upgrade_quad, icon_x, icon_y, 0, 4, 4)
            
            -- Draw cost and rarity ABOVE the icon (centered, no wobble applied)
            local upgrade_def = UpgradeNode.get_definition(upgrade_id)
            if upgrade_def then
                local cost_font = love.graphics.newFont("splashfont.otf", 12)
                love.graphics.setFont(cost_font)

                -- Compute centered positions above the icon using the static center (no drift/float)
                local text_center_x = center_x
                local icon_top_y = center_y - actual_icon_size / 2

                -- Rarity on top
                local rarity_colors = {
                    Standard = {0.7, 0.7, 0.7},
                    Premium = {0.2, 0.7, 1},
                    ["High-Roller"] = {1, 0.85, 0.2},
                    VIP = {0.9, 0.3, 0.8}
                }
                local rarity_text = upgrade_def.rarity or "Standard"
                local rarity_color = rarity_colors[rarity_text] or rarity_colors["Standard"]
                local rarity_width = cost_font:getWidth(rarity_text)
                local rarity_x = text_center_x - rarity_width / 2
                local rarity_y = icon_top_y - 31  -- moved up 5px
                love.graphics.setColor(rarity_color[1], rarity_color[2], rarity_color[3], 1)
                shop_print(rarity_text, rarity_x, rarity_y)

                -- Cost directly under rarity (still above the icon)
                local cost_text = upgrade_def.cost .. " gems"
                local cost_width = cost_font:getWidth(cost_text)
                local cost_x = text_center_x - cost_width / 2
                local cost_y = rarity_y + 12  -- increased spacing by 3px
                love.graphics.setColor(0.2, 1, 0.8, 1)  -- Cyan for cost
                shop_print(cost_text, cost_x, cost_y)
            end
        end
    end
    
    -- Store tooltip info for drawing after pop (to render on top)
    local tooltip_box_index = hovered_box
    local tooltip_box_start_x = box_start_x
    local tooltip_box_y_pos = box_y_pos
    local tooltip_box_width = box_width
    local tooltip_box_height = box_height
    local tooltip_box_gap = box_gap
    
    -- Draw NEXT ROUND button
    local button_width = 200
    local button_height = 50
    local button_x = SHOP_X + (SHOP_W - button_width) / 2
    local button_y = SHOP_Y + SHOP_H - 330  -- Moved up 250px total
    
    -- Check if button is hovered (use game-space mouse coords)
    local is_button_hovered = game_mouse_x >= button_x and game_mouse_x <= button_x + button_width and
                               game_mouse_y >= button_y and game_mouse_y <= button_y + button_height
    
    -- Button background - check if goal is met
    if current_bankroll >= next_balance_goal then
        if is_button_hovered then
            love.graphics.setColor(0.15, 0.75, 0.15, 0.8)  -- Darker green on hover
        else
            love.graphics.setColor(0.2, 1, 0.2, 0.8)  -- Green if goal met
        end
    else
        if is_button_hovered then
            love.graphics.setColor(0.3, 0.3, 0.3, 0.6)  -- Slightly darker grey on hover
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 0.6)  -- Greyed out if not
        end
    end
    love.graphics.rectangle("fill", button_x, button_y, button_width, button_height, 5, 5)
    
    -- Button border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button_x, button_y, button_width, button_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Button text
    love.graphics.setColor(1, 1, 1, 1)
    local button_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(button_font)
    local button_text = "NEXT ROUND"
    local button_text_w = button_font:getWidth(button_text)
    shop_print(button_text, button_x + (button_width - button_text_w) / 2, button_y + (button_height - button_font:getHeight()) / 2 + 15)
    
    -- Draw tooltip while slide translation is active so it lines up with icons
    -- But only if the upgrade hasn't been purchased yet
    if tooltip_box_index then
        local upgrade_id = UpgradeNode.get_box_upgrade(tooltip_box_index)
        local is_purchased = UpgradeNode.is_purchased_this_round(upgrade_id) or false
        if not is_purchased then
            Shop.draw_upgrade_tooltip(tooltip_box_index, tooltip_box_start_x, tooltip_box_y_pos, tooltip_box_width, tooltip_box_height, tooltip_box_gap)
        end
    end

    love.graphics.pop()

    -- Draw gem splashes on top of the shop UI
    Shop.draw_gem_splashes()
    -- Draw small sold-upgrade splashes on top
    Shop.draw_upgrade_splashes()
    
    -- Draw BUY button below selected upgrade if selected or while its popup is animating
    local effective_selected_id = selected_upgrade_id or last_selected_upgrade_id
    local effective_box_index = selected_upgrade_box_index or last_selected_upgrade_box_index
    if (effective_selected_id and effective_box_index) or buy_popup_state ~= "closed" then
        -- Check if the selected upgrade has already been purchased
        local is_purchased = false
        local selected_upgrades = UpgradeNode.get_selected_upgrades()
        for _, spr in ipairs(selected_upgrades) do
            if spr and spr.upgrade_id and spr.upgrade_id == effective_selected_id then
                is_purchased = true
                break
            end
        end
        
        -- Check if it's currently flying
        if not is_purchased then
            local flying_upgrades = UpgradeNode.get_flying_upgrades()
            for _, fly_upgrade in ipairs(flying_upgrades) do
                if fly_upgrade.upgrade_id == selected_upgrade_id then
                    is_purchased = true
                    break
                end
            end
        end
        
            -- Only draw BUY button if not already purchased
        if not is_purchased then
            local box_width = 200
            local box_height = 150
            local stats_y = SHOP_Y + 80
            local line_height = 30
            local box_y_pos = stats_y + line_height * 4 + 20
            local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200
            local box_gap = 20
            
            local box_x = box_start_x + (effective_box_index - 1) * (box_width + box_gap)
            local button_width = 80
            local button_height = 40
            local button_x = box_x + (box_width - button_width) / 2
            -- Compute icon position (match icon draw logic) and place BUY button just below the icon
            local center_x = box_x + box_width / 2
            local center_y = box_y_pos + box_height / 2
            local actual_icon_size = 128
            local drift_y = math.sin(love.timer.getTime() * 1.5 + effective_box_index + 1) * 6
            local icon_y = center_y - actual_icon_size / 2 + drift_y
            local button_y = icon_y + actual_icon_size + 6 + slide_offset  -- smaller gap to icon

            -- popup state is driven elsewhere; draw uses timers set by selection changes

            -- Determine affordability and style accordingly
            local cost = 0
            if effective_selected_id then
                cost = UpgradeNode.get_buy_cost(effective_selected_id)
            end
            local affordable = Shop.get_gems() >= cost

            -- Hover detection for BUY button (use game-space mouse)
            local mx, my = get_game_mouse()
            local is_hover = mx >= button_x and mx <= button_x + button_width and my >= button_y and my <= button_y + button_height

            -- No animation: immediate popup
            local slide_offset_popup = 0
            local alpha = 1
            local draw_y = button_y

            if affordable then
                if is_hover then
                    love.graphics.setColor(0.0, 0.85, 0.0, alpha)  -- Slightly darker green on hover
                else
                    love.graphics.setColor(0.0, 1.0, 0.0, alpha)
                end
            else
                if is_hover then
                    love.graphics.setColor(0.35, 0.35, 0.35, 0.7 * alpha)  -- Slightly darker grey on hover
                else
                    love.graphics.setColor(0.4, 0.4, 0.4, 0.6 * alpha)
                end
            end
            love.graphics.rectangle("fill", button_x, draw_y, button_width, button_height)

            -- Border: brighter when affordable, dimmer when not
            if affordable then
                love.graphics.setColor(1, 1, 0, 1)  -- Yellow border
            else
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
            end
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", button_x, draw_y, button_width, button_height)
            love.graphics.setLineWidth(1)

            -- Draw button text (muted when unaffordable)
            local button_font = love.graphics.newFont("splashfont.otf", 16)
            love.graphics.setFont(button_font)
            if affordable then
                if is_hover then
                    love.graphics.setColor(0.05, 0.05, 0.05, 1)
                else
                    love.graphics.setColor(0, 0, 0, 1)
                end
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
            end
            shop_printf("BUY", button_x, draw_y + 8 + 15, button_width, "center")
        end
    end

    -- Update last_selected flag for popup transitions: preserve last selection until popup fully closes
    if selected_upgrade_id and selected_upgrade_box_index then
        last_selected_upgrade_id = selected_upgrade_id
        last_selected_upgrade_box_index = selected_upgrade_box_index
    elseif buy_popup_state == "closed" then
        last_selected_upgrade_id = nil
        last_selected_upgrade_box_index = nil
    end
end

-- Draw gem splashes on top of shop UI (call after pop in draw())
function Shop.draw_gem_splashes()
    if #gem_splashes == 0 then return end
    for i, p in ipairs(gem_splashes) do
        love.graphics.push()
        if p.spent and invert_shader then
            love.graphics.setShader(invert_shader)
        end
        love.graphics.setColor(1, 1, 1, p.alpha)
        local ox, oy = 16, 16
        love.graphics.draw(ui_assets, gem_icon_quad, p.x, p.y, p.rot, p.scale, p.scale, ox, oy)
        love.graphics.setShader()
        love.graphics.pop()
    end
end

function Shop.draw_upgrade_splashes()
    if #upgrade_splashes == 0 then return end
    if not upgrade_units_image then return end
    for i = #upgrade_splashes, 1, -1 do
        local p = upgrade_splashes[i]
        local alpha = p.alpha or 1
        love.graphics.push()
        love.graphics.setColor(1,1,1,alpha)
        local quad = upgrade_units_quads and upgrade_units_quads[p.quad_index]
        if quad then
            local size = 32
            local scale = p.scale or 1
            love.graphics.draw(upgrade_units_image, quad, p.x, p.y, p.rot, scale, scale, size/2, size/2)
        end
        love.graphics.pop()
    end
end


-- Draw upgrade tooltip on hover
function Shop.draw_upgrade_tooltip(box_index, box_start_x, box_y_pos, box_width, box_height, box_gap)
    local upgrade_id = UpgradeNode.get_box_upgrade(box_index)
    if not upgrade_id then return end

    -- Reconstruct a temporary sprite-like table with the upgrade id
    local tmp_sprite = { upgrade_id = upgrade_id }

    -- Compute the drawn icon rectangle (matches draw() above)
    local center_x = box_start_x + (box_index - 1) * (box_width + box_gap) + box_width / 2
    local center_y = box_y_pos + box_height / 2
    local actual_icon_size = 128
    local icon_x = center_x - actual_icon_size / 2
    local icon_y = center_y - actual_icon_size / 2

    -- Add the same subtle drift used when drawing the icon so tooltip aligns
    local drift_x = math.sin(love.timer.getTime() * 2 + box_index) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + box_index + 1) * 6
    icon_x = icon_x + drift_x
    icon_y = icon_y + drift_y

    -- Delegate to the centralized tooltip renderer for consistent styling
    UpgradeTooltips.draw_tooltip(tmp_sprite, icon_x, icon_y, actual_icon_size, actual_icon_size)
end

-- Draw SELL button for purchased upgrades in display boxes
function Shop.draw_sell_button(selected_sell_upgrade_index, upgrade_box_positions)
    -- Allow drawing during exit animation by falling back to last_selected_sell_index
    local effective_index = selected_sell_upgrade_index or last_selected_sell_index
    if not effective_index or not upgrade_box_positions then
        return
    end
    
    -- Find the box for this upgrade
    local selected_box = nil
    for _, box in ipairs(upgrade_box_positions) do
        if box.index == effective_index then
            selected_box = box
            break
        end
    end
    
    if not selected_box then
        return
    end
    
    -- Sprite dimensions from bounding box
    local scaled_size = selected_box.width  -- Already includes scale
    
    -- Sprite center position (x, y already include wobble)
    local sprite_center_x = selected_box.x + scaled_size / 2
    local sprite_bottom_y = selected_box.y + scaled_size
    
    -- SELL button positioned below the sprite
    local button_width = 80
    local button_height = 40
    local button_x = sprite_center_x - button_width / 2
    local button_y = sprite_bottom_y + 6
    
    -- Hover detection for SELL button (convert to game-space)
    local mx, my = get_game_mouse()
    local is_hover = mx >= button_x and mx <= button_x + button_width and my >= button_y and my <= button_y + button_height
    -- popup state is controlled by main via Shop.open_sell_popup / Shop.close_sell_popup

    -- No animation: immediate sell popup
    local slide_offset_popup = 0
    local alpha = 1
    local draw_y = button_y

    if is_hover then
        love.graphics.setColor(0.85, 0.15, 0.15, alpha)
    else
        love.graphics.setColor(1.0, 0.2, 0.2, alpha)
    end
    love.graphics.rectangle("fill", button_x, draw_y, button_width, button_height)

    love.graphics.setColor(1, 1, 0, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", button_x, draw_y, button_width, button_height)
    love.graphics.setLineWidth(1)

    -- Draw button text
    local button_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(button_font)
    if is_hover then
        love.graphics.setColor(0.05, 0.05, 0.05, alpha)
    else
        love.graphics.setColor(0, 0, 0, alpha)
    end
    shop_printf("SELL", button_x, draw_y + 8 + 15, button_width, "center")

    -- Update last_selected for transitions: keep last index while animating out
    if selected_sell_upgrade_index then
        last_selected_sell_index = selected_sell_upgrade_index
    elseif sell_popup_state == "closed" then
        last_selected_sell_index = nil
    end
end

-- Draw tooltip for purchased upgrade in display boxes
function Shop.draw_display_box_tooltip(upgrade_id, upgrade_index, upgrade_box_positions)
    if not upgrade_id or not upgrade_box_positions or not upgrade_index then
        return
    end
    
    local def = UpgradeNode.get_definition(upgrade_id)
    if not def then return end
    
    -- Find the box for this upgrade
    local selected_box = nil
    for _, box in ipairs(upgrade_box_positions) do
        if box.index == upgrade_index then
            selected_box = box
            break
        end
    end
    
    if not selected_box then
        return
    end
    
    local Config = require("conf")
    local game_w, game_h = Config.GAME_WIDTH, Config.GAME_HEIGHT
    
    -- Sprite dimensions from bounding box (already includes wobble and scale)
    local scaled_size = selected_box.width
    
    -- Sprite center position
    local sprite_center_x = selected_box.x + scaled_size / 2
    local sprite_top_y = selected_box.y
    
    -- Position tooltip above the upgrade, centered
    local tooltip_width = 280
    local tooltip_height = 125
    local padding = 10
    
    local tooltip_x = sprite_center_x - tooltip_width / 2
    local tooltip_y = sprite_top_y - tooltip_height - 12
    
    -- Keep tooltip on screen before applying drift
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > game_w - 10 then
        tooltip_x = game_w - tooltip_width - 10
    end
    if tooltip_y < 20 then
        tooltip_y = sprite_top_y + scaled_size + 15
    end
    
    -- Add sinusoidal drift (same as shop tooltips)
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 0.8, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name
    love.graphics.setColor(1, 0.8, 0.2, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    shop_print(def.name, tooltip_x + padding, tooltip_y + padding)
    
    -- Draw effects as text
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    -- Draw benefit line in green
    love.graphics.setColor(0.2, 1, 0.2, 1)
    shop_print(def.benefit, tooltip_x + padding, tooltip_y + padding + 25)
    
    -- Draw downside line in magenta
    love.graphics.setColor(1, 0.2, 1, 1)
    shop_print(def.downside, tooltip_x + padding, tooltip_y + padding + 42)
    
    -- Draw flavor line in orange
    if def.flavor then
        love.graphics.setColor(1, 0.7, 0.2, 1)
        love.graphics.setFont(effects_font)
        local max_width = tooltip_width - padding * 2
        local wrapped = {}
        local words = {}
        for word in def.flavor:gmatch("%S+") do
            table.insert(words, word)
        end
        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or current_line .. " " .. word
            if effects_font:getWidth(test_line) > max_width then
                table.insert(wrapped, current_line)
                current_line = word
            else
                current_line = test_line
            end
        end
        if current_line ~= "" then
            table.insert(wrapped, current_line)
        end
        
        for i, line in ipairs(wrapped) do
            shop_print(line, tooltip_x + padding, tooltip_y + padding + 59 + (i - 1) * 14)
        end
    end
end

-- Check if BUY button was clicked

-- Draw tooltip for any sprite (shop or display)
function Shop.draw_sprite_tooltip(sprite, sprite_x, sprite_y, sprite_width, sprite_height)
    if not sprite then return end
    
    local upgrade_id = sprite.upgrade_id
    local def = UpgradeNode.get_definition(upgrade_id)
    if not def then return end
    
    local Config = require("conf")
    local game_w, game_h = Config.GAME_WIDTH, Config.GAME_HEIGHT
    
    -- Sprite center position
    local sprite_center_x = sprite_x + sprite_width / 2
    local sprite_top_y = sprite_y
    
    -- Position tooltip above the sprite, centered
    local tooltip_width = 280
    local tooltip_height = 125
    local padding = 10
    
    local tooltip_x = sprite_center_x - tooltip_width / 2
    local tooltip_y = sprite_top_y - tooltip_height - 12
    
    -- Keep tooltip on screen before applying drift
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > game_w - 10 then
        tooltip_x = game_w - tooltip_width - 10
    end
    if tooltip_y < 20 then
        tooltip_y = sprite_top_y + sprite_height + 15
    end
    
    -- Add sinusoidal drift
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 0.8, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name
    love.graphics.setColor(1, 0.8, 0.2, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    shop_print(def.name, tooltip_x + padding, tooltip_y + padding)

    -- Draw effects as text
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)

    -- Draw benefit line in green
    love.graphics.setColor(0.2, 1, 0.2, 1)
    shop_print(def.benefit, tooltip_x + padding, tooltip_y + padding + 25)

    -- Draw downside line in magenta
    love.graphics.setColor(1, 0.2, 1, 1)
    shop_print(def.downside, tooltip_x + padding, tooltip_y + padding + 42)

    -- Draw flavor line in orange
    if def.flavor then
        love.graphics.setColor(1, 0.7, 0.2, 1)
        love.graphics.setFont(effects_font)
        local max_width = tooltip_width - padding * 2
        local wrapped = {}
        local words = {}
        for word in def.flavor:gmatch("%S+") do
            table.insert(words, word)
        end
        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or current_line .. " " .. word
            if effects_font:getWidth(test_line) > max_width then
                table.insert(wrapped, current_line)
                current_line = word
            else
                current_line = test_line
            end
        end
        if current_line ~= "" then
            table.insert(wrapped, current_line)
        end
        for i, line in ipairs(wrapped) do
            shop_print(line, tooltip_x + padding, tooltip_y + padding + 57 + (i - 1) * 15)
        end
    end
end

function Shop.check_popup_button_click(x, y, selected_upgrade_id, selected_upgrade_box_index, slide_offset)
    if not selected_upgrade_id or not selected_upgrade_box_index then
        return nil
    end
    
    local box_width = 200
    local box_height = 150
    local stats_y = SHOP_Y + 80
    local line_height = 30
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200
    local box_gap = 20
    
    local box_x = box_start_x + (selected_upgrade_box_index - 1) * (box_width + box_gap)
    local button_width = 80
    local button_height = 40
    local button_x = box_x + (box_width - button_width) / 2
    -- Compute button_y using the same icon positioning math as Shop.draw so hitbox matches visuals
    local center_y = box_y_pos + box_height / 2
    local actual_icon_size = 128
    local drift_y = math.sin(love.timer.getTime() * 1.5 + selected_upgrade_box_index + 1) * 6
    local float_offset = 0
    -- If there is an actively selected upgrade, apply the same float offset used when rendering
    if selected_upgrade_id then
        float_offset = math.sin(love.timer.getTime() * 3) * 5 - 10
    end
    local icon_y = center_y - actual_icon_size / 2 + drift_y + float_offset
    local button_y = icon_y + actual_icon_size + 6 + slide_offset
    
    if x >= button_x and x <= button_x + button_width and
       y >= button_y and y <= button_y + button_height then
        return "buy"
    end
    
    return nil
end

-- Check if click is in the shop upgrade boxes area
function Shop.is_click_in_shop_boxes(x, y)
    local box_width = 200
    local box_height = 150
    local stats_y = SHOP_Y + 80
    local line_height = 30
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200
    local box_gap = 20
    
    local total_box_width = (box_width * 3) + (box_gap * 2)
    
    -- Check if click is in the shop boxes area
    if x >= box_start_x and x <= box_start_x + total_box_width and
       y >= box_y_pos and y <= box_y_pos + box_height then
        return true
    end
    return false
end

-- ============================================================================
-- STANDARDIZED UPGRADE HOVER AND BOUNDING BOX CALCULATIONS
-- ============================================================================
-- This ensures consistent tooltip behavior across all upgrade items

-- Calculate wobble effect for an upgrade at a given time
-- Wobble is deterministic based on upgrade_id to ensure consistency
function Shop.calculate_upgrade_wobble(upgrade_id)
    local time = love.timer.getTime()
    local seed = upgrade_id * 0.7
    local wobble_x = math.sin(time * Config.DRIFT_SPEED + seed) * Config.DRIFT_RANGE
    local wobble_y = math.cos(time * Config.DRIFT_SPEED * 0.8 + seed * 1.5) * Config.DRIFT_RANGE
    return wobble_x, wobble_y
end

-- DEPRECATED: get_upgrade_bounding_box is no longer needed
-- The bounding box data is now stored directly in upgrade_box_positions
-- This function is kept for reference but should not be called

-- Check which purchased upgrade the mouse is hovering over
-- Returns the upgrade index if hovering, nil otherwise
function Shop.check_display_box_hover(x, y, upgrade_box_positions)
    if not upgrade_box_positions then
        return nil
    end
    
    if #upgrade_box_positions == 0 then
        return nil
    end
    
    local hovered_box = nil
    local UpgradeSprite = require("systems.upgrade_sprite")
    
    for _, box in ipairs(upgrade_box_positions) do
        -- Verify box has required fields (new sprite-based format)
        if not box.x or not box.y or not box.width or not box.height or not box.upgrade_id then
            goto continue
        end
        
        -- SKIP sprites that are currently animating (purchasing or shifting)
        -- Tooltips and hover should NOT be available during animations
        if box.sprite and (box.sprite.state == "purchasing" or box.sprite.state == "shifting") then
            goto continue
        end
        
        -- Check if hover is within the sprite's bounding box
        if x >= box.x and x < box.x + box.width and
           y >= box.y and y < box.y + box.height then
            -- Mark this as the hovered box
            hovered_box = {index = box.index, upgrade_id = box.upgrade_id, sprite = box.sprite}
        end
        
        ::continue::
    end
    
    -- Now update all sprites' hover states
    for _, box in ipairs(upgrade_box_positions) do
        if box.sprite then
            -- Don't set hover on animating sprites
            if box.sprite.state == "purchasing" or box.sprite.state == "shifting" then
                UpgradeSprite.set_hovered(box.sprite, false)
            else
                local is_hovered = (hovered_box and hovered_box.sprite == box.sprite)
                UpgradeSprite.set_hovered(box.sprite, is_hovered)
            end
        end
    end
    
    if hovered_box then
        return hovered_box.index, hovered_box.upgrade_id
    end
    return nil
end

-- Check if a display box (purchased upgrade) was clicked
-- Returns the upgrade index (1-based) if clicked, nil otherwise
function Shop.check_display_box_click(x, y, upgrade_box_positions)
    if not upgrade_box_positions then
        return nil
    end
    
    for _, box in ipairs(upgrade_box_positions) do
        -- Verify box has required fields (new sprite-based format)
        if not box.x or not box.y or not box.width or not box.height or not box.upgrade_id then
            goto continue
        end
        
        -- SKIP sprites that are currently animating - can't click/interact with mid-flight upgrades
        if box.sprite and (box.sprite.state == "purchasing" or box.sprite.state == "shifting") then
            goto continue
        end
        
        -- Check if click is within the sprite's bounding box
        if x >= box.x and x <= box.x + box.width and
           y >= box.y and y <= box.y + box.height then
            return box.index, box.upgrade_id
        end
        
        ::continue::
    end
    
    return nil
end

-- Check if SELL button was clicked (for purchased upgrades)
-- Returns "sell" if clicked, nil otherwise
-- Check if SELL button was clicked (for purchased upgrades)
-- Returns "sell" if clicked, nil otherwise
function Shop.check_sell_button_click(x, y, selected_sell_upgrade_index, upgrade_box_positions)
    if not selected_sell_upgrade_index or not upgrade_box_positions then
        return nil
    end
    
    -- Find the box for this upgrade
    local selected_box = nil
    for _, box in ipairs(upgrade_box_positions) do
        if box.index == selected_sell_upgrade_index then
            selected_box = box
            break
        end
    end
    
    if not selected_box then
        return nil
    end
    
    -- Sprite dimensions from bounding box (already includes wobble and scale)
    local scaled_size = selected_box.width
    
    -- Sprite center position (x, y already include wobble)
    local sprite_center_x = selected_box.x + scaled_size / 2
    local sprite_bottom_y = selected_box.y + scaled_size
    
    -- SELL button positioned below the sprite
    local button_width = 80
    local button_height = 40
    local button_x = sprite_center_x - button_width / 2
    local button_y = sprite_bottom_y + 10
    
    -- Check if click is within SELL button bounds
    if x >= button_x and x <= button_x + button_width and
       y >= button_y and y <= button_y + button_height then
        return "sell"
    end
    
    return nil
end

return Shop
