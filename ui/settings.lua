-- settings.lua
local Config = require("conf")
local UIConfig = require("ui.ui_config")
local SlotMachine = require("game_mechanics.slot_machine") -- To check jam state
local Difficulty = require("systems.difficulty") -- For difficulty settings
local Keepsakes = require("systems.keepsakes") -- For keepsake settings
local Settings = {} -- Ensure the module table is initialized

-- State
local settings_icon = nil
local ui_assets = nil
local gem_icon_quad = nil

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
    local button_spacing = 110
    local button_width = 100
    local button_height = 45
    local buttons_start_x = MENU_X + (MENU_W / 2) - 55
    
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

-- Checks if return to main menu button was clicked
function Settings.check_return_to_menu_click(x, y)
    local button_x = MENU_X + 15
    local button_y = MENU_Y + 15
    local button_width = 150
    local button_height = 40
    
    return x >= button_x and x <= button_x + button_width and
           y >= button_y and y <= button_y + button_height
end

-- Checks if a keepsake was clicked in the settings menu
function Settings.check_keepsake_click(x, y)
    local grid_start_x = MENU_X + MENU_W * 0.5 - 160
    local grid_start_y = MENU_Y + MENU_H * 0.35
    return Keepsakes.check_click(x, y, grid_start_x, grid_start_y, 80, 35)
end

-- --- Drawing Functions ---

function Settings.draw_gems_counter(gems)
    local bx = Config.BUTTON_START_X  -- Move to button position
    local by = Config.BUTTON_START_Y + 70  -- Move down 70px
    local size = Config.BUTTON_WIDTH  -- Make it square
    local width = Config.BUTTON_WIDTH  -- Match button width
    
    -- Load UI assets for gem icon if not already loaded
    if not ui_assets then
        ui_assets = love.graphics.newImage("assets/UI_assets.png")
        ui_assets:setFilter("nearest", "nearest")  -- Make sprites crisp
        local quad_width = 32
        local quad_height = 32
        local col = 2
        local row = 2
        local x = (col - 1) * quad_width
        local y = (row - 1) * quad_height
        gem_icon_quad = love.graphics.newQuad(x, y, quad_width, quad_height, ui_assets:getDimensions())
    end
    
    love.graphics.push()
    
    -- Draw background box (no border)
    love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR)
    love.graphics.rectangle("fill", bx, by, width, size, 5, 5)

    -- Draw gem icon with wobble animation - centered in box
    if ui_assets and gem_icon_quad then
        local wiggle_amount = math.sin(love.timer.getTime() * 8) * 5  -- Wobble effect
        local icon_size = 32 * 2.76  -- 32 base size scaled by 2.76x (35% bigger)
        local icon_x = bx + (width - icon_size) / 2  -- Center horizontally
        local icon_y = by + (size - icon_size) / 2 + wiggle_amount  -- Center vertically with wobble
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(ui_assets, gem_icon_quad, icon_x, icon_y, 0, 2.76, 2.76)  -- Scaled up 2.76x (35% bigger)
    end

    -- Draw gems counter text in bottom left with animation
    local time = love.timer.getTime()
    local pulse_scale = 1 + math.sin(time * 4) * 0.1  -- Subtle pulsing scale
    love.graphics.setColor(0.6, 0.8, 1, 1)  -- Cyan for gems
    local gems_font = love.graphics.newFont("splashfont.otf", 24)  -- Larger text
    love.graphics.setFont(gems_font)
    local gems_text = tostring(gems)
    local text_w = gems_font:getWidth(gems_text)
    local text_h = gems_font:getHeight()
    -- Position text in bottom left with some padding, apply pulse scale
    love.graphics.print(gems_text, bx + 8, by + size - text_h - 6, 0, pulse_scale, pulse_scale)
    
    love.graphics.pop()
end

-- Return the center position of the gems UI element in game coordinates
function Settings.get_gems_ui_position()
    local bx = Config.BUTTON_START_X
    local by = Config.BUTTON_START_Y + 70
    local width = Config.BUTTON_WIDTH
    local size = Config.BUTTON_WIDTH
    local cx = bx + width / 2
    local cy = by + size / 2
    return cx, cy
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
    local button_spacing = 110
    local button_width = 100
    local button_height = 45
    local buttons_start_x = MENU_X + (MENU_W / 2) - 55
    
    local difficulties = {"EASY", "MEDIUM", "HARD"}
    local button_colors = {
        {0.25, 0.25, 0.93, 0.8},  -- Royal blue for EASY
        {1.0, 0.8, 0.2, 0.8},     -- Gold for MEDIUM
        {1.0, 0.2, 0.2, 0.8}      -- Red for HARD
    }
    
    for i, diff in ipairs(difficulties) do
        local button_x = buttons_start_x + (i - 1) * button_spacing
        
        -- Highlight selected difficulty
        if Difficulty.get() == diff then
            love.graphics.setColor(button_colors[i])  -- Color when selected
            love.graphics.setLineWidth(4)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)  -- Grey out when not selected
            love.graphics.setLineWidth(2)
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
    local grid_start_y = MENU_Y + MENU_H * 0.35
    Keepsakes.draw_grid(grid_start_x, grid_start_y, 80, 35, true)
    
    -- 7. Return to Main Menu Button (Top Left)
    local button_x = MENU_X + 15
    local button_y = MENU_Y + 15
    local button_width = 150
    local button_height = 40
    
    love.graphics.setColor(0.2, 0.2, 0.8, 0.8)  -- Blue color
    love.graphics.rectangle("fill", button_x, button_y, button_width, button_height, 5, 5)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button_x, button_y, button_width, button_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(SlotMachine.info_font)
    local button_text = "BACK"
    local text_w = SlotMachine.info_font:getWidth(button_text)
    love.graphics.print(button_text, button_x + button_width / 2 - text_w / 2, button_y + button_height / 2 - 8)
    
    love.graphics.pop()
end

return Settings
