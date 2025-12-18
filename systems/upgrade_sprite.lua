-- upgrade_sprite.lua
-- Unified upgrade sprite system with state management
-- Manages a single sprite throughout its entire lifecycle: shop -> flying -> owned

local Config = require("conf")

local UpgradeSprite = {}

-- Sprite states:
-- "available" - displayed in shop, can be purchased
-- "purchasing" - flying from shop to display area
-- "owned" - in the display area, owned by player
-- "hovered" - owned and being hovered over (for tooltip display)

function UpgradeSprite.create(upgrade_id, state_name)
    state_name = state_name or "available"
    
    local sprite = {
        upgrade_id = upgrade_id,
        state = state_name,
        
        -- Position data
        x = 0,
        y = 0,
        
        -- Animation data
        animation_progress = 0,
        animation_duration = 0,
        start_x = 0,
        start_y = 0,
        target_x = 0,
        target_y = 0,
        
        -- Wobble offset (always applied)
        wobble_x = 0,
        wobble_y = 0,
        
        -- Display settings
        display_scale = 4,  -- 32x32 source becomes 128x128
        
        -- Ownership
        index = nil,  -- Position in owned upgrades list (1-5)
        
        -- UI state
        is_hovered = false,
        hover_start_time = 0
    }
    
    return sprite
end

-- Update sprite state and animation
function UpgradeSprite.update(sprite, dt)
    if sprite.state == "purchasing" then
        sprite.animation_progress = sprite.animation_progress + dt
        
        if sprite.animation_progress >= sprite.animation_duration then
            -- Animation complete, upgrade is now owned
            sprite.state = "owned"
            sprite.animation_progress = 0
            sprite.x = sprite.target_x
            sprite.y = sprite.target_y
        else
            -- Interpolate position
            local progress = sprite.animation_progress / sprite.animation_duration
            local eased = 1 - (1 - progress) ^ 3  -- Ease-out cubic
            sprite.x = sprite.start_x + (sprite.target_x - sprite.start_x) * eased
            sprite.y = sprite.start_y + (sprite.target_y - sprite.start_y) * eased
        end
    elseif sprite.state == "shifting" then
        sprite.animation_progress = sprite.animation_progress + dt
        
        if sprite.animation_progress >= sprite.animation_duration then
            -- Animation complete, upgrade is now owned at new position
            sprite.state = "owned"
            sprite.animation_progress = 0
            sprite.x = sprite.target_x
            sprite.y = sprite.target_y
        else
            -- Interpolate position
            local progress = sprite.animation_progress / sprite.animation_duration
            local eased = 1 - (1 - progress) ^ 3  -- Ease-out cubic
            sprite.x = sprite.start_x + (sprite.target_x - sprite.start_x) * eased
            sprite.y = sprite.start_y + (sprite.target_y - sprite.start_y) * eased
        end
    end
    
    -- Update wobble for any state that displays the sprite
    if sprite.state == "purchasing" or sprite.state == "owned" or sprite.state == "hovered" or sprite.state == "shifting" then
        UpgradeSprite.update_wobble(sprite)
    end
end

-- Update wobble effect based on upgrade_id
function UpgradeSprite.update_wobble(sprite)
    local time = love.timer.getTime()
    local seed = sprite.upgrade_id * 0.7
    sprite.wobble_x = math.sin(time * Config.DRIFT_SPEED + seed) * Config.DRIFT_RANGE
    sprite.wobble_y = math.cos(time * Config.DRIFT_SPEED * 0.8 + seed * 1.5) * Config.DRIFT_RANGE
end

-- Get the actual drawn position (x + wobble)
function UpgradeSprite.get_drawn_position(sprite)
    return sprite.x + sprite.wobble_x, sprite.y + sprite.wobble_y
end

-- Get bounding box for hover/click detection
function UpgradeSprite.get_bounding_box(sprite)
    if sprite.state == "available" then
        return nil  -- Shop handles its own hover detection
    end
    
    local drawn_x, drawn_y = UpgradeSprite.get_drawn_position(sprite)
    local icon_size = 32
    local size = icon_size * sprite.display_scale
    
    return drawn_x, drawn_y, size, size
end

-- Transition sprite to purchasing state
function UpgradeSprite.start_purchasing(sprite, start_x, start_y, target_x, target_y, duration)
    sprite.state = "purchasing"
    sprite.start_x = start_x
    sprite.start_y = start_y
    sprite.target_x = target_x
    sprite.target_y = target_y
    sprite.x = start_x
    sprite.y = start_y
    sprite.animation_duration = duration
    sprite.animation_progress = 0
end

-- Transition sprite to shifting state (rearranging in display)
function UpgradeSprite.start_shifting(sprite, target_x, target_y, duration)
    sprite.state = "shifting"
    sprite.start_x = sprite.x
    sprite.start_y = sprite.y
    sprite.target_x = target_x
    sprite.target_y = target_y
    sprite.animation_duration = duration
    sprite.animation_progress = 0
end

-- Transition sprite to owned state
function UpgradeSprite.set_owned(sprite, x, y, index)
    sprite.state = "owned"
    sprite.x = x
    sprite.y = y
    sprite.index = index
    sprite.animation_progress = 0
end

-- Set hover state
function UpgradeSprite.set_hovered(sprite, is_hovered)
    sprite.is_hovered = is_hovered
    if is_hovered then
        sprite.hover_start_time = love.timer.getTime()
        sprite.state = "hovered"
    else
        sprite.state = "owned"
    end
end

-- Draw the upgrade sprite
function UpgradeSprite.draw(sprite)
    if sprite.state == "available" then
        return  -- Shop handles its own drawing
    end
    
    local drawn_x, drawn_y = UpgradeSprite.get_drawn_position(sprite)
    
    -- Get upgrade icon quad
    local icon_size = 32
    local cols = 5
    local col = ((sprite.upgrade_id - 1) % cols)
    local row = math.floor((sprite.upgrade_id - 1) / cols)
    
    -- Load spritesheet (cached across calls)
    if not UpgradeSprite._upgrade_units_image then
        UpgradeSprite._upgrade_units_image = love.graphics.newImage("assets/upgrade_units_UI.png")
        UpgradeSprite._upgrade_units_image:setFilter("nearest", "nearest")
    end
    local upgrade_units_image = UpgradeSprite._upgrade_units_image
    
    local quad = love.graphics.newQuad(col * icon_size, row * icon_size, icon_size, icon_size, upgrade_units_image:getDimensions())
    
    -- Draw sprite
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(upgrade_units_image, quad, drawn_x, drawn_y, 0, sprite.display_scale, sprite.display_scale)
end

return UpgradeSprite
