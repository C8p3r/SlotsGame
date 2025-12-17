-- shop.lua
-- Shop menu system for round progression and spin allocation
local Config = require("conf")
local UIConfig = require("ui/ui_config")
local UpgradeNode = require("upgrade_node")

local Shop = {}

-- Shop state
local is_open = false
local current_round = 0
local spins_remaining = 0
local balance_goal = 0
local spins_per_round = 10
local base_balance_goal = 1000
local goal_multiplier = 1.5  -- Increase goal by 50% each round

-- Shop animation state
local shop_entrance_timer = 0
local shop_entrance_duration = 0.6
local is_shop_entering = false
local is_shop_closing = false

-- Gems currency (secondary currency in shops)
local gems = 0
local gems_gained = 0  -- Gems gained in the current round
local conversion_rate = 1  -- 1 excess spin = 1 gem
local converting_gems = 0  -- Gems currently being converted (animated)
local gem_conversion_timer = 0
local gem_conversion_duration = 0.5

-- Shop menu dimensions
local SHOP_W = Config.GAME_WIDTH * 0.77  -- Wide to cover all slots
local SHOP_H = Config.GAME_HEIGHT * 0.5
local SHOP_X = (Config.GAME_WIDTH - SHOP_W) / 2
local SHOP_Y = (Config.GAME_HEIGHT - SHOP_H) / 2 + 92  -- Move down 100px

-- UI Assets
local ui_assets = nil
local gem_icon_quad = nil  -- Second row, second column quad
local upgrade_units_image = nil
local upgrade_units_quads = {}  -- Table to store all upgrade icon quads

-- Load UI assets for gem icon
local function load_ui_assets()
    if not ui_assets then
        ui_assets = love.graphics.newImage("assets/UI_assets.png")
        -- Assuming 4 columns per row, second row second column = quad index 6
        -- Row 2, Col 2: (row-1) * cols + col = (2-1) * 4 + 2 = 6
        local quad_width = 32
        local quad_height = 32
        local cols = 4
        local col = 2
        local row = 2
        local x = (col - 1) * quad_width
        local y = (row - 1) * quad_height
        gem_icon_quad = love.graphics.newQuad(x, y, quad_width, quad_height, ui_assets:getDimensions())
    end
    
    -- Load upgrade units image
    if not upgrade_units_image then
        upgrade_units_image = love.graphics.newImage("assets/upgrade_units_UI.png")
        upgrade_units_image:setFilter("nearest", "nearest")  -- Crisp pixel rendering
        
        -- Create quads for all 32x32 icons from the 160x320 grid
        local icon_size = 32
        local cols = 5  -- 160 / 32 = 5 columns
        local rows = 10  -- 320 / 32 = 10 rows
        
        for row = 0, rows - 1 do
            for col = 0, cols - 1 do
                local x = col * icon_size
                local y = row * icon_size
                table.insert(upgrade_units_quads, love.graphics.newQuad(x, y, icon_size, icon_size, upgrade_units_image:getDimensions()))
            end
        end
    end
end

function Shop.initialize(initial_bankroll)
    current_round = 1
    spins_remaining = spins_per_round
    balance_goal = base_balance_goal
    is_open = false
    print("[SHOP.INITIALIZE] Shop initialized! spins_remaining: " .. spins_remaining .. ", balance_goal: " .. balance_goal)
end

function Shop.start_new_round()
    current_round = current_round + 1
    spins_remaining = spins_per_round
    balance_goal = math.floor(base_balance_goal * (goal_multiplier ^ (current_round - 1)))
    is_open = true
    
    -- Reset the balance to initial amount for the new round
    local SlotMachine = require("slot_machine")
    local state = SlotMachine.getState()
    state.bankroll = Config.INITIAL_BANKROLL
end

function Shop.open()
    is_open = true
    is_shop_entering = true
    is_shop_closing = false
    shop_entrance_timer = 0
    
    -- Generate 3 random upgrades for this shop session
    UpgradeNode.generate_shop_upgrades()
    
    -- Convert excess spins to gems immediately
    local excess_spins = spins_remaining - 0  -- All remaining spins after round ends become gems
    if excess_spins > 0 then
        gems_gained = excess_spins * conversion_rate
        gems = gems + gems_gained
        print("[SHOP] Added " .. gems_gained .. " gems! Total gems: " .. gems)
    else
        gems_gained = 0
    end
end

function Shop.close()
    is_shop_closing = true
    is_shop_entering = false
    shop_entrance_timer = shop_entrance_duration  -- Start from end, count down
end

function Shop.is_open()
    return is_open or is_shop_entering or is_shop_closing
end

function Shop.get_spins_remaining()
    return spins_remaining
end

function Shop.get_gems()
    return gems
end

function Shop.reset_gems()
    gems = 0
    converting_gems = 0
    gem_conversion_timer = 0
    print("[SHOP] Gems reset to 0")
end

function Shop.update(dt)
    -- No gem conversion animation needed
end

function Shop.use_spin()
    print("[SHOP.USE_SPIN] Called! Current spins_remaining: " .. spins_remaining)
    if spins_remaining > 0 then
        spins_remaining = spins_remaining - 1
        print("[SHOP.USE_SPIN] Spin used! New spins_remaining: " .. spins_remaining)
        return true
    end
    print("[SHOP.USE_SPIN] No spins available! spins_remaining: " .. spins_remaining)
    return false
end

function Shop.get_balance_goal()
    return balance_goal
end

function Shop.get_current_round()
    return current_round
end

function Shop.get_spins_per_round()
    return spins_per_round
end

function Shop.update(dt)
    -- Update shop animation
    if is_shop_entering then
        shop_entrance_timer = shop_entrance_timer + dt
        if shop_entrance_timer >= shop_entrance_duration then
            shop_entrance_timer = shop_entrance_duration
            is_shop_entering = false
        end
    elseif is_shop_closing then
        shop_entrance_timer = shop_entrance_timer - dt
        if shop_entrance_timer <= 0 then
            shop_entrance_timer = 0
            is_shop_closing = false
            is_open = false
        end
    end
end

function Shop.check_next_button_click(x, y)
    local button_width = 200
    local button_height = 50
    local button_x = SHOP_X + (SHOP_W - button_width) / 2
    local button_y = SHOP_Y + SHOP_H - 330  -- Moved up 250px total
    
    return x >= button_x and x <= button_x + button_width and
           y >= button_y and y <= button_y + button_height
end

-- Check which upgrade box was clicked (1-3)
function Shop.check_upgrade_box_click(x, y)
    local box_width = 200
    local box_height = 150
    local stats_y = SHOP_Y + 80
    local line_height = 30
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200  -- Center the 3 boxes, moved left 200px total
    local box_gap = 20
    
    for i = 1, 3 do
        local box_x = box_start_x + (i - 1) * (box_width + box_gap)
        if x >= box_x and x <= box_x + box_width and
           y >= box_y_pos and y <= box_y_pos + box_height then
            return i, box_x + box_width / 2, box_y_pos + box_height / 2
        end
    end
    return nil
end

-- Helper function to draw text with wavy/jumping effect
local function draw_wavy_shop_text(text, x, y, font, color)
    if not text or text == "" then return end
    love.graphics.setFont(font)
    love.graphics.setColor(color)
    local time = love.timer.getTime()
    
    -- Intermittent effect - only apply when this oscillates
    local effect_intensity = math.max(0, math.sin(time * 1.5))  -- Turns on/off in cycles
    
    -- Only draw with wavy effect if intensity > 0.2
    if effect_intensity < 0.2 then
        -- Draw normal text when effect is off
        love.graphics.print(text, x, y)
        return
    end
    
    local cursor_x = x
    local base_y = y
    local frequency = 0.6  -- Much shorter wavelength
    local speed = 4.0      -- How fast the wave moves
    local amplitude = 2.0 * effect_intensity  -- Amplitude scales with effect intensity
    
    for i = 1, #text do
        local char = text:sub(i, i)
        -- Create a jumping effect where letters jump one at a time
        local wave_y = math.sin(time * speed + i * frequency) * amplitude
        love.graphics.print(char, cursor_x, base_y + wave_y)
        cursor_x = cursor_x + font:getWidth(char)
    end
end

function Shop.draw(current_bankroll, SlotMachine)
    if not is_open and not is_shop_entering and not is_shop_closing then return end
    
    load_ui_assets()  -- Ensure UI assets are loaded
    
    -- Calculate slide animation (0 to 1 for entrance, 1 to 0 for exit)
    local animation_progress = shop_entrance_duration > 0 and (shop_entrance_timer / shop_entrance_duration) or 1
    -- Easing: ease-out cubic for entrance
    local ease_progress = 1 - (1 - animation_progress) ^ 3
    
    -- Slide up from bottom: start below screen, slide to final position
    local slide_offset = (1 - ease_progress) * Config.GAME_HEIGHT
    
    love.graphics.push()
    
    -- Apply slide animation translation
    love.graphics.translate(0, slide_offset)
    
    -- Draw shop menu background (no background overlay)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", SHOP_X, SHOP_Y, SHOP_W, SHOP_H, 10, 10)
    
    -- Draw border
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", SHOP_X, SHOP_Y, SHOP_W, SHOP_H, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Draw title
    love.graphics.setColor(1, 1, 0, 1)
    local title_font = love.graphics.newFont("splashfont.otf", 28)
    love.graphics.setFont(title_font)
    local title = "ROUND " .. current_round
    local title_w = title_font:getWidth(title)
    love.graphics.print(title, SHOP_X + (SHOP_W - title_w) / 2, SHOP_Y + 20)
    
    -- Draw stats section
    love.graphics.setColor(1, 1, 1, 1)
    local stats_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(stats_font)
    
    local stats_x = SHOP_X + 40
    local stats_y = SHOP_Y + 80
    local line_height = 30
    
    -- Spins remaining
    love.graphics.setColor(0.2, 1, 0.2, 1)  -- Green
    love.graphics.print("SPINS REMAINING: " .. spins_remaining, stats_x, stats_y)
    
    -- Current balance
    love.graphics.setColor(0.8, 0.8, 0.2, 1)  -- Gold
    love.graphics.print("CURRENT BALANCE: $" .. string.format("%.0f", current_bankroll), stats_x, stats_y + line_height)
    
    -- Next balance goal (for the upcoming round)
    local next_balance_goal = math.floor(base_balance_goal * (goal_multiplier ^ current_round))
    love.graphics.setColor(1, 0.4, 0.4, 1)  -- Red/Pink
    love.graphics.print("NEXT GOAL: $" .. string.format("%.0f", next_balance_goal), stats_x, stats_y + line_height * 2)
    
    -- Gems gained this round
    if gems_gained > 0 then
        love.graphics.setColor(0.2, 1, 0.8, 1)  -- Bright cyan
        love.graphics.print("GEMS GAINED: +" .. gems_gained, stats_x, stats_y + line_height * 3)
    end
    
    -- Draw 3 display boxes (same size as game display boxes)
    local box_width = 200
    local box_height = 150
    local box_y_pos = stats_y + line_height * 4 + 20
    local box_start_x = SHOP_X + (SHOP_W - (box_width * 3 + 20 * 2)) / 2 - 200  -- Center the 3 boxes, moved left 200px total
    local box_gap = 20
    
    -- Calculate the total span box dimensions
    local total_box_width = (box_width * 3) + (box_gap * 2)
    local large_box_x = box_start_x
    local large_box_y = box_y_pos
    
    -- Draw one large box spanning all 3 upgrade positions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", large_box_x, large_box_y, total_box_width, box_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Get mouse position for hover detection
    local mouse_x, mouse_y = love.mouse.getPosition()
    local hovered_box = nil
    
    for i = 1, 3 do
        local box_x = box_start_x + (i - 1) * (box_width + box_gap)
        local is_hovered = mouse_x >= box_x and mouse_x <= box_x + box_width and
                           mouse_y >= box_y_pos and mouse_y <= box_y_pos + box_height
        
        if is_hovered then
            hovered_box = i
        end
        
        -- Draw transparent center area for icon positioning
        local center_x = box_x + box_width / 2
        local center_y = box_y_pos + box_height / 2
        local actual_icon_size = 128  -- 32 pixels * 4 scale
        local icon_x = center_x - actual_icon_size / 2
        local icon_y = center_y - actual_icon_size / 2
        
        -- Add sinusoidal drift animation (varies by box index)
        local drift_x = math.sin(love.timer.getTime() * 2 + i) * 8
        local drift_y = math.sin(love.timer.getTime() * 1.5 + i + 1) * 6
        icon_x = icon_x + drift_x
        icon_y = icon_y + drift_y
        
        -- Draw the assigned upgrade icon in the center
        local upgrade_id = UpgradeNode.get_box_upgrade(i)
        
        -- Check if this upgrade has been selected (currently flying or already in display box)
        local selected_upgrades = UpgradeNode.get_selected_upgrades()
        local is_selected = false
        for _, selected_id in ipairs(selected_upgrades) do
            if selected_id == upgrade_id then
                is_selected = true
                break
            end
        end
        
        -- Also check if it's currently flying
        local flying_upgrades = UpgradeNode.get_flying_upgrades()
        for _, fly_upgrade in ipairs(flying_upgrades) do
            if fly_upgrade.upgrade_id == upgrade_id then
                is_selected = true
                break
            end
        end
        
        -- Only draw the upgrade icon if it hasn't been selected yet
        if upgrade_id and upgrade_units_image and upgrade_units_quads[upgrade_id] and not is_selected then
            local upgrade_quad = upgrade_units_quads[upgrade_id]
            love.graphics.setColor(1, 1, 1, 1)
            -- Scale the 32x32 icon to 128x128 (4x scale)
            love.graphics.draw(upgrade_units_image, upgrade_quad, icon_x, icon_y, 0, 4, 4)
        end
    end
    
    -- Store tooltip info for drawing after pop (to render on top)
    local tooltip_box_index = hovered_box
    local tooltip_box_start_x = box_start_x
    local tooltip_box_y_pos = box_y_pos
    local tooltip_box_width = box_width
    local tooltip_box_height = box_height
    local tooltip_box_gap = box_gap
    
    -- Draw NEXT ROUND button
    local button_width = 200
    local button_height = 50
    local button_x = SHOP_X + (SHOP_W - button_width) / 2
    local button_y = SHOP_Y + SHOP_H - 330  -- Moved up 250px total
    
    -- Check if button is hovered
    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_button_hovered = mouse_x >= button_x and mouse_x <= button_x + button_width and
                               mouse_y >= button_y and mouse_y <= button_y + button_height
    
    -- Button background - check if goal is met
    if current_bankroll >= next_balance_goal then
        if is_button_hovered then
            love.graphics.setColor(0.15, 0.75, 0.15, 0.8)  -- Darker green on hover
        else
            love.graphics.setColor(0.2, 1, 0.2, 0.8)  -- Green if goal met
        end
    else
        if is_button_hovered then
            love.graphics.setColor(0.3, 0.3, 0.3, 0.6)  -- Slightly darker grey on hover
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 0.6)  -- Greyed out if not
        end
    end
    love.graphics.rectangle("fill", button_x, button_y, button_width, button_height, 5, 5)
    
    -- Button border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button_x, button_y, button_width, button_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Button text
    love.graphics.setColor(1, 1, 1, 1)
    local button_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(button_font)
    local button_text = "NEXT ROUND"
    local button_text_w = button_font:getWidth(button_text)
    love.graphics.print(button_text, button_x + (button_width - button_text_w) / 2, button_y + (button_height - button_font:getHeight()) / 2)
    
    love.graphics.pop()
    
    -- Draw tooltip after pop so it renders on top of all other assets
    if tooltip_box_index then
        Shop.draw_upgrade_tooltip(tooltip_box_index, tooltip_box_start_x, tooltip_box_y_pos, tooltip_box_width, tooltip_box_height, tooltip_box_gap)
    end
end

-- Draw upgrade tooltip on hover
function Shop.draw_upgrade_tooltip(box_index, box_start_x, box_y_pos, box_width, box_height, box_gap)
    local upgrade_id = UpgradeNode.get_box_upgrade(box_index)
    if not upgrade_id then return end
    
    local def = UpgradeNode.get_definition(upgrade_id)
    if not def then return end
    
    local game_w, game_h = Config.GAME_WIDTH, Config.GAME_HEIGHT
    
    -- Calculate box center position
    local box_x = box_start_x + (box_index - 1) * (box_width + box_gap)
    local box_center_x = box_x + box_width / 2
    
    -- Position tooltip above the box, centered
    local tooltip_width = 280
    local tooltip_height = 125
    local padding = 10
    
    local tooltip_x = box_center_x - tooltip_width / 2
    local tooltip_y = box_y_pos - tooltip_height - 15
    
    -- Keep tooltip on screen before applying drift
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > game_w - 10 then
        tooltip_x = game_w - tooltip_width - 10
    end
    if tooltip_y < 20 then
        tooltip_y = box_y_pos + box_height + 15
    end
    
    -- Add sinusoidal drift (same as keepsake tooltips)
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(1, 0.8, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name
    love.graphics.setColor(1, 0.8, 0.2, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    love.graphics.print(def.name, tooltip_x + padding, tooltip_y + padding)
    
    -- Draw effects as text
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    -- Draw benefit line in green
    love.graphics.setColor(0.2, 1, 0.2, 1)
    love.graphics.print(def.benefit, tooltip_x + padding, tooltip_y + padding + 25)
    
    -- Draw downside line in magenta
    love.graphics.setColor(1, 0.2, 1, 1)
    love.graphics.print(def.downside, tooltip_x + padding, tooltip_y + padding + 42)
    
    -- Draw flavor line in orange
    if def.flavor then
        love.graphics.setColor(1, 0.7, 0.2, 1)
        love.graphics.setFont(effects_font)
        local max_width = tooltip_width - padding * 2
        local wrapped = {}
        local words = {}
        for word in def.flavor:gmatch("%S+") do
            table.insert(words, word)
        end
        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or current_line .. " " .. word
            if effects_font:getWidth(test_line) > max_width then
                table.insert(wrapped, current_line)
                current_line = word
            else
                current_line = test_line
            end
        end
        if current_line ~= "" then
            table.insert(wrapped, current_line)
        end
        
        for i, line in ipairs(wrapped) do
            love.graphics.print(line, tooltip_x + padding, tooltip_y + padding + 59 + (i - 1) * 14)
        end
    end
end

return Shop
