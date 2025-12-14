-- buttons.lua
local Config = require("conf")
local UIConfig = require("ui/ui_config")
local SlotMachine = require("slot_machine") 

local Buttons = {}

local active_button_index = nil
local button_font 
local symbol_font -- Font specifically for the large symbol/amount

function Buttons.load()
    active_button_index = nil
    -- Load custom font for betting controls/text (small text)
    button_font = love.graphics.newFont(UIConfig.FONT_FILE, UIConfig.BUTTON_FONT_SIZE) 
    -- Larger font for main symbols/amounts
    symbol_font = love.graphics.newFont(UIConfig.FONT_FILE, UIConfig.SYMBOL_FONT_SIZE) 
end

function Buttons.update(dt)
    -- Buttons are decorative, no active LERP needed
end

-- Helper structure for button definitions (to simplify interaction check)
local button_defs = {
    {y_offset = 15, type = "FLAT", symbol = "$", increment_text = "+100"},
    {y_offset = Config.BUTTON_HEIGHT + Config.BUTTON_GAP - 10, type = "PERCENT", symbol = "%", increment_text = "+0.5%"},
}

function Buttons.mousePressed(x, y)
    local bx = Config.BUTTON_START_X
    
    for i, def in ipairs(button_defs) do
        local by = Config.BUTTON_START_Y + def.y_offset + UIConfig.BUTTON_Y_OFFSET
        
        if x >= bx and x <= bx + Config.BUTTON_WIDTH and 
           y >= by and y <= by + UIConfig.BUTTON_HEIGHT_ADJUSTED then
            
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

return Buttons