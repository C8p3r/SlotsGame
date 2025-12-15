-- keepsake_splashs.lua
-- Manages all keepsake splash effects and drawing

local Config = require("conf")
local UIConfig = require("ui/ui_config")

local KeepsakeSplash = {}

-- Trigger a keepsake splash effect
function KeepsakeSplash.trigger(state, effect_type, effect_value)
    local Keepsakes = require("keepsakes")
    local custom_splash_text = Keepsakes.get_splash_text()
    local splash_timing = Keepsakes.get_splash_timing()
    
    local effect_text = ""
    -- Use custom splash text if available, otherwise use generic text
    if custom_splash_text and custom_splash_text ~= "" then
        effect_text = custom_splash_text
    else
        if effect_type == "win_multiplier" then
            effect_text = string.format("KEEPSAKE +%.0f%%", (effect_value - 1.0) * 100)
        elseif effect_type == "spin_cost_multiplier" then
            local reduction = (1.0 - effect_value) * 100
            effect_text = string.format("KEEPSAKE -%.0f%%", reduction)
        elseif effect_type == "streak_multiplier" then
            effect_text = string.format("KEEPSAKE +%.0f%% STREAK", (effect_value - 1.0) * 100)
        elseif effect_type == "qte_target_lifetime_multiplier" then
            effect_text = string.format("KEEPSAKE +%.0f%% TIME", (effect_value - 1.0) * 100)
        elseif effect_type == "qte_circle_shrink_multiplier" then
            effect_text = string.format("KEEPSAKE SLOWER SHRINK")
        elseif effect_type == "qte_bonus" then
            effect_text = "QTE BOOST"
        else
            effect_text = "KEEPSAKE ACTIVE"
        end
    end
    
    state.keepsake_splash_text = effect_text
    state.keepsake_splash_timing = splash_timing
    state.keepsake_splash_timer = state.KEEPSAKE_SPLASH_DURATION
end

-- Draw keepsake splash over the lucky box
function KeepsakeSplash.draw(state)
    if not state or (state.keepsake_splash_timer or 0) <= 0 then return end
    
    local Keepsakes = require("keepsakes")
    local keepsake_id = Keepsakes.get()
    if not keepsake_id then return end
    
    local splash_timing = state.keepsake_splash_timing
    if not splash_timing then return end  -- No timing set
    
    -- Check if splash should be displayed based on timing
    if splash_timing == "spin" then
        if not state.is_spinning then return end  -- Don't show spin-timing splash when NOT spinning
    elseif splash_timing == "score" then
        if state.is_spinning then return end  -- Don't show score-timing splash while spinning
    elseif splash_timing == "qte" then
        if not (state.qte and state.qte.active) then return end  -- Only show when QTE is active
    end
    
    local progress = state.keepsake_splash_timer / state.KEEPSAKE_SPLASH_DURATION
    local alpha = progress  -- Fade out as timer decreases
    
    -- Growth and wiggle animation
    local scale = 1.0 + (1.0 - progress) * 0.5  -- Grows from 1.5x to 1.0x as it fades
    local wiggle_amount = math.sin(love.timer.getTime() * 8) * (1.0 - progress) * 15  -- Wiggle decreases as it fades
    
    -- Rotation animation - up to 20 degrees
    local rotation = math.sin(love.timer.getTime() * 4) * (1.0 - progress) * 20 * (math.pi / 180)  -- Convert degrees to radians
    
    local splash_text = state.keepsake_splash_text or ""
    if splash_text == "" then return end
    
    local lucky_x = Config.BUTTON_START_X
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local splash_y = box_y + UIConfig.LUCKY_BOX_HEIGHT / 2 - 65 + wiggle_amount  -- Center over lucky box with wiggle, moved up 50px total
    
    -- Get SlotMachine module for info_font
    local SlotMachine = require("slot_machine")
    
    -- Get keepsake color
    local splash_color = Keepsakes.get_splash_color()
    
    love.graphics.setFont(SlotMachine.info_font)
    local tw = SlotMachine.info_font:getWidth(splash_text)
    local th = SlotMachine.info_font:getHeight()
    local box_center_x = lucky_x + UIConfig.LUCKY_BOX_WIDTH / 2
    
    -- Draw text with scale and rotation
    love.graphics.push()
    love.graphics.translate(box_center_x, splash_y)
    love.graphics.scale(scale)
    love.graphics.rotate(rotation)
    
    -- Draw text
    love.graphics.setColor(splash_color[1], splash_color[2], splash_color[3], alpha)
    love.graphics.print(splash_text, -tw / 2, -th / 2)
    
    love.graphics.pop()
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
end

return KeepsakeSplash
