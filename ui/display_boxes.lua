-- display_boxes.lua
-- 5 decorative boxes displayed above the main slots and below dialogue text

local Config = require("conf")
local DisplayBoxes = {}

-- Box dimensions (same as slots for visual consistency)
local BOX_COUNT = 5
local BOX_WIDTH = Config.SLOT_WIDTH
local BOX_GAP = Config.SLOT_GAP
local BOX_COLOR = {0.15, 0.15, 0.15, 0.8}
local BOX_BORDER_COLOR = {0.6, 0.6, 0.6}
local BOX_BORDER_WIDTH = 2

-- Calculate positioning
local total_box_w = (BOX_WIDTH * BOX_COUNT) + (BOX_GAP * (BOX_COUNT - 1))
local start_x = Config.PADDING_X + 30  -- Offset to align with slot positions
local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40  -- 10px lower from dialogue
local BOX_HEIGHT = Config.SLOT_Y - box_y - 20  -- Extend down with 20px gap to slot boxes

function DisplayBoxes.draw()
    love.graphics.setLineWidth(BOX_BORDER_WIDTH)
    
    -- Draw the 5 main display boxes
    for i = 1, BOX_COUNT do
        local x = start_x + (i - 1) * (BOX_WIDTH + BOX_GAP)
        local y = box_y
        
        -- Draw box background
        love.graphics.setColor(BOX_COLOR)
        love.graphics.rectangle("fill", x, y, BOX_WIDTH, BOX_HEIGHT, 5, 5)
    end
    
    -- Draw luckykeepsake box (above flat bet increase button, to the left)
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = box_y  -- Align top with display boxes
    local lucky_width = 120
    local lucky_height = 120  -- Square box
    
    love.graphics.setColor(BOX_COLOR)
    love.graphics.rectangle("fill", lucky_x, lucky_y, lucky_width, lucky_height, 5, 5)
    
    -- Draw two opaque black boxes at the bottom to fill space below slots
    local slot_bottom = Config.SLOT_Y + 150 + 20 + 245  -- Approximate slot height, 20px gap from bottom of slots, moved down 245px
    local bottom_box_height = 40  -- Fixed height of 40px
    local left_box_x = Config.PADDING_X + 30
    local right_box_x = left_box_x + (BOX_WIDTH * BOX_COUNT) + (BOX_GAP * (BOX_COUNT - 1)) + BOX_GAP
    local bottom_box_width = (BOX_WIDTH * BOX_COUNT) + (BOX_GAP * (BOX_COUNT - 1))
    
    if bottom_box_height > 0 then
        love.graphics.setColor(0, 0, 0, 1)  -- Opaque black
        love.graphics.rectangle("fill", left_box_x + 230, slot_bottom, bottom_box_width / 2 - 5 - 230, bottom_box_height)
        love.graphics.rectangle("fill", left_box_x + bottom_box_width / 2 + 5, slot_bottom, bottom_box_width / 2 - 5, bottom_box_height)
    end
    
    love.graphics.setLineWidth(1)
end

function DisplayBoxes.getBoxY()
    return box_y
end

function DisplayBoxes.getBoxCount()
    return BOX_COUNT
end

return DisplayBoxes
