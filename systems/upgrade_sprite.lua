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
    -- Departing animation (fade + shrink) - marks sprite for removal when finished
    if sprite.state == "departing" then
        sprite.animation_progress = sprite.animation_progress + dt
        local dur = sprite.animation_duration or 0.35
        if sprite.animation_progress >= dur then
            sprite.to_remove = true
            sprite.display_alpha = 0
            sprite.current_pulse = 0
        else
            local p = math.max(0, math.min(1, sprite.animation_progress / dur))
            local eased = 1 - (1 - p) ^ 3
            sprite.display_alpha = 1 - eased
            sprite.current_pulse = 0.25 * (1 - eased) -- slight shrink while departing
        end
    end
    -- Update pulse animation (when triggered during scoring)
    if sprite.pulse_active then
        sprite.pulse_timer = sprite.pulse_timer + dt
        if sprite.pulse_timer >= (sprite.pulse_duration or 0.0) then
            sprite.pulse_active = false
            sprite.pulse_timer = 0
            sprite.current_pulse = 0
        else
            local p = sprite.pulse_timer / sprite.pulse_duration
            -- simple ease-out for pulse
            local eased = 1 - (1 - p) ^ 3
            sprite.current_pulse = eased * (sprite.pulse_scale_target - 1.0)
        end
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
    local pulse_mult = 1.0 + (sprite.current_pulse or 0)
    local size = icon_size * sprite.display_scale * pulse_mult
    
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

-- Start a visual pulse for this sprite (used during scoring triggers)
function UpgradeSprite.start_pulse(sprite, duration, scale_target)
    sprite.pulse_active = true
    sprite.pulse_duration = duration or 0.5
    sprite.pulse_timer = 0
    sprite.pulse_scale_target = scale_target or 1.5
    sprite.current_pulse = 0
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
    
    -- Draw sprite with pulse scaling from its visual center while preserving logical top-left coordinates
    local pulse_mult = 1.0 + (sprite.current_pulse or 0)
    local scale_x = sprite.display_scale * pulse_mult
    local scale_y = sprite.display_scale * pulse_mult
    local alpha = sprite.display_alpha or 1
    love.graphics.setColor(1, 1, 1, alpha)

    -- The stored sprite.x/sprite.y are top-left coordinates. To scale from the icon center
    -- we compute the visual center (top-left + half scaled size) and draw the quad with
    -- an origin offset of half the source icon (16,16). This keeps hitboxes unchanged.
    local size = icon_size * sprite.display_scale
    local center_x = drawn_x + size / 2
    local center_y = drawn_y + size / 2

    -- Apply inversion + strobe effect during pulse to match scoring slot icons
    local SlotMachine = nil
    local pulse_on = false
    if sprite.pulse_active and sprite.pulse_duration and sprite.pulse_duration > 0 then
        -- Compute eased progress (same easing used in update) so blink timing matches growth
        local t = sprite.pulse_timer or 0
        local p = 0
        if sprite.pulse_duration > 0 then p = math.max(0, math.min(1, t / sprite.pulse_duration)) end
        local eased = 1 - (1 - p) ^ 3

        -- Blink-style strobe synchronized to eased growth: 3 flips at even eased centers
        local flips = 3
        local threshold = 0.12 -- how wide (in eased-space) each blink is
        for i = 1, flips do
            local center = (i - 0.5) / flips
            if math.abs(eased - center) <= threshold then
                pulse_on = true
                break
            end
        end
    elseif (sprite.current_pulse or 0) > 0 then
        pulse_on = true
    end

    local shader_set = false
    -- Do NOT apply invert shader when the sprite is departing or scheduled for removal
    if pulse_on and sprite.state ~= "departing" and not sprite.to_remove then
        SlotMachine = require("game_mechanics.slot_machine")
        if SlotMachine and SlotMachine.state and SlotMachine.state.invert_shader then
            love.graphics.setShader(SlotMachine.state.invert_shader)
            shader_set = true
        end
    end

    love.graphics.draw(upgrade_units_image, quad, center_x, center_y, 0, scale_x, scale_y, icon_size / 2, icon_size / 2)

    if shader_set then
        love.graphics.setShader()
    end
end

return UpgradeSprite
