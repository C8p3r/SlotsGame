local Config = require("conf")
local Slots = require("game_mechanics.slot_machine")

local AtlasSelector = {}

local state = {
    current_row = Config.SLOT_ATLAS_ROW or 0,
    animating = false,
    elapsed = 0,
    duration = 1.0,
    target_row = 0,
    next_row = 1,
    spin_speed = 0.06 -- time per row during spin
    ,spin_flips = 0,
    flip_duration = 0.12,
    flip_elapsed = 0,
    _flips_done = 0,
    _switched_this_flip = false,
    _visual_scale_x = 1
    ,display_mode = "row"
}

function AtlasSelector.load()
    -- Always start selector display at row 0
    state.current_row = 0
    state.next_row = 1
    state.animating = false
    state.elapsed = 0
    -- ensure slot machine uses row 0 initially (best-effort)
    pcall(function() Slots.set_atlas_row(0) end)
end

function AtlasSelector.spin()
    if state.animating then return end
    -- Ensure visual starts at 0 for the spin
    state.current_row = 0
    state.target_row = state.next_row or 0
    state.animating = true
    state.elapsed = 0
    -- configure flip animation
    state.spin_flips = 6
    state.flip_duration = 0.12
    state.flip_elapsed = 0
    state._flips_done = 0
    state._switched_this_flip = false
    state._visual_scale_x = 1
    -- play a small click sound if available
    pcall(function() love.audio.newSource("assets/click.wav", "static"):play() end)
end


function AtlasSelector.update(dt)
    if not state.animating then return end

    -- Update flip timer
    state.flip_elapsed = state.flip_elapsed + dt

    local fd = state.flip_duration
    -- Advance flips when local flip time completes
    while state.flip_elapsed >= fd and state._flips_done < state.spin_flips do
        state.flip_elapsed = state.flip_elapsed - fd
        state._flips_done = state._flips_done + 1
        state._switched_this_flip = false
    end

    -- progress within current flip [0,1]
    local local_p = math.min(1, state.flip_elapsed / fd)
    -- ease in/out for smooth squash
    local ease_p = 0.5 - 0.5 * math.cos(math.min(1, local_p) * math.pi)
    -- scaleX goes 1 -> 0 -> 1 across a flip
    local scale_x = 1 - ease_p
    state._visual_scale_x = math.max(0.01, scale_x)

    -- Switch displayed row at mid-flip once
    if local_p >= 0.5 and not state._switched_this_flip and state._flips_done <= state.spin_flips then
        state.current_row = (state.current_row + 1) % 5
        state._switched_this_flip = true
    end

    -- If all flips completed, settle to target (row spin behavior)
    if state._flips_done >= state.spin_flips then
        state.current_row = state.target_row
        pcall(function() Slots.set_atlas_row(state.target_row) end)
        state.next_row = ((state.target_row + 1) % 5)
        state.animating = false
        state.flip_elapsed = 0
        state._flips_done = 0
        state._switched_this_flip = false
        state._visual_scale_x = 1
    end
end

-- draw at given position (x,y) with optional entrance_ease for alpha
function AtlasSelector.draw(x, y, entrance_ease)
    x = x or 24
    y = y or 220
    local alpha = entrance_ease or 1

    local atlas = nil
    pcall(function()
        local s = Slots.getState()
        if s then atlas = s.atlas_image end
    end)

    local icon_size = 72 -- 50% larger than the doubled size (48 * 1.5)
    local spacing = icon_size + 12
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.setColor(1, 1, 1, 0.95 * alpha)

    -- Draw header
    local font = love.graphics.newFont("splashfont.otf", 18)
    love.graphics.setFont(font)
    -- love.graphics.print("Atlas Row", 0, -18)

    -- Draw 5 columns showing the currently selected row's icons
    local visual_scale_x = state._visual_scale_x or 1
    for col = 0, 4 do
        local dx = col * spacing
        love.graphics.push()
        -- center of icon
        local cx = dx + icon_size / 2
        local cy = icon_size / 2
        love.graphics.translate(cx, cy)
        love.graphics.scale(visual_scale_x, 1)
        love.graphics.translate(-cx, -cy)
        if state.display_mode == "gem" then
            -- draw gem icon from UI assets (row 2 col 2 quad as used elsewhere)
            local ok, uiimg = pcall(function() return love.graphics.newImage("assets/UI_assets.png") end)
            if ok and uiimg then
                uiimg:setFilter("nearest", "nearest")
                local q = love.graphics.newQuad(32, 32, 32, 32, uiimg:getDimensions())
                love.graphics.draw(uiimg, q, dx, 0, 0, icon_size / 32, icon_size / 32)
            else
                love.graphics.setColor(0.2 + col * 0.12, 0.2, 0.2, 1)
                love.graphics.rectangle("fill", dx, 0, icon_size, icon_size, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("G", dx + 6, 4)
            end
        else
            if atlas then
                local q = love.graphics.newQuad(col * Config.SOURCE_SPRITE_WIDTH, state.current_row * Config.SOURCE_SPRITE_HEIGHT, Config.SOURCE_SPRITE_WIDTH, Config.SOURCE_SPRITE_HEIGHT, atlas:getDimensions())
                love.graphics.draw(atlas, q, dx, 0, 0, icon_size / Config.SOURCE_SPRITE_WIDTH, icon_size / Config.SOURCE_SPRITE_HEIGHT)
            else
                love.graphics.setColor(0.2 + col * 0.12, 0.2, 0.2, 1)
                love.graphics.rectangle("fill", dx, 0, icon_size, icon_size, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(tostring(state.current_row), dx + 6, 4)
            end
        end
        love.graphics.pop()
    end

-- Simple setters for external control (Shop will manage flip animation)
function AtlasSelector.set_visual_scale_x(v)
    state._visual_scale_x = v or 1
end

function AtlasSelector.set_display_mode(mode)
    state.display_mode = mode or "row"
end

function AtlasSelector.get_display_mode()
    return state.display_mode
end

    -- Draw spin button
    local btn_x = 0
    local btn_y = icon_size + 18
    local btn_w = 5 * spacing - 12
    local btn_h = 40
    love.graphics.setColor(0.12, 0.12, 0.12, 0.95 * alpha)
    love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.95 * alpha)
    local btn_font = love.graphics.newFont("splashfont.otf", 20)
    love.graphics.setFont(btn_font)
    local text = state.animating and "Swapping..." or "Swap Icons"
    local tw = btn_font:getWidth(text)
    love.graphics.print(text, btn_x + (btn_w / 2) - (tw / 2), btn_y + 3)

    love.graphics.pop()
end

function AtlasSelector.get_bounds(x, y)
    x = x or 24
    y = y or 220
    local icon_size = 72
    local spacing = icon_size + 12
    local w = 5 * spacing - 12
    local h = icon_size + 18 + 40
    return x, y, w, h
end

function AtlasSelector.check_click(gx, gy, base_x, base_y)
    base_x = base_x or (Config.GAME_WIDTH * 0.02)
    base_y = base_y or (Config.GAME_HEIGHT * 0.25 + 50 + 120)
    local x, y, w, h = AtlasSelector.get_bounds(base_x, base_y)
    if gx >= x and gx <= x + w and gy >= y and gy <= y + h then
        -- If click in lower button area, trigger spin; else ignore
        local local_y = gy - y
        local icon_size = 72
        local btn_y = icon_size + 18
        if local_y >= btn_y then
            AtlasSelector.spin()
            return true
        end
    end
    return false
end

return AtlasSelector
