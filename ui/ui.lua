-- ui.lua
-- Consolidated UI drawing system
-- Organizes all UI elements: buttons, indicators, display boxes, and overlays

local Config = require("conf")
local UIConfig = require("ui/ui_config")
local SlotMachine = require("slot_machine")

local UI = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function format_large_number(num)
    -- Format numbers in scientific notation if they exceed 99,999,999 or go below -99,999,999
    if num > 99999999 or num < -99999999 then
        return string.format("%.2e", num)
    else
        return string.format("%.0f", num)
    end
end

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
    local Keepsakes = require("keepsakes")
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
    local button_font = love.graphics.getFont()
    local symbol_font = love.graphics.newFont(UIConfig.FONT_FILE, UIConfig.SYMBOL_FONT_SIZE)
    
    local button_defs = {
        {y_offset = 15, type = "FLAT", symbol = "$", increment_text = "+100"},
        {y_offset = Config.BUTTON_HEIGHT + Config.BUTTON_GAP - 5, type = "PERCENT", symbol = "%", increment_text = "+0.5%"},
    }
    
    local bx = Config.BUTTON_START_X
    local current_flat_bet = Slots.getFlatBetBase()
    local current_pct = Slots.getBetPercent()
    
    for i, def in ipairs(button_defs) do
        local by = Config.BUTTON_START_Y + def.y_offset + UIConfig.BUTTON_Y_OFFSET
        local color = Config.BUTTON_COLORS[def.type]
        local border_color = Config.BUTTON_BORDER_COLORS[def.type]
        
        local offset = 0
        if active_button_index == i then
            offset = UIConfig.BUTTON_ANIMATION_DEPTH
        end
        
        love.graphics.push()
        
        -- Button Face
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", bx, by + offset, Config.BUTTON_WIDTH, UIConfig.BUTTON_HEIGHT_ADJUSTED, UIConfig.BUTTON_CORNER_RADIUS)
        
        -- Border
        love.graphics.setColor(border_color)
        love.graphics.setLineWidth(UIConfig.BUTTON_BORDER_WIDTH)
        love.graphics.rectangle("line", bx, by + offset, Config.BUTTON_WIDTH, UIConfig.BUTTON_HEIGHT_ADJUSTED, UIConfig.BUTTON_CORNER_RADIUS)
        love.graphics.setLineWidth(UIConfig.BUTTON_LINE_WIDTH_DEFAULT)
        
        -- Combined text: +Symbol+Amount on one line
        love.graphics.setFont(button_font)
        local symbol = def.symbol
        local increment_amount = def.increment_text:sub(2)  -- Remove the + from increment_text
        -- Remove % if present in increment_amount
        if increment_amount:sub(-1) == "%" then
            increment_amount = increment_amount:sub(1, -2)
        end
        local combined_text = "^ " .. symbol .. increment_amount
        
        love.graphics.setColor(UIConfig.TEXT_WHITE)
        local ctw = button_font:getWidth(combined_text)
        local scale = UIConfig.BUTTON_TEXT_SCALE
        if ctw > (Config.BUTTON_WIDTH - 10) then
            scale = (Config.BUTTON_WIDTH - 10) / ctw
        end
        draw_wavy_text(combined_text, bx + Config.BUTTON_WIDTH / 2 - (ctw * scale) / 2, by + UIConfig.BUTTON_HEIGHT_ADJUSTED / 2 + UIConfig.BUTTON_TEXT_OFFSET_Y + offset, button_font, UIConfig.TEXT_WHITE, 260 + i * 5, scale, get_wiggle_modifiers)
        
        love.graphics.pop()
    end
end

-- ============================================================================
-- DISPLAY BOXES (Above Slots and Bottom Overlays)
-- ============================================================================

function UI.drawDisplayBoxes()
    -- Display box constants
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    
    local start_x = Config.PADDING_X + 30
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    
    -- Draw the 5 main display boxes
    love.graphics.setColor(UIConfig.DISPLAY_BOX_COLOR)
    for i = 1, UIConfig.DISPLAY_BOX_COUNT do
        local x = start_x + (i - 1) * (BOX_WIDTH + BOX_GAP)
        local y = box_y
        love.graphics.rectangle("fill", x, y, BOX_WIDTH, BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    end
    
    -- Draw luckykeepsake box
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = box_y
    
    love.graphics.setColor(UIConfig.DISPLAY_BOX_COLOR)
    love.graphics.rectangle("fill", lucky_x, lucky_y, UIConfig.LUCKY_BOX_WIDTH, UIConfig.LUCKY_BOX_HEIGHT, UIConfig.BOX_CORNER_RADIUS)
    
    -- Draw keepsake texture or name in lucky box
    local Keepsakes = require("keepsakes")
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

-- Draw keepsake effect splash above the lucky box
function UI.drawKeepsakeSplash(state)
    if not state or (state.keepsake_splash_timer or 0) <= 0 then return end
    
    local Keepsakes = require("keepsakes")
    local keepsake_id = Keepsakes.get()
    if not keepsake_id then return end
    
    local progress = state.keepsake_splash_timer / state.KEEPSAKE_SPLASH_DURATION
    local alpha = progress  -- Fade out as timer decreases
    
    local splash_text = state.keepsake_splash_text or ""
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = Config.PERCENT_BOX_Y  -- Position above lucky box
    local splash_y = lucky_y - 50
    
    love.graphics.setColor(state.keepsake_splash_color[1], state.keepsake_splash_color[2], state.keepsake_splash_color[3], alpha)
    love.graphics.setFont(SlotMachine.info_font)
    local tw = SlotMachine.info_font:getWidth(splash_text)
    local box_center_x = lucky_x + UIConfig.LUCKY_BOX_WIDTH / 2
    love.graphics.print(splash_text, box_center_x - tw / 2, splash_y)
end

function UI.drawBottomOverlays()
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
        -- Left box (spin#)
        local left_box_width = bottom_box_width / 2 - UIConfig.BOTTOM_BOX_GAP - UIConfig.BOTTOM_BOX_LEFT_OFFSET
        local left_box_x_pos = left_box_x + UIConfig.BOTTOM_BOX_LEFT_OFFSET
        love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
        love.graphics.rectangle("fill", left_box_x_pos, slot_bottom, left_box_width, box_height, UIConfig.BOX_CORNER_RADIUS)
        
        -- Right box (threshold)
        local right_box_x = left_box_x + bottom_box_width / 2 + UIConfig.BOTTOM_BOX_GAP
        local right_box_width = bottom_box_width / 2 - UIConfig.BOTTOM_BOX_GAP
        love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
        love.graphics.rectangle("fill", right_box_x, slot_bottom, right_box_width, box_height, UIConfig.BOX_CORNER_RADIUS)
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

return UI
