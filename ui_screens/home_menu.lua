-- home_menu.lua
-- Main menu screen handling

local Config = require("conf")
local Difficulty = require("systems.difficulty")
local Keepsakes = require("systems.keepsakes")
local UIConfig = require("ui.ui_config")
local StartScreen = require("ui_screens.start_screen")
local UpgradeNode = require("systems.upgrade_node")

local HomeMenu = {}

-- Menu state
HomeMenu.fonts = {
    title = nil,
    prompt = nil,
    start_button = nil
}

-- Menu entrance animation
local menu_entrance_timer = 0
local menu_entrance_duration = 1.2
local is_menu_entering = false
local is_menu_exiting = false
local menu_exit_timer = 0
local menu_exit_duration = 1.2

-- Initialize fonts for the menu
function HomeMenu.load_fonts()
    local font_file = "splashfont.otf"
    HomeMenu.fonts.title = love.graphics.newFont(font_file, StartScreen.TITLE_SIZE)
    HomeMenu.fonts.prompt = love.graphics.newFont(font_file, StartScreen.PROMPT_SIZE)
    HomeMenu.fonts.start_button = love.graphics.newFont(font_file, 100)
end

-- Shop seed UI state
local shop_seed_enabled = false
local shop_seed_value = ""
local shop_seed_focused = false

function HomeMenu.get_shop_seed_settings()
    if shop_seed_enabled then
        local n = tonumber(shop_seed_value)
        return true, n
    end
    return false, nil
end

-- Start the menu entrance animation
function HomeMenu.start_entrance_animation()
    menu_entrance_timer = 0
    is_menu_entering = true
    is_menu_exiting = false
    menu_exit_timer = 0
end

-- Check if menu is currently entering
function HomeMenu.is_entrance_animating()
    return is_menu_entering
end

-- Reset all menu animations
function HomeMenu.reset_animations()
    menu_entrance_timer = 0
    is_menu_entering = false
    menu_exit_timer = 0
    is_menu_exiting = false
end

-- Start the menu exit animation
function HomeMenu.start_exit_animation()
    is_menu_exiting = true
    menu_exit_timer = 0
end

-- Check if menu is currently exiting
function HomeMenu.is_exit_animating()
    return is_menu_exiting
end

-- Get current animation timers for drawing
function HomeMenu.get_animation_timers()
    return menu_entrance_timer, menu_entrance_duration, menu_exit_timer, menu_exit_duration
end

-- Update menu animations
function HomeMenu.update(dt)
    if is_menu_entering then
        menu_entrance_timer = menu_entrance_timer + dt
        if menu_entrance_timer >= menu_entrance_duration then
            menu_entrance_timer = menu_entrance_duration
            is_menu_entering = false
        end
    elseif is_menu_exiting then
        menu_exit_timer = menu_exit_timer + dt
        if menu_exit_timer >= menu_exit_duration then
            menu_exit_timer = menu_exit_duration
            is_menu_exiting = false
        end
    end
end

-- Draw the main menu
function HomeMenu.draw(menu_exit_timer, menu_exit_duration)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    
    -- Calculate entrance animation progress (0 to 1)
    local entrance_progress = menu_entrance_duration > 0 and (menu_entrance_timer / menu_entrance_duration) or 1
    -- Easing: ease-out cubic
    local entrance_ease = 1 - (1 - entrance_progress) ^ 3
    
    -- Calculate exit animation progress (0 to 1)
    local exit_progress = menu_exit_duration > 0 and (menu_exit_timer / menu_exit_duration) or 0
    local exit_ease = exit_progress * exit_progress  -- ease-in for exit
    local exit_slide_offset = exit_ease * w  -- Slide out to the right
    
    -- Entrance offset (elements slide in from the left)
    local entrance_offset = (1 - entrance_ease) * w
    
    -- Draw split black background that separates on exit
    love.graphics.setColor(0, 0, 0, 1)
    
    if exit_ease > 0 then
        -- Exit animation: split and slide off to sides
        local left_offset = exit_ease * (w / 2)  -- Left half slides left
        local right_offset = exit_ease * (w / 2)  -- Right half slides right
        
        -- Left half slides left
        love.graphics.rectangle("fill", -left_offset, 0, w / 2, h)
        -- Right half slides right
        love.graphics.rectangle("fill", w / 2 + right_offset, 0, w / 2, h)
    else
        -- Normal state: full black background
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    
    love.graphics.push()
    -- Only translate horizontally for menu elements
    love.graphics.translate(entrance_offset - exit_slide_offset, 0)
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw Title
    love.graphics.setFont(HomeMenu.fonts.title)
    local title_text = StartScreen.TITLE_TEXT
    local tw = HomeMenu.fonts.title:getWidth(title_text)
    local tx = 40
    local ty = h * 0.15 - 70
    
    -- Simple neon effect for the title
    love.graphics.setColor(0, 0.8, 1, 0.5 * entrance_ease)
    love.graphics.print(title_text, tx + 3, ty + 3)
    love.graphics.setColor(1, 1, 1, entrance_ease)
    love.graphics.print(title_text, tx, ty)
    
    -- Draw Keepsake Selection (LEFT SIDE)
    love.graphics.setColor(0.8, 0.8, 0.8, entrance_ease)
    love.graphics.setFont(Config.GAME_WIDTH == 1920 and love.graphics.getFont() or love.graphics.newFont("splashfont.otf", 14))
    Keepsakes.draw_grid(w * 0.02, h * 0.25 + 50, 96, 32, true)
    
    -- Draw Difficulty Selection
    love.graphics.setFont(love.graphics.getFont())
    love.graphics.setColor(1, 1, 1, entrance_ease)
    
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
    
    -- Darker hover colors for each difficulty
    local button_colors_hover = {
        {0.18, 0.18, 0.7, 0.8},   -- Darker blue for EASY
        {0.75, 0.6, 0.15, 0.8},   -- Darker gold for MEDIUM
        {0.75, 0.15, 0.15, 0.8}   -- Darker red for HARD
    }
    
    -- Get mouse position for hover detection
    local mouse_x, mouse_y = love.mouse.getPosition()
    
    for i, diff in ipairs(difficulties) do
        local button_x = buttons_start_x + (i - 1) * button_spacing
        
        -- Check if button is hovered
        local is_button_hovered = mouse_x >= button_x and mouse_x <= button_x + button_width and
                                   mouse_y >= button_y and mouse_y <= button_y + button_height
        
        -- Highlight selected difficulty
        if Difficulty.get() == diff then
            -- Use hover color if hovered, otherwise use regular color
            local color = is_button_hovered and button_colors_hover[i] or button_colors[i]
            love.graphics.setColor(color[1], color[2], color[3], color[4] * entrance_ease)
            love.graphics.setLineWidth(4)
        else
            -- Greyed out when not selected, but still darken on hover
            if is_button_hovered then
                love.graphics.setColor(0.4, 0.4, 0.4, 0.8 * entrance_ease)  -- Darker grey on hover
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 0.8 * entrance_ease)  -- Regular grey when not selected
            end
            love.graphics.setLineWidth(2)
        end
        
        -- Draw button background
        love.graphics.rectangle("fill", button_x, button_y, button_width, button_height)
        
        -- Draw button border
        love.graphics.setColor(1, 1, 1, entrance_ease)
        love.graphics.rectangle("line", button_x, button_y, button_width, button_height)
        love.graphics.setLineWidth(1)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, entrance_ease)
        love.graphics.setFont(love.graphics.getFont())
        local text_w = love.graphics.getFont():getWidth(diff)
        love.graphics.print(diff, button_x + button_width / 2 - text_w / 2, button_y + button_height / 2 - 8)
    end
    
    -- Draw Prompt
    love.graphics.setFont(HomeMenu.fonts.prompt)
    local prompt_text = StartScreen.PROMPT_TEXT
    local pw = HomeMenu.fonts.prompt:getWidth(prompt_text)
    local px = w / 2 - pw / 2 + 50 + entrance_offset
    local py = h * 0.65
    
    -- Pulsing alpha effect for prompt
    local pulse_alpha = (0.5 + 0.5 * math.sin(love.timer.getTime() * 4)) * entrance_ease
    love.graphics.setColor(1, 1, 1, pulse_alpha)
    love.graphics.print(prompt_text, px, py)
    
    -- Instructions - Selection message
    love.graphics.setColor(1.0, 0.8, 0.2, entrance_ease)
    local inst_font = love.graphics.newFont("splashfont.otf", 14)
    love.graphics.setFont(inst_font)
    local inst_text = "SELECT A DIFFICULTY AND KEEPSAKE TO START"
    local iw = inst_font:getWidth(inst_text)
    love.graphics.print(inst_text, w / 2 - iw / 2 + 50, h * 0.8)
    
    -- Draw START button (always visible)
    local button_x = w / 2 - 200 + 50 + entrance_offset
    local button_y = h * 0.48 - 20
    local button_w = 400
    local button_h = 120
    
    local is_enabled = Difficulty.is_selected() and Keepsakes.get()
    
    -- Check if START button is hovered
    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_button_hovered = mouse_x >= button_x and mouse_x <= button_x + button_w and
                               mouse_y >= button_y and mouse_y <= button_y + button_h
    
    if is_enabled then
        -- Green enabled button - darken on hover
        if is_button_hovered then
            love.graphics.setColor(0.15, 0.6, 0.15, 0.9 * entrance_ease)  -- Darker green on hover
        else
            love.graphics.setColor(0.2, 0.8, 0.2, 0.9 * entrance_ease)
        end
        love.graphics.rectangle("fill", button_x, button_y, button_w, button_h)
        love.graphics.setColor(0.5, 1.0, 0.5, entrance_ease)
    else
        -- Grey disabled button
        love.graphics.setColor(0.3, 0.3, 0.3, 0.6 * entrance_ease)
        love.graphics.rectangle("fill", button_x, button_y, button_w, button_h)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.6 * entrance_ease)
    end
    
    -- Button border
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, entrance_ease)
    love.graphics.rectangle("line", button_x, button_y, button_w, button_h)
    love.graphics.setLineWidth(1)
    
    -- Button text
    if is_enabled then
        love.graphics.setColor(1, 1, 1, entrance_ease)
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 0.6 * entrance_ease)
    end
    love.graphics.setFont(HomeMenu.fonts.start_button)
    local start_text = "START"
    local text_w = HomeMenu.fonts.start_button:getWidth(start_text)
    local text_h = HomeMenu.fonts.start_button:getHeight()
    love.graphics.print(start_text, button_x + button_w / 2 - text_w / 2, button_y + button_h / 2 - text_h / 2)
    

    -- Draw smaller shop seed UI below the instructions
    local inst_font = love.graphics.newFont("splashfont.otf", 14)
    local inst_text = "SELECT A DIFFICULTY AND KEEPSAKE TO START"
    local inst_w = inst_font:getWidth(inst_text)
    local inst_x = w / 2 - inst_w / 2 + 50
    local inst_y = h * 0.8

    local seed_x = inst_x
    local seed_y = inst_y + 30
    local cb_size = 16
    local input_w = 160
    local input_h = 22

    -- Checkbox (smaller)
    love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
    love.graphics.rectangle("fill", seed_x, seed_y, cb_size, cb_size, 3, 3)
    if shop_seed_enabled then
        love.graphics.setColor(0.2, 0.9, 0.2, 1)
        love.graphics.rectangle("fill", seed_x + 3, seed_y + 3, cb_size - 6, cb_size - 6, 2, 2)
    end
    love.graphics.setColor(1, 1, 1, entrance_ease)
    love.graphics.setFont(love.graphics.newFont("splashfont.otf", 12))
    love.graphics.print("Seeded Shops", seed_x + cb_size + 8, seed_y - 2)

    -- Seed input box (smaller)
    local input_x = seed_x
    local input_y = seed_y + cb_size + 6
    love.graphics.setColor(0.05, 0.05, 0.05, 0.95)
    love.graphics.rectangle("fill", input_x, input_y, input_w, input_h, 3, 3)
    love.graphics.setLineWidth(1)
    if shop_seed_focused then
        love.graphics.setColor(0.9, 0.9, 0.2, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
    end
    love.graphics.rectangle("line", input_x, input_y, input_w, input_h, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
    local display_text
    if shop_seed_enabled then
        display_text = shop_seed_value ~= "" and shop_seed_value or "enter seed"
    else
        -- Show a shuffling random string when seeded shops is not selected.
        local t = love.timer.getTime()
        local period = 0.12
        local seed = math.floor(t / period)
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local localseed = (seed % 2147483646) + 1
        local s = ""
        for i = 1, 8 do
            localseed = (localseed * 16807) % 2147483647
            local idx = (localseed % #chars) + 1
            s = s .. chars:sub(idx, idx)
        end
        display_text = s
    end
    love.graphics.setFont(love.graphics.newFont("splashfont.otf", 12))
    love.graphics.print(display_text, input_x + 6, input_y + 3)

    love.graphics.pop()
end

-- Check if difficulty button was clicked
function HomeMenu.check_difficulty_click(x, y)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    local button_y = h * 0.32
    local button_spacing = 110
    local button_width = 100
    local button_height = 45
    local buttons_start_x = w / 2 - 110
    
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

-- Check seed checkbox and input clicks
function HomeMenu.check_seed_click(x, y)
    local w = Config.GAME_WIDTH
    local h = Config.GAME_HEIGHT
    local inst_font = love.graphics.newFont("splashfont.otf", 14)
    local inst_text = "SELECT A DIFFICULTY AND KEEPSAKE TO START"
    local inst_w = inst_font:getWidth(inst_text)
    local inst_x = w / 2 - inst_w / 2 + 50
    local inst_y = h * 0.8
    local seed_x = inst_x
    local seed_y = inst_y + 30
    local cb_x = seed_x
    local cb_y = seed_y
    local cb_size = 16

    -- Click toggle checkbox
    if x >= cb_x and x <= cb_x + cb_size and y >= cb_y and y <= cb_y + cb_size then
        shop_seed_enabled = not shop_seed_enabled
        print(string.format("[HOME_MENU] shop_seed_enabled toggled -> %s", tostring(shop_seed_enabled)))
        return true
    end

    -- Click input box (smaller)
    local input_x = cb_x
    local input_y = cb_y + cb_size + 6
    local input_w = 160
    local input_h = 22
    if x >= input_x and x <= input_x + input_w and y >= input_y and y <= input_y + input_h then
        shop_seed_focused = true
        print("[HOME_MENU] shop_seed input focused")
        return true
    else
        shop_seed_focused = false
    end

    return false
end

-- Handle key input for seed entry
function HomeMenu.keypressed(key)
    if shop_seed_focused then
        if key == "backspace" then
            -- remove last char
            shop_seed_value = shop_seed_value:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            shop_seed_focused = false
        else
            -- Accept digits and minus
            if key:match("^%d$") or key == "-" then
                shop_seed_value = shop_seed_value .. key
            end
        end
        return true
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
    -- Account for menu entrance/exit horizontal translation so clicks match drawn grid
    local grid_start_x = w * 0.02
    local grid_start_y = h * 0.25 + 50

    local entrance_progress = menu_entrance_duration > 0 and (menu_entrance_timer / menu_entrance_duration) or 1
    local entrance_ease = 1 - (1 - entrance_progress) ^ 3
    local entrance_offset = (1 - entrance_ease) * w

    local exit_progress = menu_exit_duration > 0 and (menu_exit_timer / menu_exit_duration) or 0
    local exit_ease = exit_progress * exit_progress
    local exit_slide_offset = exit_ease * w

    local menu_offset = entrance_offset - exit_slide_offset
    grid_start_x = grid_start_x + menu_offset

    return Keepsakes.check_click(x, y, grid_start_x, grid_start_y, 96, 32)
end

-- Draw keepsake tooltip on hover
function HomeMenu.draw_keepsake_tooltip(hovered_id, keepsake_x, keepsake_y, item_size, item_h)
    if not hovered_id then return end

    local def = Keepsakes.get_definition(hovered_id)
    if not def then return end

    local game_w, game_h = Config.GAME_WIDTH, Config.GAME_HEIGHT

    -- Use provided bounding box (keepsake_x, keepsake_y, item_size)
    item_size = item_size or 96
    local keepsake_center_x = (keepsake_x or 0) + item_size / 2

    -- Position tooltip above the keepsake item, centered
    local tooltip_width = 280
    local tooltip_height = 125
    local padding = 10

    local tooltip_x = keepsake_center_x - tooltip_width / 2
    local tooltip_y = (keepsake_y or 0) - tooltip_height
    
    -- Keep tooltip on screen before applying drift
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > game_w - 10 then
        tooltip_x = game_w - tooltip_width - 10
    end
    if tooltip_y < 20 then  -- Larger margin to account for drift
        tooltip_y = keepsake_y + item_size + 15
    end
    
    -- Add sinusoidal drift
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
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
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    -- Check if tooltip is a table with benefit/downside
    if type(def.tooltip) == "table" and def.tooltip.benefit then
        -- Draw benefit line in green
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.print(def.tooltip.benefit, tooltip_x + padding, tooltip_y + padding + 25)
        
        -- Draw downside line in magenta
        love.graphics.setColor(1, 0.2, 1, 1)
        love.graphics.print(def.tooltip.downside, tooltip_x + padding, tooltip_y + padding + 42)
        
        -- Draw flavor line in orange
        if def.tooltip.flavor then
            love.graphics.setColor(1, 0.7, 0.2, 1)
            love.graphics.setFont(effects_font)
            -- Wrap flavor text if needed
            local max_width = tooltip_width - padding * 2
            local wrapped = {}
            local words = {}
            for word in def.tooltip.flavor:gmatch("%S+") do
                table.insert(words, word)
            end
            local current_line = ""
            for _, word in ipairs(words) do
                local test_line = current_line == "" and word or current_line .. " " .. word
                if effects_font:getWidth(test_line) > max_width then
                    if current_line ~= "" then
                        table.insert(wrapped, current_line)
                        current_line = word
                    else
                        table.insert(wrapped, word)
                        current_line = ""
                    end
                else
                    current_line = test_line
                end
            end
            if current_line ~= "" then
                table.insert(wrapped, current_line)
            end
            for i, line in ipairs(wrapped) do
                love.graphics.print(line, tooltip_x + padding, tooltip_y + padding + 60 + (i-1) * 12)
            end
        end
    else
        -- Fallback for old string tooltips
        local effects_text = def.tooltip or ""
        if effects_text == "" then
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
        end
        
        if effects_text == "" then
            effects_text = "No major effects"
        end
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print(effects_text, tooltip_x + padding, tooltip_y + padding + 25)
    end
end

-- Check if mouse is hovering over the lucky box during gameplay
function HomeMenu.get_lucky_box_hover(mouse_x, mouse_y)
    local UIConfig = require("ui.ui_config")
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
    
    local UIConfig = require("ui.ui_config")
    local Config = require("conf")
    local game_w, game_h = Config.GAME_WIDTH, Config.GAME_HEIGHT
    
    -- Calculate lucky box position (same as in get_lucky_box_hover)
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local lucky_x = Config.BUTTON_START_X
    local lucky_y = box_y
    local lucky_center_x = lucky_x + UIConfig.LUCKY_BOX_WIDTH / 2
    
    -- Position tooltip above the lucky box, centered
    local tooltip_width = 250
    local tooltip_height = 100
    local padding = 10
    
    local tooltip_x = lucky_center_x - tooltip_width / 2
    local tooltip_y = lucky_y - tooltip_height - 15
    
    -- Keep tooltip on screen before applying drift
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > game_w - 10 then
        tooltip_x = game_w - tooltip_width - 10
    end
    if tooltip_y < 20 then  -- Larger margin to account for drift
        tooltip_y = lucky_y + UIConfig.LUCKY_BOX_HEIGHT + 15
    end
    
    -- Add sinusoidal drift
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
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
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    -- Check if tooltip is a table with benefit/downside
    if type(def.tooltip) == "table" and def.tooltip.benefit then
        -- Draw benefit line in green
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.print(def.tooltip.benefit, tooltip_x + padding, tooltip_y + padding + 25)
        
        -- Draw downside line in magenta
        love.graphics.setColor(1, 0.2, 1, 1)
        love.graphics.print(def.tooltip.downside, tooltip_x + padding, tooltip_y + padding + 42)
        
        -- Draw flavor line in orange
        if def.tooltip.flavor then
            love.graphics.setColor(1, 0.7, 0.2, 1)
            love.graphics.setFont(effects_font)
            -- Wrap flavor text if needed
            local max_width = tooltip_width - padding * 2
            local wrapped = {}
            local words = {}
            for word in def.tooltip.flavor:gmatch("%S+") do
                table.insert(words, word)
            end
            local current_line = ""
            for _, word in ipairs(words) do
                local test_line = current_line == "" and word or current_line .. " " .. word
                if effects_font:getWidth(test_line) > max_width then
                    if current_line ~= "" then
                        table.insert(wrapped, current_line)
                        current_line = word
                    else
                        table.insert(wrapped, word)
                        current_line = ""
                    end
                else
                    current_line = test_line
                end
            end
            if current_line ~= "" then
                table.insert(wrapped, current_line)
            end
            for i, line in ipairs(wrapped) do
                love.graphics.print(line, tooltip_x + padding, tooltip_y + padding + 57 + (i - 1) * 12)
            end
        end
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("No tooltip available", tooltip_x + padding, tooltip_y + padding + 25)
    end
end

return HomeMenu
