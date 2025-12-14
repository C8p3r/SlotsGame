-- settings.lua
local Config = require("conf")
local UIConfig = require("ui/ui_config")
local SlotMachine = require("slot_machine") -- To check jam state
local Difficulty = require("difficulty") -- For difficulty settings
local Keepsakes = require("keepsakes") -- For keepsake settings
local Settings = {} -- Ensure the module table is initialized

-- State
local settings_icon = nil

-- Menu dimensions
local MENU_W = Config.GAME_WIDTH * UIConfig.SETTINGS_MENU_WIDTH_RATIO
local MENU_H = Config.GAME_HEIGHT * UIConfig.SETTINGS_MENU_HEIGHT_RATIO
local MENU_X = (Config.GAME_WIDTH - MENU_W) / 2
local MENU_Y = (Config.GAME_HEIGHT - MENU_H) / 2

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
    local cx_start = MENU_X + MENU_W - UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING
    local cy_start = MENU_Y + UIConfig.SETTINGS_CLOSE_BTN_PADDING
    
    return x >= cx_start and x <= cx_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE and y >= cy_start and y <= cy_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE
end

-- Checks if a difficulty button was clicked in the settings menu
function Settings.check_difficulty_click(x, y)
    local button_y = MENU_Y + MENU_H * 0.25
    local button_spacing = 100
    local button_width = 90
    local button_height = 45
    local buttons_start_x = MENU_X + (MENU_W / 2) - button_spacing - 60
    
    local difficulties = {"EASY", "MEDIUM", "HARD"}
    
    for i, diff in ipairs(difficulties) do
        local button_x = buttons_start_x + (i - 1) * button_spacing
        
        if x >= button_x and x <= button_x + button_width and
           y >= button_y and y <= button_y + button_height then
            Difficulty.set(diff)
            return true
        end
    end
    
    return false
end

-- Checks if a keepsake was clicked in the settings menu
function Settings.check_keepsake_click(x, y)
    local grid_start_x = MENU_X + MENU_W * 0.5 - 160
    local grid_start_y = MENU_Y + MENU_H * 0.45
    return Keepsakes.check_click(x, y, grid_start_x, grid_start_y, 60, 6)
end

-- --- Drawing Functions ---

function Settings.draw_settings_button()
    local bx = Config.SETTINGS_BTN_X
    local by = Config.SETTINGS_BTN_Y - 20
    local size = Config.SETTINGS_BTN_SIZE
    
    love.graphics.push()
    
    -- Draw standard UI backdrop
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", bx, by, size, size, 5, 5)
    
    -- Draw border
    love.graphics.setColor(UIConfig.BOX_BORDER_COLOR)
    love.graphics.rectangle("line", bx, by, size, size, 5, 5)

    -- Draw asset image (settings.png)
    if settings_icon then
        local img_w = settings_icon:getWidth()
        local img_h = settings_icon:getHeight()
        -- Calculate scale to fit the image inside the button square
        local scale = size / math.max(img_w, img_h)
        local tx = bx + size/2
        local ty = by + size/2
        
        love.graphics.setColor(UIConfig.TEXT_WHITE)
        love.graphics.draw(settings_icon, tx, ty, 0, scale, scale, img_w/2, img_h/2)
    end
    
    love.graphics.pop()
end

function Settings.draw_menu()
    if not SlotMachine.info_font then return end -- Safety check for fonts
    
    love.graphics.push()
    
    -- 1. Fully black background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", MENU_X, MENU_Y, MENU_W, MENU_H, UIConfig.SETTINGS_MENU_CORNER_RADIUS)
    
    -- 2. Border
    love.graphics.setLineWidth(UIConfig.SETTINGS_MENU_BORDER_WIDTH)
    love.graphics.setColor(UIConfig.SETTINGS_MENU_BORDER_COLOR)
    love.graphics.rectangle("line", MENU_X, MENU_Y, MENU_W, MENU_H, UIConfig.SETTINGS_MENU_CORNER_RADIUS)
    love.graphics.setLineWidth(1)
    
    -- 3. Close Button (Red X)
    local cx_start = MENU_X + MENU_W - UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING
    local cy_start = MENU_Y + UIConfig.SETTINGS_CLOSE_BTN_PADDING
    
    love.graphics.setColor(UIConfig.SETTINGS_CLOSE_BTN_COLOR)
    love.graphics.rectangle("fill", cx_start, cy_start, UIConfig.SETTINGS_CLOSE_BTN_SIZE, UIConfig.SETTINGS_CLOSE_BTN_SIZE, 5, 5)
    
    -- Draw Red X
    love.graphics.setColor(UIConfig.TEXT_WHITE)
    love.graphics.setLineWidth(UIConfig.SETTINGS_CLOSE_BTN_LINE_WIDTH)
    love.graphics.line(cx_start + UIConfig.SETTINGS_CLOSE_BTN_PADDING, cy_start + UIConfig.SETTINGS_CLOSE_BTN_PADDING, 
                       cx_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING, cy_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING)
    love.graphics.line(cx_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING, cy_start + UIConfig.SETTINGS_CLOSE_BTN_PADDING,
                       cx_start + UIConfig.SETTINGS_CLOSE_BTN_PADDING, cy_start + UIConfig.SETTINGS_CLOSE_BTN_SIZE - UIConfig.SETTINGS_CLOSE_BTN_PADDING)
    love.graphics.setLineWidth(1)

    -- 4. Title
    love.graphics.setColor(UIConfig.TEXT_WHITE)
    love.graphics.setFont(SlotMachine.info_font)
    local tw = SlotMachine.info_font:getWidth(UIConfig.SETTINGS_MENU_TITLE)
    love.graphics.print(UIConfig.SETTINGS_MENU_TITLE, MENU_X + MENU_W/2 - tw/2, MENU_Y + UIConfig.SETTINGS_CLOSE_BTN_PADDING)
    
    -- 5. Difficulty Selection
    love.graphics.setColor(UIConfig.TEXT_WHITE)
    love.graphics.setFont(SlotMachine.info_font)
    local diff_label = "DIFFICULTY:"
    love.graphics.print(diff_label, MENU_X + 40, MENU_Y + MENU_H * 0.15)
    
    -- Draw difficulty buttons
    local button_y = MENU_Y + MENU_H * 0.25
    local button_spacing = 100
    local button_width = 90
    local button_height = 45
    local buttons_start_x = MENU_X + (MENU_W / 2) - button_spacing - 60
    
    local difficulties = {"EASY", "MEDIUM", "HARD"}
    local button_colors = {
        {0.2, 1.0, 0.2, 0.8},    -- Green for EASY
        {1.0, 0.8, 0.2, 0.8},    -- Gold for MEDIUM
        {1.0, 0.2, 0.2, 0.8}     -- Red for HARD
    }
    
    for i, diff in ipairs(difficulties) do
        local button_x = buttons_start_x + (i - 1) * button_spacing
        
        -- Highlight selected difficulty
        if Difficulty.get() == diff then
            love.graphics.setColor(button_colors[i][1] + 0.3, button_colors[i][2] + 0.3, button_colors[i][3] + 0.3, 1.0)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(button_colors[i])
            love.graphics.setLineWidth(1.5)
        end
        
        -- Draw button background
        love.graphics.rectangle("fill", button_x, button_y, button_width, button_height)
        
        -- Draw button border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", button_x, button_y, button_width, button_height)
        love.graphics.setLineWidth(1)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(SlotMachine.info_font)
        local text_w = SlotMachine.info_font:getWidth(diff)
        love.graphics.print(diff, button_x + button_width / 2 - text_w / 2, button_y + button_height / 2 - 8)
    end
    
    -- 6. Keepsake Selection
    love.graphics.setColor(UIConfig.TEXT_WHITE)
    love.graphics.setFont(SlotMachine.info_font)
    local keeper_label = "KEEPSAKE:"
    love.graphics.print(keeper_label, MENU_X + 40, MENU_Y + MENU_H * 0.38)
    
    -- Draw keepsake selection grid
    local grid_start_x = MENU_X + MENU_W * 0.5 - 160
    local grid_start_y = MENU_Y + MENU_H * 0.45
    Keepsakes.draw_grid(grid_start_x, grid_start_y, 60, 6, true)
    
    love.graphics.pop()
end

return Settings
