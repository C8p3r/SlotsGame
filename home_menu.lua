-- home_menu.lua
-- Main menu screen handling

local Config = require("conf")
local Difficulty = require("difficulty")
local Keepsakes = require("keepsakes")
local StartScreen = require("ui/start_screen")

local HomeMenu = {}

-- Menu state
HomeMenu.fonts = {
    title = nil,
    prompt = nil,
    start_button = nil
}

-- Initialize fonts for the menu
function HomeMenu.load_fonts()
    local font_file = "splashfont.otf"
    HomeMenu.fonts.title = love.graphics.newFont(font_file, StartScreen.TITLE_SIZE)
    HomeMenu.fonts.prompt = love.graphics.newFont(font_file, StartScreen.PROMPT_SIZE)
    HomeMenu.fonts.start_button = love.graphics.newFont(font_file, 100)
end

-- Draw the main menu
function HomeMenu.draw(menu_exit_timer, menu_exit_duration)
    local w, h = love.graphics.getDimensions()
    
    -- Calculate animation progress (0 to 1)
    local anim_progress = menu_exit_timer / menu_exit_duration
    local exit_offset = anim_progress * (w + h) * 2  -- Fast exit animation
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw Title
    love.graphics.setFont(HomeMenu.fonts.title)
    local title_text = StartScreen.TITLE_TEXT
    local tw = HomeMenu.fonts.title:getWidth(title_text)
    local tx = 40
    local ty = h * 0.15 - exit_offset / 2 - 70
    
    -- Simple neon effect for the title
    love.graphics.setColor(0, 0.8, 1, 0.5)
    love.graphics.print(title_text, tx + 3, ty + 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(title_text, tx, ty)
    
    -- Draw Keepsake Selection (LEFT SIDE)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setFont(Config.GAME_WIDTH == 1920 and love.graphics.getFont() or love.graphics.newFont("splashfont.otf", 14))
    Keepsakes.draw_grid(w * 0.02 - exit_offset, h * 0.25 + 50, 96, 32, true)
    
    -- Draw Difficulty Selection
    love.graphics.setFont(love.graphics.getFont())
    love.graphics.setColor(1, 1, 1, 1)
    
    local button_y = h * 0.32
    local button_width = 100
    local button_height = 45
    local button_spacing = 110
    local buttons_start_x = w / 2 - 110  -- Center-aligned to match START button center
    
    local difficulties = {"EASY", "MEDIUM", "HARD"}
    local button_colors = {
        {0.25, 0.25, 0.93, 0.8},  -- Royal blue for EASY
        {1.0, 0.8, 0.2, 0.8},     -- Gold for MEDIUM
        {1.0, 0.2, 0.2, 0.8}      -- Red for HARD
    }
    
    for i, diff in ipairs(difficulties) do
        local button_x = buttons_start_x + (i - 1) * button_spacing + exit_offset
        
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
        love.graphics.setFont(love.graphics.getFont())
        local text_w = love.graphics.getFont():getWidth(diff)
        love.graphics.print(diff, button_x + button_width / 2 - text_w / 2, button_y + button_height / 2 - 8)
    end
    
    -- Draw Prompt
    love.graphics.setFont(HomeMenu.fonts.prompt)
    local prompt_text = StartScreen.PROMPT_TEXT
    local pw = HomeMenu.fonts.prompt:getWidth(prompt_text)
    local px = w / 2 - pw / 2 + 50
    local py = h * 0.65 - exit_offset / 2
    
    -- Pulsing alpha effect for prompt
    local pulse_alpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
    love.graphics.setColor(1, 1, 1, pulse_alpha)
    love.graphics.print(prompt_text, px, py)
    
    -- Instructions - Selection message
    love.graphics.setColor(1.0, 0.8, 0.2, 1)
    local inst_font = love.graphics.newFont("splashfont.otf", 14)
    love.graphics.setFont(inst_font)
    local inst_text = "SELECT A DIFFICULTY AND KEEPSAKE TO START"
    local iw = inst_font:getWidth(inst_text)
    love.graphics.print(inst_text, w / 2 - iw / 2 + 50, h * 0.8 - exit_offset / 2)
    
    -- Draw START button (always visible)
    local button_x = w / 2 - 200 + 50
    local button_y = h * 0.48 - 20 - exit_offset / 2
    local button_w = 400
    local button_h = 120
    
    local is_enabled = Difficulty.is_selected() and Keepsakes.get()
    
    if is_enabled then
        -- Green enabled button
        love.graphics.setColor(0.2, 0.8, 0.2, 0.9)
        love.graphics.rectangle("fill", button_x, button_y, button_w, button_h)
        love.graphics.setColor(0.5, 1.0, 0.5, 1.0)
    else
        -- Grey disabled button
        love.graphics.setColor(0.3, 0.3, 0.3, 0.6)
        love.graphics.rectangle("fill", button_x, button_y, button_w, button_h)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
    end
    
    -- Button border
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", button_x, button_y, button_w, button_h)
    love.graphics.setLineWidth(1)
    
    -- Button text
    if is_enabled then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 0.6)
    end
    love.graphics.setFont(HomeMenu.fonts.start_button)
    local start_text = "START"
    local text_w = HomeMenu.fonts.start_button:getWidth(start_text)
    local text_h = HomeMenu.fonts.start_button:getHeight()
    love.graphics.print(start_text, button_x + button_w / 2 - text_w / 2, button_y + button_h / 2 - text_h / 2)
end

-- Check if difficulty button was clicked
function HomeMenu.check_difficulty_click(x, y)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    local button_y = h * 0.32
    local button_spacing = 110
    local button_width = 100
    local button_height = 45
    local buttons_start_x = w / 2 - 110  -- Center-aligned to match START button center
    
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

-- Check if START button was clicked
function HomeMenu.check_start_button_click(x, y)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    
    local button_x = w / 2 - 200 + 50
    local button_y = h * 0.48 - 20
    local button_w = 400
    local button_h = 120
    
    return x >= button_x and x <= button_x + button_w and
           y >= button_y and y <= button_y + button_h and
           Difficulty.is_selected() and Keepsakes.get()
end

-- Check if keepsake was clicked
function HomeMenu.check_keepsake_click(x, y)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    local grid_start_x = w * 0.02
    local grid_start_y = h * 0.25 + 50
    return Keepsakes.check_click(x, y, grid_start_x, grid_start_y, 96, 32)
end

-- Draw keepsake tooltip on hover
function HomeMenu.draw_keepsake_tooltip(hovered_id)
    if not hovered_id then return end
    
    local def = Keepsakes.get_definition(hovered_id)
    if not def then return end
    
    local mouse_x, mouse_y = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    
    -- Tooltip dimensions
    local tooltip_width = 250
    local tooltip_height = 100
    local padding = 10
    
    -- Position tooltip near mouse, but keep it on screen
    local tooltip_x = math.min(mouse_x + 15, w - tooltip_width - 10)
    local tooltip_y = math.min(mouse_y + 15, h - tooltip_height - 10)
    tooltip_x = math.max(tooltip_x, 10)
    tooltip_y = math.max(tooltip_y, 10)
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 1, 0, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name
    love.graphics.setColor(1, 1, 0, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    love.graphics.print(def.name, tooltip_x + padding, tooltip_y + padding)
    
    -- Draw effects as text
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    local effects_text = ""
    if def.effects.win_multiplier and def.effects.win_multiplier ~= 1.0 then
        local pct = math.floor((def.effects.win_multiplier - 1.0) * 100)
        effects_text = effects_text .. "Winnings: " .. (pct > 0 and "+" or "") .. pct .. "%\n"
    end
    if def.effects.spin_cost_multiplier and def.effects.spin_cost_multiplier ~= 1.0 then
        local pct = math.floor((1.0 - def.effects.spin_cost_multiplier) * 100)
        effects_text = effects_text .. "Spin Cost: " .. (pct > 0 and "-" or "") .. pct .. "%\n"
    end
    if def.effects.streak_multiplier and def.effects.streak_multiplier ~= 1.0 then
        local pct = math.floor((def.effects.streak_multiplier - 1.0) * 100)
        effects_text = effects_text .. "Streak: " .. (pct > 0 and "+" or "") .. pct .. "%"
    end
    
    if effects_text == "" then
        effects_text = "No major effects"
    end
    
    love.graphics.print(effects_text, tooltip_x + padding, tooltip_y + padding + 25)
end

-- Check if mouse is hovering over the lucky box during gameplay
function HomeMenu.get_lucky_box_hover(mouse_x, mouse_y)
    local UIConfig = require("ui/ui_config")
    -- Calculate box_y the same way as drawDisplayBoxes() does
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = box_y
    local lucky_width = UIConfig.LUCKY_BOX_WIDTH
    local lucky_height = UIConfig.LUCKY_BOX_HEIGHT
    
    if mouse_x >= lucky_x and mouse_x <= lucky_x + lucky_width and
       mouse_y >= lucky_y and mouse_y <= lucky_y + lucky_height then
        return Keepsakes.get()  -- Return keepsake ID if hovering
    end
    return nil
end

-- Draw tooltip for lucky box keepsake during gameplay
function HomeMenu.draw_lucky_box_tooltip(keepsake_id)
    if not keepsake_id then return end
    
    local def = Keepsakes.get_definition(keepsake_id)
    if not def then return end
    
    local mouse_x, mouse_y = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    
    -- Tooltip dimensions
    local tooltip_width = 250
    local tooltip_height = 100
    local padding = 10
    
    -- Position tooltip near mouse, but keep it on screen
    local tooltip_x = math.min(mouse_x + 15, w - tooltip_width - 10)
    local tooltip_y = math.min(mouse_y + 15, h - tooltip_height - 10)
    tooltip_x = math.max(tooltip_x, 10)
    tooltip_y = math.max(tooltip_y, 10)
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 1, 0, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name
    love.graphics.setColor(1, 1, 0, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    love.graphics.print(def.name, tooltip_x + padding, tooltip_y + padding)
    
    -- Draw effects as text
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    local effects_text = ""
    if def.effects.win_multiplier and def.effects.win_multiplier ~= 1.0 then
        local pct = math.floor((def.effects.win_multiplier - 1.0) * 100)
        effects_text = effects_text .. "Winnings: " .. (pct > 0 and "+" or "") .. pct .. "%\n"
    end
    if def.effects.spin_cost_multiplier and def.effects.spin_cost_multiplier ~= 1.0 then
        local pct = math.floor((1.0 - def.effects.spin_cost_multiplier) * 100)
        effects_text = effects_text .. "Spin Cost: " .. (pct > 0 and "-" or "") .. pct .. "%\n"
    end
    if def.effects.streak_multiplier and def.effects.streak_multiplier ~= 1.0 then
        local pct = math.floor((def.effects.streak_multiplier - 1.0) * 100)
        effects_text = effects_text .. "Streak: " .. (pct > 0 and "+" or "") .. pct .. "%"
    end
    
    if effects_text == "" then
        effects_text = "No major effects"
    end
    
    love.graphics.print(effects_text, tooltip_x + padding, tooltip_y + padding + 25)
end

return HomeMenu
