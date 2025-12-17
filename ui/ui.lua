-- ui.lua
-- Consolidated UI drawing system
-- Organizes all UI elements: buttons, indicators, display boxes, and overlays

local Config = require("conf")
local UIConfig = require("ui.ui_config")
local SlotMachine = require("game_mechanics.slot_machine")
local Shop = require("ui.shop")
local UpgradeNode = require("systems.upgrade_node")

local UI = {}

-- UI Assets
local ui_assets_spritesheet = nil
local ui_assets_quads = {}  -- Store quads for 4x4 grid

-- Greyscale and blur shader for display boxes
local greyscale_shader = nil
local display_box_canvas = nil

local function load_greyscale_shader()
    if not greyscale_shader then
        local ok, shader = pcall(love.graphics.newShader, "shaders/greyscale_shader.glsl")
        if ok then
            greyscale_shader = shader
        else
            print("Warning: failed to load greyscale shader: " .. tostring(shader))
            greyscale_shader = nil
        end
    end
end

local function get_display_box_canvas(width, height)
    if not display_box_canvas or display_box_canvas:getWidth() ~= width or display_box_canvas:getHeight() ~= height then
        display_box_canvas = love.graphics.newCanvas(width, height)
    end
    return display_box_canvas
end

-- Load UI assets on initialization
local function load_ui_assets()
    local ok, img = pcall(love.graphics.newImage, "assets/UI_assets.png")
    if ok then
        ui_assets_spritesheet = img
        -- Set filter to nearest for pixel-perfect rendering
        ui_assets_spritesheet:setFilter("nearest", "nearest")
        -- Create quads for 4x4 grid (128x128 px / 4 = 32x32 px per sprite)
        local sprite_size = 32
        local cols = 4
        local rows = 4
        for row = 0, rows - 1 do
            for col = 0, cols - 1 do
                local quad_index = row * cols + col + 1
                ui_assets_quads[quad_index] = love.graphics.newQuad(col * sprite_size, row * sprite_size, sprite_size, sprite_size, img:getDimensions())
            end
        end
    else
        print("Warning: Could not load UI_assets.png")
    end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Store upgrade box positions for click detection and dragging
local upgrade_box_positions = {}  -- Table of {x, y, size, index}

function UI.get_upgrade_box_at_position(x, y)
    for _, box in ipairs(upgrade_box_positions) do
        if x >= box.x and x <= box.x + box.size and
           y >= box.y and y <= box.y + box.size then
            return box.index
        end
    end
    return nil
end

local function format_large_number(num)
    -- Format numbers in scientific notation if they exceed 99,999,999 or go below -99,999,999
    if num > 99999999 or num < -99999999 then
        return string.format("%.2e", num)
    else
        return string.format("%.0f", num)
    end
end

-- ============================================================================
-- TOKEN ANIMATION STATE
-- ============================================================================

local departing_tokens = {}  -- Table to track tokens leaving the screen
local arriving_tokens = {}  -- Table to track tokens arriving on screen
local prev_spins_remaining = 0
local token_oscillation_time = 0  -- Time accumulator for oscillation animation
local last_token_x = 0  -- Store position of last token for departing animation
local last_token_y = 0  -- Store position of last token for departing animation
local gauge_display_progress = 0  -- Twitchy gauge needle position
local gauge_twitch_timer = 0  -- Timer for gauge twitches
local sprite_animation_time = 0  -- Time accumulator for sprite grow/shrink animation

-- ============================================================================
-- INDICATOR BOXES (BET, SPIN MULTIPLIER, STREAK MULTIPLIER)
-- ============================================================================

local function draw_multiplier_box(state, box_y, value, label, value_color, draw_wavy_text, get_wiggle_modifiers)
    local bx = Config.MULTIPLIER_BOX_START_X
    local by = box_y
    local bw = Config.MULTIPLIER_BOX_WIDTH
    local bh = Config.MULTIPLIER_BOX_HEIGHT
    
    -- Draw Box
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", bx, by, bw, bh, UIConfig.MULTIPLIER_BOX_CORNER_RADIUS)
    love.graphics.setLineWidth(UIConfig.BUTTON_LINE_WIDTH_DEFAULT)

    -- Label (Info Font, top of the box) - with wiggle effect
    love.graphics.setFont(state.info_font)
    local label_tw = state.info_font:getWidth(label)
    local label_x = bx + (bw - label_tw) / 2
    
    love.graphics.setColor(UIConfig.MULTIPLIER_LABEL_COLOR)
    draw_wavy_text(label, label_x, by + UIConfig.MULTIPLIER_BOX_LABEL_OFFSET_Y, state.info_font, UIConfig.MULTIPLIER_LABEL_COLOR, 200, 1.0, get_wiggle_modifiers)
    
    -- Value (Symbol Font, centered in box) - with wiggle effect
    love.graphics.setFont(state.symbol_font)
    local value_str = string.format(UIConfig.MULTIPLIER_BOX_VALUE_FORMAT, value)
    local value_tw = state.symbol_font:getWidth(value_str)
    local value_x = bx + (bw - value_tw) / 2
    local value_y = by + bh / 2 - state.symbol_font:getHeight() / 2 + 7
    
    love.graphics.setColor(value_color)
    draw_wavy_text(value_str, value_x, value_y, state.symbol_font, value_color, 250, 1.0, get_wiggle_modifiers)
end

function UI.drawIndicatorBoxes(state, Slots, draw_wavy_text, get_wiggle_modifiers)
    -- Streak Multiplier Box
    local Keepsakes = require("systems.keepsakes")
    local base_streak_mult = (state.consecutive_wins > 0) and (UIConfig.STREAK_MULTIPLIER_BASE + state.consecutive_wins * UIConfig.STREAK_MULTIPLIER_INCREMENT) or UIConfig.STREAK_MULTIPLIER_BASE
    local streak_mult = base_streak_mult * Keepsakes.get_effect("streak_multiplier")
    draw_multiplier_box(state, Config.MULTIPLIER_STREAK_Y, streak_mult, 
                        "STREAK BONUS", UIConfig.STREAK_BONUS_COLOR, draw_wavy_text, get_wiggle_modifiers)
    
    -- Spin Multiplier Box
    local spin_mult = state.current_spin_multiplier or 1.0
    draw_multiplier_box(state, Config.MULTIPLIER_SPIN_Y, spin_mult, 
                        "SPIN BONUS", UIConfig.SPIN_MULTIPLIER_COLOR, draw_wavy_text, get_wiggle_modifiers)
    
    -- Bet Indicator Boxes
    local current_flat_bet = Slots.getFlatBetBase()
    local current_pct = Slots.getBetPercent()
    
    local button_font = love.graphics.getFont()
    
    -- 1. PERCENTAGE CALCULATION DISPLAY (FLAT + % OF BALANCE)
    local pb_x = Config.INDICATOR_BOX_START_X
    local pb_y = Config.PERCENT_BOX_Y
    local flat_str = string.format("$%.0f", current_flat_bet)
    local pct_str = string.format("%.1f%%", current_pct * 100)
    
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", pb_x, pb_y, Config.INDICATOR_BOX_WIDTH, Config.INDICATOR_BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    
    love.graphics.setColor(UIConfig.PERCENT_BOX_LABEL_COLOR)
    local tw1 = button_font:getWidth(flat_str)
    local tw2 = button_font:getWidth(pct_str)
    local th = button_font:getHeight()
    local line_spacing = 5
    local total_height = th * 2 + line_spacing
    local start_y = pb_y + (Config.INDICATOR_BOX_HEIGHT - total_height) / 2 - 2
    draw_wavy_text(flat_str, pb_x + (Config.INDICATOR_BOX_WIDTH - tw1) / 2, start_y, button_font, UIConfig.PERCENT_BOX_LABEL_COLOR, 220, 1.0, get_wiggle_modifiers)
    draw_wavy_text(pct_str, pb_x + (Config.INDICATOR_BOX_WIDTH - tw2) / 2, start_y + th + line_spacing, button_font, UIConfig.PERCENT_BOX_LABEL_COLOR, 230, 1.0, get_wiggle_modifiers)

    -- 2. TOTAL BET DISPLAY BOX 
    local tb_x = Config.INDICATOR_BOX_START_X
    local tb_y = Config.TOTAL_BET_BOX_Y
    local bet_label = "BET="
    local bet_amount = string.format("$%.0f", Slots.getCurrentBet())
    
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", tb_x, tb_y, Config.INDICATOR_BOX_WIDTH, Config.INDICATOR_BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    
    love.graphics.setColor(UIConfig.TOTAL_BET_LABEL_COLOR)
    local tw_label = button_font:getWidth(bet_label)
    local tw_amount = button_font:getWidth(bet_amount)
    th = button_font:getHeight()
    local line_spacing_bet = 5
    local total_height_bet = th * 2 + line_spacing_bet
    local start_y_bet = tb_y + (Config.INDICATOR_BOX_HEIGHT - total_height_bet) / 2 - 2
    draw_wavy_text(bet_label, tb_x + (Config.INDICATOR_BOX_WIDTH - tw_label) / 2, start_y_bet, button_font, UIConfig.TOTAL_BET_LABEL_COLOR, 240, 1.0, get_wiggle_modifiers)
    draw_wavy_text(bet_amount, tb_x + (Config.INDICATOR_BOX_WIDTH - tw_amount) / 2, start_y_bet + th + line_spacing_bet, button_font, UIConfig.TOTAL_BET_LABEL_COLOR, 245, 1.0, get_wiggle_modifiers)
end

-- ============================================================================
-- BET CONTROL BUTTONS
-- ============================================================================

function UI.drawButtons(state, Slots, active_button_index, draw_wavy_text, get_wiggle_modifiers)
    -- Buttons removed - gem counter now in their place
end

-- ============================================================================
-- DISPLAY BOXES (Above Slots and Bottom Overlays)
-- ============================================================================

function UI.drawUpgradesLayer()
    -- Draw selected upgrades and flying animations as a foremost layer
    -- This function should be called AFTER all game content
    -- NOTE: This is called INSIDE the push/pop scale/translate, so coordinates are already in game space
    
    -- Display box constants
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    
    local start_x = Config.PADDING_X + 30
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    
    -- Draw one continuous box spanning all 5 display box positions
    local total_width = (BOX_WIDTH * UIConfig.DISPLAY_BOX_COUNT) + (BOX_GAP * (UIConfig.DISPLAY_BOX_COUNT - 1))
    
    -- Draw MAX upgrades counter in left corner
    local selected_upgrades = UpgradeNode.get_selected_upgrades()
    local max_upgrades = UpgradeNode.get_max_selected_upgrades()
    love.graphics.setColor(1, 1, 0, 1)
    local counter_font = love.graphics.newFont("splashfont.otf", 14)
    love.graphics.setFont(counter_font)
    local counter_text = #selected_upgrades .. "/" .. max_upgrades
    love.graphics.print(counter_text, start_x + 8, box_y + 6)
    
    -- Clear upgrade box positions
    upgrade_box_positions = {}
    
    -- Display box dimensions for position calculation
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    local start_x_box = Config.PADDING_X + 30
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local total_width = (BOX_WIDTH * UIConfig.DISPLAY_BOX_COUNT) + (BOX_GAP * (UIConfig.DISPLAY_BOX_COUNT - 1))
    local usable_width = total_width - 20
    local spacing_x = usable_width / (5 + 1)
    local center_y = box_y + BOX_HEIGHT / 2
    local flying_sprite_size = 128
    
    -- NOTE: Upgrades are now drawn as flying sprites only - they stay at 128x128 size after landing
    
    -- Draw flying upgrade animations (and landed upgrades at 128x128 size)
    local flying_upgrades = UpgradeNode.get_flying_upgrades()
    local selected_upgrades = UpgradeNode.get_selected_upgrades()
    
    -- Store positions for ALL selected upgrades (flying and landed)
    -- This ensures hover detection works even after animations complete
    for upgrade_index, upgrade_id in ipairs(selected_upgrades) do
        local final_x = start_x_box + 10 + spacing_x * upgrade_index
        local final_y = center_y - flying_sprite_size / 2
        
        -- Store base position for this upgrade (will be used for non-animating upgrades)
        table.insert(upgrade_box_positions, {
            base_x = final_x,
            base_y = final_y,
            wobble_x = 0,
            wobble_y = 0,
            upgrade_id = upgrade_id,
            index = upgrade_index,
            display_scale = 4
        })
    end
    
    if #flying_upgrades > 0 then
        local upgrade_units_image = love.graphics.newImage("assets/upgrade_units_UI.png")
        upgrade_units_image:setFilter("nearest", "nearest")
        
        local shift_animations = UpgradeNode.get_shift_animations()
        
        for idx, fly_upgrade in ipairs(flying_upgrades) do
            -- Find this upgrade's current index in selected_upgrades
            local upgrade_index = nil
            for i, upgrade_id in ipairs(selected_upgrades) do
                if upgrade_id == fly_upgrade.upgrade_id then
                    upgrade_index = i
                    break
                end
            end
            
            if upgrade_index then
                -- Calculate final position in display box based on current index
                local final_x = start_x_box + 10 + spacing_x * upgrade_index
                local final_y = center_y - flying_sprite_size / 2
                
                -- Apply shift animation offset if this upgrade is shifting
                local animated_x = final_x
                for _, shift in ipairs(shift_animations) do
                    if shift.upgrade_index == upgrade_index then
                        local progress = shift.elapsed / shift.duration
                        local eased = 1 - (1 - progress) ^ 3
                        local from_x = start_x_box + 10 + spacing_x * shift.from_index
                        local to_x = start_x_box + 10 + spacing_x * shift.to_index
                        animated_x = from_x + (to_x - from_x) * eased
                        break
                    end
                end
                
                local progress = math.min(fly_upgrade.elapsed / fly_upgrade.duration, 1.0)
                local eased = 1 - (1 - progress) ^ 3
                
                -- Interpolate from start to animated final position
                local current_x = fly_upgrade.start_x + (animated_x - fly_upgrade.start_x) * eased
                local current_y = fly_upgrade.start_y + (final_y - fly_upgrade.start_y) * eased
                
                -- Get upgrade icon (32x32 source size)
                local icon_size = 32
                local cols = 5
                local upgrade_id = fly_upgrade.upgrade_id
                local col = ((upgrade_id - 1) % cols)
                local row = math.floor((upgrade_id - 1) / cols)
                local quad = love.graphics.newQuad(col * icon_size, row * icon_size, icon_size, icon_size, upgrade_units_image:getDimensions())
                
                -- Add wobble effect
                local Shop = require("ui.shop")
                local wobble_x, wobble_y = Shop.calculate_upgrade_wobble(upgrade_id)
                
                -- Draw flying icon at 128x128 size with wobble
                love.graphics.setColor(1, 1, 1, 1)
                local display_scale = 4
                love.graphics.draw(upgrade_units_image, quad, current_x + wobble_x, current_y + wobble_y, 0, display_scale, display_scale)
                
                -- Update position for this upgrade with animated values
                -- Find the entry we pre-created and update it with animation data
                for i, pos in ipairs(upgrade_box_positions) do
                    if pos.index == upgrade_index then
                        upgrade_box_positions[i] = {
                            base_x = current_x,
                            base_y = current_y,
                            wobble_x = wobble_x,
                            wobble_y = wobble_y,
                            upgrade_id = upgrade_id,
                            index = upgrade_index,
                            display_scale = display_scale
                        }
                        break
                    end
                end
            end
        end
    end
    
    -- Draw non-flying (landed) upgrades at their final positions with wobble
    -- This ensures all upgrades are visible and have position data for hover/click detection
    if #selected_upgrades > 0 then
        -- Check which upgrades are already flying
        local flying_ids = {}
        for _, fly in ipairs(flying_upgrades) do
            flying_ids[fly.upgrade_id] = true
        end
        
        -- Draw non-flying upgrades
        local upgrade_units_image = love.graphics.newImage("assets/upgrade_units_UI.png")
        upgrade_units_image:setFilter("nearest", "nearest")
        
        for upgrade_index, upgrade_id in ipairs(selected_upgrades) do
            -- Skip if this upgrade is already being drawn by flying animation
            if not flying_ids[upgrade_id] then
                -- Calculate final position in display box
                local final_x = start_x_box + 10 + spacing_x * upgrade_index
                local final_y = center_y - flying_sprite_size / 2
                
                -- Get upgrade icon (32x32 source size)
                local icon_size = 32
                local cols = 5
                local col = ((upgrade_id - 1) % cols)
                local row = math.floor((upgrade_id - 1) / cols)
                local quad = love.graphics.newQuad(col * icon_size, row * icon_size, icon_size, icon_size, upgrade_units_image:getDimensions())
                
                -- Add wobble effect
                local Shop = require("ui.shop")
                local wobble_x, wobble_y = Shop.calculate_upgrade_wobble(upgrade_id)
                
                -- Draw icon at 128x128 size with wobble
                love.graphics.setColor(1, 1, 1, 1)
                local display_scale = 4
                love.graphics.draw(upgrade_units_image, quad, final_x + wobble_x, final_y + wobble_y, 0, display_scale, display_scale)
                
                -- Update position for this upgrade with current wobble values
                -- Find the entry we pre-created and update it
                for i, pos in ipairs(upgrade_box_positions) do
                    if pos.index == upgrade_index then
                        upgrade_box_positions[i] = {
                            base_x = final_x,
                            base_y = final_y,
                            wobble_x = wobble_x,
                            wobble_y = wobble_y,
                            upgrade_id = upgrade_id,
                            index = upgrade_index,
                            display_scale = display_scale
                        }
                        break
                    end
                end
            end
        end
    end
end

function UI.drawDisplayBoxes(state)
    -- Display box constants
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    
    local start_x = Config.PADDING_X + 30
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    
    -- Draw one continuous box spanning all 5 display box positions
    local total_width = (BOX_WIDTH * UIConfig.DISPLAY_BOX_COUNT) + (BOX_GAP * (UIConfig.DISPLAY_BOX_COUNT - 1))
    
    -- Draw transparent display box border (background will show through with greyscale effect from background renderer)
    love.graphics.setColor(UIConfig.DISPLAY_BOX_COLOR)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", start_x, box_y, total_width, BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    
    -- Draw luckykeepsake box
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = box_y
    
    love.graphics.setColor(0, 0, 0, 0)  -- Fully transparent
    love.graphics.rectangle("fill", lucky_x, lucky_y, UIConfig.LUCKY_BOX_WIDTH, UIConfig.LUCKY_BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    
    -- Draw keepsake texture or name in lucky box
    local Keepsakes = require("systems.keepsakes")
    local keepsake_id = Keepsakes.get()
    
    if keepsake_id then
        local quad = Keepsakes.get_texture(keepsake_id)
        if quad then
            -- Draw quad from spritesheet (32x32 source size)
            local texture_size = UIConfig.LUCKY_BOX_HEIGHT - 10
            local scale = texture_size / 32  -- 32x32 is source size
            local scaled_size = 32 * scale
            local texture_x = lucky_x + (UIConfig.LUCKY_BOX_WIDTH - scaled_size) / 2
            local texture_y = lucky_y + 5
            
            -- Add drift effect
            local time = love.timer.getTime()
            local seed = keepsake_id * 0.5
            local dx = math.sin(time * Config.DRIFT_SPEED + seed) * Config.DRIFT_RANGE
            local dy = math.cos(time * Config.DRIFT_SPEED * 0.8 + seed * 1.5) * Config.DRIFT_RANGE
            
            love.graphics.setColor(1, 1, 1, 1)
            -- Get spritesheet from keepsakes module
            local spritesheet = Keepsakes.get_spritesheet()
            if spritesheet then
                love.graphics.draw(spritesheet, quad, texture_x + dx, texture_y + dy, 0, scale, scale)
            end
        else
            -- Fallback to text if texture unavailable
            local keepsake_name = Keepsakes.get_name()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(love.graphics.getFont())
            local name_w = love.graphics.getFont():getWidth(keepsake_name)
            local box_center_x = lucky_x + UIConfig.LUCKY_BOX_WIDTH / 2
            local box_center_y = lucky_y + UIConfig.LUCKY_BOX_HEIGHT / 2
            love.graphics.print(keepsake_name, box_center_x - name_w / 2, box_center_y - 8)
        end
    end
end


function UI.drawBottomOverlays(state)
    -- Load UI assets if not already loaded
    if not ui_assets_spritesheet then
        load_ui_assets()
    end
    
    -- Two opaque black boxes at the bottom
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    local start_x = Config.PADDING_X + 30
    
    local slot_bottom = Config.SLOT_Y + 150 + 20 + 245
    local left_box_x = start_x
    local bottom_box_width = (BOX_WIDTH * 5) + (BOX_GAP * 4)
    
    -- Calculate BAL box bottom to match
    local bal_box_height = 2 * 24 + 5 + 1  -- approximate based on symbol font and spacing
    local bal_box_bottom = slot_bottom + bal_box_height
    local box_height = bal_box_bottom - slot_bottom + 15
    
    if box_height > 0 then
        -- Left box (spin chips display)
        local left_box_width = bottom_box_width / 2 - UIConfig.BOTTOM_BOX_GAP - UIConfig.BOTTOM_BOX_LEFT_OFFSET
        local left_box_x_pos = left_box_x + UIConfig.BOTTOM_BOX_LEFT_OFFSET
        love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
        love.graphics.rectangle("fill", left_box_x_pos, slot_bottom, left_box_width, box_height, UIConfig.BOX_CORNER_RADIUS)
        
        -- ================================================================
        -- SPIN CHIPS FEATURE: Display remaining spins as a horizontal line
        -- ================================================================
        if ui_assets_spritesheet and ui_assets_quads[5] then
            love.graphics.setColor(1, 1, 1, 1)
            local spins_remaining = Shop.get_spins_remaining()
            local base_token_size = 32  -- Original sprite size
            local scale = 2  -- 2x scale for bigger tokens
            local token_size = base_token_size * scale  -- 64 pixels when drawn
            local chip_spacing = -52  -- Tight packing with significant overlap
            local padding_top = (box_height - token_size) / 2  -- Vertically center
            
            -- Calculate position of first chip (left-aligned with padding, moved left 10px)
            local chip_x = left_box_x_pos  -- Moved left 10px (was +10)
            local chip_y = slot_bottom + padding_top
            
            -- Track last token position for departing animation (store globally for update function)
            last_token_x = chip_x
            last_token_y = chip_y
            
            -- Draw chips in a single horizontal line
            for i = 1, spins_remaining do
                -- Skip chips that are currently arriving (they're drawn separately)
                local is_arriving = false
                for _, arriving_token in ipairs(arriving_tokens) do
                    if arriving_token.slot_index == i then
                        is_arriving = true
                        break
                    end
                end
                
                if not is_arriving then
                    local current_chip_x = chip_x + (i - 1) * (token_size + chip_spacing)
                    local current_chip_y = chip_y
                    
                    -- Apply individual oscillation animation to each chip with phase offset
                    local phase_offset = i * 0.2  -- Each chip has a different phase offset
                    local oscillation = math.sin(token_oscillation_time * 4 + phase_offset) * 2  -- Oscillates 2 pixels up and down (tighter)
                    current_chip_y = current_chip_y + oscillation
                    
                    love.graphics.draw(ui_assets_spritesheet, ui_assets_quads[5], current_chip_x, current_chip_y, 0, scale, scale)
                    
                    -- Update last token position (for animation starting point)
                    last_token_x = current_chip_x
                    last_token_y = current_chip_y
                end
            end
            
            -- Draw departing tokens with animation
            for _, token in ipairs(departing_tokens) do
                -- Draw token (no fade, it just falls off screen)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(ui_assets_spritesheet, ui_assets_quads[5], token.x - 32, token.y - 32, 0, scale, scale)
            end
            
            -- Draw arriving tokens with animation
            for _, token in ipairs(arriving_tokens) do
                local adjusted_lifetime = math.max(0, token.lifetime - token.delay)
                if adjusted_lifetime > 0 then
                    local progress = adjusted_lifetime / token.max_lifetime
                    local arrival_x = chip_x + (token.slot_index - 1) * (token_size + chip_spacing)
                    local arrival_y = chip_y
                    
                    -- Animate from bottom up to final position
                    local start_y = arrival_y + 150  -- Start 150 pixels below
                    local current_y = start_y - (progress * 150)  -- Slide up
                    local alpha = math.min(progress * 2, 1)  -- Fade in quickly
                    
                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.draw(ui_assets_spritesheet, ui_assets_quads[5], arrival_x, current_y, 0, scale, scale)
                end
            end
        end
        
        -- Right box (balance goal progress gauge)
        local right_box_x = left_box_x + bottom_box_width / 2 + UIConfig.BOTTOM_BOX_GAP
        local right_box_width = bottom_box_width / 2 - UIConfig.BOTTOM_BOX_GAP
        love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
        love.graphics.rectangle("fill", right_box_x, slot_bottom, right_box_width, box_height, UIConfig.BOX_CORNER_RADIUS)
        
        -- Draw balance goal progress gauge (thermometer style, horizontal)
        local current_balance = state.bankroll or 0
        local goal_balance = Shop.get_balance_goal()
        local actual_progress = math.min(1.0, current_balance / goal_balance)
        
        -- Thermometer dimensions (horizontal without bulb, 50px smaller from right)
        local thermo_padding = 15
        local thermo_x = right_box_x + thermo_padding
        local thermo_y = slot_bottom + box_height / 2 - 18
        local thermo_width = right_box_width - (thermo_padding * 2) - 50  -- 50px smaller from right
        local thermo_height = 36
        local tube_x = thermo_x
        local tube_width = thermo_width
        
        -- Background (empty thermometer tube)
        love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
        love.graphics.rectangle("fill", tube_x, thermo_y, tube_width, thermo_height, 5)
        
        -- Needle position with twitchiness and sporadic jumps
        local needle_x = tube_x + (tube_width * gauge_display_progress)
        local needle_height = thermo_height + 10
        
        -- Draw colored fill behind needle (red to blue)
        local color_r = 1.0 - (gauge_display_progress * 0.8)
        local color_g = 0.0
        local color_b = gauge_display_progress * 0.8
        love.graphics.setColor(color_r, color_g, color_b, 0.6)
        love.graphics.rectangle("fill", tube_x, thermo_y, tube_width * gauge_display_progress, thermo_height, 5)
        
        -- Draw lightning effect from left edge to needle (multiple rows)
        local time = love.timer.getTime() * 8.0
        local p1_x = tube_x
        local p2_x = needle_x
        
        -- Draw three rows of lightning: above, center, below
        local lightning_rows = {
            {y_offset = -8, amplitude = 0.15},   -- Above (smaller amplitude)
            {y_offset = -5, amplitude = 0.25},   -- Center (original)
            {y_offset = 3, amplitude = 0.15}     -- Below (smaller amplitude)
        }
        
        for _, row in ipairs(lightning_rows) do
            local p1_y = thermo_y + thermo_height / 2 + row.y_offset
            local p2_y = thermo_y + thermo_height / 2 + row.y_offset
            
            local dx = p2_x - p1_x
            local dy = p2_y - p1_y
            local len = math.sqrt(dx*dx + dy*dy)
            
            if len > 1 then
                local points = {}
                table.insert(points, p1_x)
                table.insert(points, p1_y)
                
                local nx = -dy / len
                local ny = dx / len
                
                local num_bolt_segments = 20
                for i = 1, num_bolt_segments do
                    local t = i / num_bolt_segments
                    local current_x = p1_x + dx * t
                    local current_y = p1_y + dy * t
                    local jitter = (math.sin(time + i * 2.0) + love.math.random() * 2.0) * (thermo_height * row.amplitude) * 0.5
                    current_x = current_x + nx * jitter
                    current_y = current_y + ny * jitter
                    table.insert(points, current_x)
                    table.insert(points, current_y)
                end
                
                -- Draw multiple lightning arcs for intense effect with color based on gauge progress
                for arc = 1, 10 do
                    local arc_width = 4 - arc * 0.6
                    local alpha = (0.8 + love.math.random() * 0.2) / (arc * 0.5)
                    
                    love.graphics.setLineWidth(arc_width)
                    
                    -- Color shifts from yellow to cyan based on gauge progress
                    local gauge_progress = gauge_display_progress  -- 0 to 1
                    local r = 1.0 * (1.0 - gauge_progress)  -- Yellow to no red
                    local g = 1.0  -- Always full green
                    local b = 1.0 * gauge_progress  -- No blue to full blue
                    
                    love.graphics.setColor(r, g, b, alpha)
                    love.graphics.line(points)
                end
            end
        end
        
        -- Draw needle (vertical line)
        love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
        love.graphics.setLineWidth(3)
        love.graphics.line(needle_x, thermo_y - 5, needle_x, thermo_y + thermo_height + 5)
        love.graphics.setLineWidth(1)
        
        -- Border - draw rectangle
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", tube_x, thermo_y, tube_width, thermo_height, 5)
        love.graphics.setLineWidth(1)
        
        -- Draw sprite in the freed-up right space (first quad from UI assets)
        if ui_assets_spritesheet and ui_assets_quads[1] then
            love.graphics.setColor(1, 1, 1, 1)
            local sprite_x = right_box_x + right_box_width - 50 - 32  -- 50px space, 64px (32*2) sprite width
            local sprite_y = slot_bottom + box_height / 2 - 32  -- Center vertically
            local base_sprite_scale = 2  -- Same size as spin tokens
            
            -- Add grow/shrink animation
            local grow_shrink = math.sin(sprite_animation_time * 2) * 0.15  -- Oscillate ±15%
            local animated_scale = base_sprite_scale * (1.0 + grow_shrink)
            
            -- Draw from center - add origin offset to center the scaling
            love.graphics.draw(ui_assets_spritesheet, ui_assets_quads[1], sprite_x + 32, sprite_y + 32, 0, animated_scale, animated_scale, 16, 16)
        end
    end
end

-- ============================================================================
-- BANKROLL AND PAYOUT DISPLAY
-- ============================================================================

function UI.drawBankrollAndPayout(state, draw_wavy_text, get_wiggle_modifiers)
    local b_col = UIConfig.TEXT_WHITE
    if state.bankroll < 0 then b_col = UIConfig.BANKROLL_NEGATIVE else b_col = UIConfig.BANKROLL_POSITIVE end
    local bank_txt = "BAL: $" .. format_large_number(state.bankroll)

    -- Calculate dimensions for combined backing rectangle
    local payout_y = Config.BANKROLL_Y - state.symbol_font:getHeight() - UIConfig.BANKROLL_PAYOUT_LINE_SPACING
    local tw_bank = state.symbol_font:getWidth(bank_txt)
    local th_font = state.symbol_font:getHeight()
    
    local pw_payout = 0
    if state.display_payout_string ~= "" then
        pw_payout = state.symbol_font:getWidth(state.display_payout_string)
    end
    
    -- Draw single large backing rectangle for both payout and bankroll
    local max_width = math.max(tw_bank, pw_payout)
    local combined_height = th_font * 2 + UIConfig.BANKROLL_PAYOUT_LINE_SPACING
    local box_top_y = Config.SLOT_Y + 150 + 20 + 245
    local bal_box_x = Config.INDICATOR_BOX_START_X + 7
    local first_slot_right = Config.PADDING_X + Config.SLOT_WIDTH
    local bal_box_width = first_slot_right - bal_box_x + UIConfig.BANKROLL_PAYOUT_PADDING + 30
    
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", bal_box_x - UIConfig.BANKROLL_PAYOUT_PADDING, box_top_y, bal_box_width, combined_height + UIConfig.BANKROLL_PAYOUT_PADDING, UIConfig.BANKROLL_PAYOUT_CORNER_RADIUS)

    -- PAYOUT
    if state.display_payout_string ~= "" then
        draw_wavy_text(state.display_payout_string, bal_box_x, payout_y, state.symbol_font, state.display_payout_color, UIConfig.PAYOUT_SEED, 1.0, get_wiggle_modifiers)
    end

    -- Draw BANKROLL
    draw_wavy_text(bank_txt, bal_box_x, Config.BANKROLL_Y, state.symbol_font, b_col, UIConfig.BANKROLL_SEED, 1.0, get_wiggle_modifiers)
end

-- ============================================================================
-- UI UPDATE (for animations)
-- ============================================================================

function UI.update(dt)
    -- Update oscillation animation for tokens
    token_oscillation_time = token_oscillation_time + dt
    
    -- Update sprite animation
    sprite_animation_time = sprite_animation_time + dt
    
    -- Update gauge needle with twitchy behavior
    gauge_twitch_timer = gauge_twitch_timer + dt
    local current_balance = (love.graphics.getFont() and 1 or 0) -- Dummy to avoid nil  
    local state = require("game_mechanics.slot_machine").getState()
    if state then
        current_balance = state.bankroll or 0
        local Shop = require("ui.shop")
        local goal_balance = Shop.get_balance_goal()
        local actual_progress = math.min(1.0, current_balance / goal_balance)
        
        -- Smooth movement toward actual value with twitches (more erratic when further from 100%)
        local target_progress = actual_progress
        local twitchy_offset = 0
        
        -- Distance from goal (0 = at goal, 1 = far from goal)
        local distance_from_goal = 1.0 - actual_progress
        
        -- Add sporadic twitches - more frequent and intense when far from goal
        if gauge_twitch_timer > (0.1 * (0.5 + actual_progress * 0.5)) then  -- Timer faster when far from goal
            gauge_twitch_timer = 0
            -- Occasionally overshoot/undershoot for twitchy effect (scaled by distance)
            if math.random() > (0.7 - distance_from_goal * 0.3) then  -- More likely to twitch when far
                twitchy_offset = (math.random() - 0.5) * (0.15 + distance_from_goal * 0.25)  -- Larger twitches when far
            end
        end
        
        -- Small random noise every frame for continuous twitchiness (more when far from goal)
        twitchy_offset = twitchy_offset + (math.random() - 0.5) * (0.02 + distance_from_goal * 0.04)
        
        -- Smoothly move toward target (less smooth when far from goal)
        local easing = 0.1 * (0.5 + actual_progress * 0.5)  -- Slower easing when far from goal
        local difference = target_progress + twitchy_offset - gauge_display_progress
        gauge_display_progress = gauge_display_progress + difference * easing
        
        -- Clamp to valid range
        gauge_display_progress = math.max(0, math.min(1.0, gauge_display_progress))
    end
    
    -- Check if a spin was just used
    local current_spins = Shop.get_spins_remaining()
    
    if current_spins ~= prev_spins_remaining then
        print("[UI.UPDATE] Spin count changed! prev=" .. prev_spins_remaining .. ", current=" .. current_spins)
    end
    
    if current_spins < prev_spins_remaining then
        -- A spin was used! Create a departing token animation
        print("[UI.UPDATE] Spin detected! prev=" .. prev_spins_remaining .. ", current=" .. current_spins)
        table.insert(departing_tokens, {
            x = last_token_x + 32,  -- Center of last token (token_size/2)
            y = last_token_y + 32,  -- Center of last token (token_size/2)
            vx = math.random(-150, 150),  -- Random horizontal velocity
            vy = -100 + math.random(-50, 50),  -- Initial velocity with random direction variation
            lifetime = 0,
            max_lifetime = 1.2  -- How long the animation lasts before disappearing off screen
        })
        print("[UI.UPDATE] Animation created at (" .. last_token_x .. ", " .. last_token_y .. "), departing_tokens count: " .. #departing_tokens)
    elseif current_spins > prev_spins_remaining then
        -- Spins were added! Create arriving token animations for new spins
        print("[UI.UPDATE] Spins restocked! prev=" .. prev_spins_remaining .. ", current=" .. current_spins)
        local spins_added = current_spins - prev_spins_remaining
        for i = 1, spins_added do
            local slot_index = prev_spins_remaining + i
            table.insert(arriving_tokens, {
                slot_index = slot_index,
                lifetime = 0,
                max_lifetime = 0.3,  -- Animation duration for arrival (faster)
                delay = (i - 1) * 0.08  -- Stagger tokens by 0.08 seconds each (quicker)
            })
        end
        print("[UI.UPDATE] Added " .. spins_added .. " arriving token animations")
    end
    
    prev_spins_remaining = current_spins
    
    -- Update all departing tokens
    local i = 1
    while i <= #departing_tokens do
        local token = departing_tokens[i]
        token.lifetime = token.lifetime + dt
        
        -- Apply gravity (makes it fall faster)
        token.vy = token.vy + 1500 * dt
        
        -- Update position
        token.x = token.x + token.vx * dt
        token.y = token.y + token.vy * dt
        
        -- Remove if animation is done
        if token.lifetime >= token.max_lifetime then
            table.remove(departing_tokens, i)
        else
            i = i + 1
        end
    end
    
    -- Update all arriving tokens
    local j = 1
    while j <= #arriving_tokens do
        local token = arriving_tokens[j]
        token.lifetime = token.lifetime + dt
        
        -- Remove if animation is done (including delay)
        if token.lifetime >= (token.max_lifetime + token.delay) then
            table.remove(arriving_tokens, j)
        else
            j = j + 1
        end
    end
end

function UI.clear_animations()
    departing_tokens = {}
    arriving_tokens = {}
end

function UI.initialize()
    -- Reset animation tracking when UI is initialized
    prev_spins_remaining = Shop.get_spins_remaining()
    departing_tokens = {}
    arriving_tokens = {}
    print("[UI.INITIALIZE] UI initialized! prev_spins_remaining set to: " .. prev_spins_remaining)
    print("[UI.INITIALIZE] departing_tokens and arriving_tokens cleared")
end

function UI.get_upgrade_box_positions()
    return upgrade_box_positions
end

return UI
