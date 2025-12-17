-- display_boxes.lua
-- Single decorative box displayed above the main slots and below dialogue text

local Config = require("conf")
local DisplayBoxes = {}

-- Box dimensions
local BOX_COUNT = 5
local BOX_WIDTH = Config.SLOT_WIDTH
local BOX_GAP = Config.SLOT_GAP
local BOX_COLOR = {0.15, 0.15, 0.15, 0.8}
local BOX_BORDER_COLOR = {0.6, 0.6, 0.6}
local BOX_BORDER_WIDTH = 2

-- Calculate positioning
local start_x = Config.PADDING_X + 30
local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
local BOX_HEIGHT = Config.SLOT_Y - box_y - 20

-- Calculate total box width (from left edge of first box to right edge of last box)
local total_box_width = (BOX_WIDTH * BOX_COUNT) + (BOX_GAP * (BOX_COUNT - 1))

function DisplayBoxes.draw()
    -- Display boxes removed
end

function DisplayBoxes.getBoxY()
    return box_y
end

function DisplayBoxes.getBoxCount()
    return BOX_COUNT
end

return DisplayBoxes
