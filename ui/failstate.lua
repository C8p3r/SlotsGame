-- failstate.lua
-- Menu displayed when player runs out of spins without reaching the goal
local Config = require("conf")
local UIConfig = require("ui/ui_config")

local Failstate = {}

-- Menu dimensions
local MENU_W = Config.GAME_WIDTH * 0.6
local MENU_H = Config.GAME_HEIGHT * 0.4
local MENU_X = (Config.GAME_WIDTH - MENU_W) / 2
local MENU_Y = (Config.GAME_HEIGHT - MENU_H) / 2

-- Button
local BUTTON_W = 300
local BUTTON_H = 60
local BUTTON_X = MENU_X + (MENU_W - BUTTON_W) / 2
local BUTTON_Y = MENU_Y + MENU_H - 100

-- Fonts
local title_font
local message_font
local button_font

-- State
local fade_alpha = 0
local fade_direction = 1  -- 1 for fading in, -1 for fading out
local fade_speed = 1.5
local is_fading_out = false
local menu_fade_complete = false  -- Track if menu has faded out

-- Animation state
local menu_entrance_timer = 0
local menu_entrance_duration = 0.6
local is_menu_entering = false
local is_menu_closing = false

-- Initialize fonts on first load
local function init_fonts()
    if not title_font then
        local font_file = "splashfont.otf"
        title_font = love.graphics.newFont(font_file, 48)
        message_font = love.graphics.newFont(font_file, 20)
        button_font = love.graphics.newFont(font_file, 24)
    end
end

function Failstate.initialize()
    fade_alpha = 0
    fade_direction = 1
    is_fading_out = false
    menu_fade_complete = false
    menu_entrance_timer = 0
    is_menu_entering = true
    is_menu_closing = false
end

function Failstate.update(dt)
    -- Update slide animation
    if is_menu_entering then
        menu_entrance_timer = menu_entrance_timer + dt
        if menu_entrance_timer >= menu_entrance_duration then
            menu_entrance_timer = menu_entrance_duration
            is_menu_entering = false
        end
    elseif is_menu_closing then
        menu_entrance_timer = menu_entrance_timer - dt
        if menu_entrance_timer <= 0 then
            menu_entrance_timer = 0
            is_menu_closing = false
        end
    end
    
    if not menu_fade_complete then
        -- Fade in/out animation for menu
        fade_alpha = fade_alpha + (fade_direction * fade_speed * dt)
        fade_alpha = math.max(0, math.min(1, fade_alpha))
        
        -- When menu has faded out, mark as complete
        if fade_alpha <= 0 and is_fading_out then
            menu_fade_complete = true
        end
    end
end

function Failstate.draw()
    init_fonts()
    
    -- Draw full-screen black overlay at full opacity (no fade out)
    love.graphics.setColor(0, 0, 0, 1.0)
    love.graphics.rectangle("fill", 0, 0, Config.GAME_WIDTH, Config.GAME_HEIGHT)
    
    -- Calculate slide animation (0 to 1 for entrance, 1 to 0 for exit)
    local animation_progress = menu_entrance_duration > 0 and (menu_entrance_timer / menu_entrance_duration) or 1
    -- Easing: ease-out cubic for entrance
    local ease_progress = 1 - (1 - animation_progress) ^ 3
    
    -- Slide down from top: start above screen, slide to final position
    local slide_offset = (1 - ease_progress) * -Config.GAME_HEIGHT
    
    -- Apply slide animation translation
    love.graphics.translate(0, slide_offset)
    
    -- Get mouse position for hover detection
    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_button_hovered = mouse_x >= BUTTON_X and mouse_x <= BUTTON_X + BUTTON_W and
                               mouse_y >= BUTTON_Y and mouse_y <= BUTTON_Y + BUTTON_H
    
    -- Only draw menu elements if menu is still visible
    if not menu_fade_complete then
        -- Menu box
        love.graphics.setColor(UIConfig.BOX_BACKGROUND_COLOR[1], UIConfig.BOX_BACKGROUND_COLOR[2], UIConfig.BOX_BACKGROUND_COLOR[3], fade_alpha)
        love.graphics.rectangle("fill", MENU_X, MENU_Y, MENU_W, MENU_H, UIConfig.BOX_CORNER_RADIUS)
        
        -- Border
        love.graphics.setColor(0.8, 0.2, 0.2, fade_alpha)  -- Red border
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", MENU_X, MENU_Y, MENU_W, MENU_H, UIConfig.BOX_CORNER_RADIUS)
        love.graphics.setLineWidth(1)
        
        -- Title
        love.graphics.setColor(1, 0.2, 0.2, fade_alpha)  -- Red title
        love.graphics.setFont(title_font)
        local title = "GAME OVER"
        local title_w = title_font:getWidth(title)
        love.graphics.print(title, MENU_X + (MENU_W - title_w) / 2, MENU_Y + 40)
        
        -- Message
        love.graphics.setColor(0.8, 0.8, 0.8, fade_alpha)
        love.graphics.setFont(message_font)
        local message = "thy art broke and hath no further motion!"
        local msg_w = message_font:getWidth(message)
        love.graphics.print(message, MENU_X + (MENU_W - msg_w) / 2, MENU_Y + 110)
        
        -- Draw button with hover darkening
        local button_color = {0.2, 0.2, 0.8, fade_alpha}
        local button_text_color = {1, 1, 1, fade_alpha}
        
        -- Darken button if hovered
        if is_button_hovered then
            button_color = {0.15, 0.15, 0.6, fade_alpha}
        end
        
        love.graphics.setColor(button_color)
        love.graphics.rectangle("fill", BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, 5)
        
        love.graphics.setColor(0.5, 0.5, 0.9, fade_alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, 5)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(button_text_color)
        love.graphics.setFont(button_font)
        local button_text = "COME BACK SOON"
        local btn_text_w = button_font:getWidth(button_text)
        love.graphics.print(button_text, BUTTON_X + (BUTTON_W - btn_text_w) / 2, BUTTON_Y + (BUTTON_H - button_font:getHeight()) / 2)
    end
end

function Failstate.check_button_click(x, y)
    return x >= BUTTON_X and x <= BUTTON_X + BUTTON_W and
           y >= BUTTON_Y and y <= BUTTON_Y + BUTTON_H
end

function Failstate.fade_out()
    is_fading_out = true
    fade_direction = -1
    is_menu_closing = true
    is_menu_entering = false
end

function Failstate.is_fade_complete()
    return menu_fade_complete and not is_menu_closing
end

return Failstate
