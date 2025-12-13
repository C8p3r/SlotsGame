-- buttons.lua
local Config = require("conf")
local SlotMachine = require("slot_machine") 

local Buttons = {}

local active_button_index = nil
local button_font 
local symbol_font -- Font specifically for the large symbol/amount
local ANIMATION_DEPTH = 5 -- Pixel offset when pressed

function Buttons.load()
    active_button_index = nil
    -- Load custom font for betting controls/text (small text)
    button_font = love.graphics.newFont("splashfont.otf", 20) 
    -- Larger font for main symbols/amounts
    symbol_font = love.graphics.newFont("splashfont.otf", 36) 
end

function Buttons.update(dt)
    -- Buttons are decorative, no active LERP needed
end

-- Helper structure for button definitions (to simplify interaction check)
local button_defs = {
    {y_offset = 0, type = "FLAT", symbol = "$", increment_text = "+100"},
    {y_offset = Config.BUTTON_HEIGHT + Config.BUTTON_GAP, type = "PERCENT", symbol = "%", increment_text = "+0.5%"},
}

function Buttons.mousePressed(x, y)
    local bx = Config.BUTTON_START_X
    
    for i, def in ipairs(button_defs) do
        local by = Config.BUTTON_START_Y + def.y_offset
        
        if x >= bx and x <= bx + Config.BUTTON_WIDTH and 
           y >= by and y <= by + Config.BUTTON_HEIGHT then
            
            SlotMachine.adjustBet(def.type, 1)
            active_button_index = i -- Store index for animation
            return true
        end
    end
    return false
end

function Buttons.mouseReleased(x, y)
    local was_active = (active_button_index ~= nil)
    active_button_index = nil
    return was_active
end

function Buttons.draw()
    local DARK_GRAY_COLOR = {0.15, 0.15, 0.15}
    local BORDER_COLOR = {1, 1, 1}
    
    -- DRAW FUNCTIONAL BUTTONS
    local bx = Config.BUTTON_START_X
    local current_flat_bet = SlotMachine.getFlatBetBase()
    local current_pct = SlotMachine.getBetPercent()
    
    for i, def in ipairs(button_defs) do
        local by = Config.BUTTON_START_Y + def.y_offset
        local color = Config.BUTTON_COLORS[def.type]
        
        local offset = 0
        if active_button_index == i then
            offset = ANIMATION_DEPTH -- Pressed animation offset
        end
        
        love.graphics.push()
        
        -- Backdrop (Fixed position for the shadow/depth)
        love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5)
        love.graphics.rectangle("fill", bx, by + 5, Config.BUTTON_WIDTH, Config.BUTTON_HEIGHT, 10, 10)
        
        -- Button Face (Moves with offset)
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", bx, by + offset, Config.BUTTON_WIDTH, Config.BUTTON_HEIGHT, 10, 10)
        
        -- Border
        love.graphics.setColor(BORDER_COLOR)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by + offset, Config.BUTTON_WIDTH, Config.BUTTON_HEIGHT, 10, 10)
        love.graphics.setLineWidth(1)
        
        -- --- SYMBOLIC CONTENT ---
        love.graphics.setFont(symbol_font)
        local symbol = def.symbol
        local stw = symbol_font:getWidth(symbol)
        
        -- Draw main symbol ($, %)
        love.graphics.setColor(1, 1, 1)
        -- Positioned high and centered
        love.graphics.print(symbol, bx + Config.BUTTON_WIDTH / 2, by + 10 + offset, 0, 1.0, 1.0, stw / 2, 0)
        
        love.graphics.setFont(button_font)
        local line2 = def.increment_text -- Use simplified increment text
        
        -- Draw increment amount (+100 or +0.5%)
        love.graphics.setColor(1, 1, 0)
        local tw2 = button_font:getWidth(line2)
        local scale2 = 1.0
        if tw2 > (Config.BUTTON_WIDTH - 10) then
            scale2 = (Config.BUTTON_WIDTH - 10) / tw2
        end
        -- Positioned lower and centered
        love.graphics.print(line2, bx + Config.BUTTON_WIDTH / 2, by + Config.BUTTON_HEIGHT / 2 + 10 + offset, 0, scale2, scale2, tw2 / 2, 0)
        
        love.graphics.pop()
    end
    
    -- --- DISPLAY BOXES ---
    
    -- 1. FLAT BET BASE DISPLAY
    local fb_x = Config.BUTTON_START_X
    local fb_y = Config.FLAT_BET_BOX_Y
    
    love.graphics.setColor(DARK_GRAY_COLOR)
    love.graphics.rectangle("fill", fb_x, fb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    love.graphics.setColor(BORDER_COLOR)
    love.graphics.rectangle("line", fb_x, fb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    
    -- Text: FLAT: $X
    local fb_str = "FLAT: $" .. string.format("%.0f", current_flat_bet)
    love.graphics.setColor(0.2, 0.8, 0.2) 
    
    love.graphics.setFont(button_font)
    local tw = button_font:getWidth(fb_str)
    
    -- Small font scale for FLAT text
    local flat_scale = 0.8
    love.graphics.print(fb_str, fb_x + Config.BET_BOX_WIDTH/2, fb_y + Config.BET_BOX_HEIGHT/2, 0, flat_scale, flat_scale, tw/2, button_font:getHeight()/2)


    -- 2. PERCENTAGE CALCULATION DISPLAY (FLAT + % OF BALANCE)
    local pb_x = Config.BUTTON_START_X
    local pb_y = Config.PERCENT_BOX_Y
    
    love.graphics.setColor(DARK_GRAY_COLOR)
    love.graphics.rectangle("fill", pb_x, pb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    love.graphics.setColor(BORDER_COLOR)
    love.graphics.rectangle("line", pb_x, pb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    
    love.graphics.setColor(0.2, 1.0, 1.0) -- Cyan for visibility
    local pct_str = string.format("$%.0f + %.1f%%", current_flat_bet, current_pct * 100)
    
    love.graphics.setFont(button_font)
    tw = button_font:getWidth(pct_str)
    local text_scale = 1.0
    if tw > (Config.BET_BOX_WIDTH - 10) then
        text_scale = (Config.BET_BOX_WIDTH - 10) / tw
    end

    love.graphics.print(pct_str, pb_x + Config.BET_BOX_WIDTH/2, pb_y + Config.BET_BOX_HEIGHT/2, 0, text_scale, text_scale, tw/2, button_font:getHeight()/2)


    -- 3. TOTAL BET DISPLAY BOX 
    local tb_x = Config.BUTTON_START_X
    local tb_y = Config.TOTAL_BET_BOX_Y
    local display_str = "TOTAL: $" .. string.format("%.0f", SlotMachine.getCurrentBet())
    
    love.graphics.setColor(DARK_GRAY_COLOR)
    love.graphics.rectangle("fill", tb_x, tb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    love.graphics.setColor(BORDER_COLOR)
    love.graphics.rectangle("line", tb_x, tb_y, Config.BET_BOX_WIDTH, Config.BET_BOX_HEIGHT, 5, 5)
    
    love.graphics.setColor(0.2, 1.0, 0.2) -- Green for total bet
    tw = button_font:getWidth(display_str)
    
    -- Small font scale for TOTAL text
    local total_scale = 0.8
    love.graphics.print(display_str, tb_x + Config.BET_BOX_WIDTH/2, tb_y + Config.BET_BOX_HEIGHT/2, 0, total_scale, total_scale, tw/2, button_font:getHeight()/2)
end

return Buttons