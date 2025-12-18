-- upgrade_tooltips.lua
-- Isolated tooltip system for upgrade sprites
-- Handles all tooltip drawing for both shop and purchased upgrades

local Config = require("conf")
local UpgradeNode = require("systems.upgrade_node")

local UpgradeTooltips = {}

-- Rarity color mapping
local RARITY_COLORS = {
    Standard = {0.7, 0.7, 0.7},        -- Gray
    Premium = {0.2, 0.7, 1},           -- Cyan/Blue
    ["High-Roller"] = {1, 0.85, 0.2},  -- Gold/Yellow
    VIP = {0.9, 0.3, 0.8}              -- Magenta/Purple
}

-- Track tooltip states
local active_tooltips = {}  -- Table of currently active tooltips

-- Draw tooltip for an upgrade sprite
function UpgradeTooltips.draw_tooltip(sprite, sprite_x, sprite_y, sprite_width, sprite_height)
    if not sprite then
        return false
    end
    
    local upgrade_id = sprite.upgrade_id
    local def = UpgradeNode.get_definition(upgrade_id)
    
    if not def then
        return false
    end
    
    -- Sprite center position
    local sprite_center_x = sprite_x + sprite_width / 2
    local sprite_top_y = sprite_y
    
    -- Tooltip dimensions
    local tooltip_width = 280
    local tooltip_height = 145
    local padding = 10
    
    -- Position tooltip above sprite, centered
    local tooltip_x = sprite_center_x - tooltip_width / 2
    local tooltip_y = sprite_top_y - tooltip_height - 12 + (tooltip_height * 0.25)
    
    -- Keep tooltip on screen horizontally
    if tooltip_x < 10 then
        tooltip_x = 10
    elseif tooltip_x + tooltip_width > Config.GAME_WIDTH - 10 then
        tooltip_x = Config.GAME_WIDTH - tooltip_width - 10
    end
    
    -- Add sinusoidal drift for visual interest
    local drift_x = math.sin(love.timer.getTime() * 2) * 8
    local drift_y = math.sin(love.timer.getTime() * 1.5 + 1) * 6
    tooltip_x = tooltip_x + drift_x
    tooltip_y = tooltip_y + drift_y
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    
    -- Get rarity color for border
    local rarity_color = RARITY_COLORS[def.rarity] or RARITY_COLORS["Standard"]
    love.graphics.setColor(rarity_color[1], rarity_color[2], rarity_color[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height, 5, 5)
    love.graphics.setLineWidth(1)
    
    -- Draw name (title) and rarity
    love.graphics.setColor(1, 0.8, 0.2, 1)
    local name_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(name_font)
    love.graphics.print(def.name, tooltip_x + padding, tooltip_y + padding)
    
    -- Draw rarity in color-coded text next to name
    local rarity_color = RARITY_COLORS[def.rarity] or RARITY_COLORS["Standard"]
    love.graphics.setColor(rarity_color[1], rarity_color[2], rarity_color[3], 1)
    local small_font = love.graphics.newFont("splashfont.otf", 10)
    love.graphics.setFont(small_font)
    love.graphics.print("[" .. def.rarity .. "]", tooltip_x + padding + name_font:getWidth(def.name) + 8, tooltip_y + padding + 4)
    
    -- Draw effects text
    local effects_font = love.graphics.newFont("splashfont.otf", 11)
    love.graphics.setFont(effects_font)
    
    -- Draw benefit line in green
    love.graphics.setColor(0.2, 1, 0.2, 1)
    love.graphics.print(def.benefit, tooltip_x + padding, tooltip_y + padding + 25)
    
    -- Draw downside line in magenta
    love.graphics.setColor(1, 0.2, 1, 1)
    love.graphics.print(def.downside, tooltip_x + padding, tooltip_y + padding + 42)
    
    -- Draw flavor text in orange (with word wrapping)
    if def.flavor then
        love.graphics.setColor(1, 0.7, 0.2, 1)
        love.graphics.setFont(effects_font)
        
        local max_width = tooltip_width - padding * 2
        local wrapped_lines = {}
        local words = {}
        
        -- Split flavor into words
        for word in def.flavor:gmatch("%S+") do
            table.insert(words, word)
        end
        
        -- Wrap words to fit width
        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or current_line .. " " .. word
            if effects_font:getWidth(test_line) > max_width then
                if current_line ~= "" then
                    table.insert(wrapped_lines, current_line)
                end
                current_line = word
            else
                current_line = test_line
            end
        end
        
        if current_line ~= "" then
            table.insert(wrapped_lines, current_line)
        end
        
        -- Draw wrapped lines
        for i, line in ipairs(wrapped_lines) do
            love.graphics.print(line, tooltip_x + padding, tooltip_y + padding + 57 + (i - 1) * 15)
        end
    end
    
    return true
end

-- Draw all active tooltips for sprites in a position list
function UpgradeTooltips.draw_all(upgrade_box_positions)
    if not upgrade_box_positions then
        return
    end
    
    for _, box in ipairs(upgrade_box_positions) do
        -- Only draw tooltips for sprites that are NOT animating
        -- Skip "purchasing" and "shifting" states - no tooltips during animations
        if box.sprite and box.sprite.is_hovered and 
           box.sprite.state ~= "purchasing" and box.sprite.state ~= "shifting" then
            UpgradeTooltips.draw_tooltip(box.sprite, box.x, box.y, box.width, box.height)
        end
    end
end

-- Clear tooltip tracking (call on state change)
function UpgradeTooltips.clear()
    active_tooltips = {}
end

return UpgradeTooltips
