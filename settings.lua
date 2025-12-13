-- settings.lua
local Config = require("conf")
local SlotMachine = require("slot_machine") -- To check jam state
local Settings = {} -- Ensure the module table is initialized

-- State
local settings_icon = nil

-- Menu dimensions
local MENU_W = Config.GAME_WIDTH * 0.9
local MENU_H = Config.GAME_HEIGHT * 0.9
local MENU_X = (Config.GAME_WIDTH - MENU_W) / 2
local MENU_Y = (Config.GAME_HEIGHT - MENU_H) / 2
local CLOSE_BTN_SIZE = 50
local CLOSE_PADDING = 15

function Settings.load()
    local ok, img = pcall(love.graphics.newImage, Config.SETTINGS_ASSET)
    if ok then
        settings_icon = img
    else
        -- Fallback: simple square icon if settings.png is missing
        print("Warning: Missing " .. (Config.SETTINGS_ASSET or "settings asset path") .. ". Using fallback square.")
        local p = love.image.newImageData(32, 32)
        p:setPixel(0, 0, 1, 1, 1, 1) 
        settings_icon = love.graphics.newImage(p)
    end
end

-- --- Button Input Helpers ---

-- Checks if a point (x, y) is within the bounds of the settings button
function Settings.check_settings_button(x, y)
    local bx = Config.SETTINGS_BTN_X
    local by = Config.SETTINGS_BTN_Y
    local size = Config.SETTINGS_BTN_SIZE
    
    return x >= bx and x <= bx + size and y >= by and y <= by + size
end

-- Checks if a point (x, y) is within the bounds of the menu close button
function Settings.check_close_button(x, y)
    local cx_start = MENU_X + MENU_W - CLOSE_BTN_SIZE - CLOSE_PADDING
    local cy_start = MENU_Y + CLOSE_PADDING
    
    return x >= cx_start and x <= cx_start + CLOSE_BTN_SIZE and y >= cy_start and y <= cy_start + CLOSE_BTN_SIZE
end

-- --- Drawing Functions ---

function Settings.draw_settings_button()
    local bx = Config.SETTINGS_BTN_X
    local by = Config.SETTINGS_BTN_Y
    local size = Config.SETTINGS_BTN_SIZE
    
    love.graphics.push()
    
    -- Draw transparent square backdrop
    love.graphics.setColor(1, 1, 1, 0.2) 
    love.graphics.rectangle("fill", bx, by, size, size, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", bx, by, size, size, 5, 5)

    -- Draw asset image (settings.png)
    if settings_icon then
        local img_w = settings_icon:getWidth()
        local img_h = settings_icon:getHeight()
        -- Calculate scale to fit the image inside the button square
        local scale = size / math.max(img_w, img_h)
        local tx = bx + size/2
        local ty = by + size/2
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(settings_icon, tx, ty, 0, scale, scale, img_w/2, img_h/2)
    end
    
    love.graphics.pop()
end

function Settings.draw_menu()
    if not SlotMachine.info_font then return end -- Safety check for fonts
    
    love.graphics.push()
    
    -- 1. Opaque Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", MENU_X, MENU_Y, MENU_W, MENU_H, 20, 20)
    
    -- 2. Border
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
    love.graphics.rectangle("line", MENU_X, MENU_Y, MENU_W, MENU_H, 20, 20)
    love.graphics.setLineWidth(1)
    
    -- 3. Close Button (Red X)
    local cx_start = MENU_X + MENU_W - CLOSE_BTN_SIZE - CLOSE_PADDING
    local cy_start = MENU_Y + CLOSE_PADDING
    
    love.graphics.setColor(0.8, 0.1, 0.1, 1.0)
    love.graphics.rectangle("fill", cx_start, cy_start, CLOSE_BTN_SIZE, CLOSE_BTN_SIZE, 5, 5)
    
    -- Draw Red X
    love.graphics.setColor(1, 1, 1, 1.0)
    love.graphics.setLineWidth(5)
    love.graphics.line(cx_start + CLOSE_PADDING, cy_start + CLOSE_PADDING, 
                       cx_start + CLOSE_BTN_SIZE - CLOSE_PADDING, cy_start + CLOSE_BTN_SIZE - CLOSE_PADDING)
    love.graphics.line(cx_start + CLOSE_BTN_SIZE - CLOSE_PADDING, cy_start + CLOSE_PADDING,
                       cx_start + CLOSE_PADDING, cy_start + CLOSE_BTN_SIZE - CLOSE_PADDING)
    love.graphics.setLineWidth(1)

    -- 4. Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(SlotMachine.info_font)
    local title = "Settings & Configuration"
    local tw = SlotMachine.info_font:getWidth(title)
    love.graphics.print(title, MENU_X + MENU_W/2 - tw/2, MENU_Y + CLOSE_PADDING)
    
    -- Add setting contents here later
    
    love.graphics.pop()
end

return Settings