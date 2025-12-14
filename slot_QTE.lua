-- slot_QTE.lua
local Config = require("conf")
local Difficulty = require("difficulty")

local SlotQTE = {}

function SlotQTE.init(state)
    state.qte = {
        active = false,
        x = 0,
        y = 0,
        radius = 60,
        color = {0, 1, 0, 1}, -- Default Green
        status = "IDLE", -- IDLE, ACTIVE, RESOLVED
        timer = 0,
        duration = Difficulty.get_duration(),  -- Time for circle to decay
        start_radius = 60,
        min_radius = 5
    }
end

function SlotQTE.trigger(state)
    state.qte.active = true
    state.qte.status = "ACTIVE"
    state.qte.duration = Difficulty.get_duration()  -- Decay time = difficulty duration
    state.qte.color = Difficulty.get_color()
    state.qte.start_radius = 60
    state.qte.min_radius = 5
    state.qte.timer = state.qte.duration  -- Timer = decay duration
    state.qte.radius = state.qte.start_radius
    
    -- Random position within game bounds (padded to avoid edges)
    local padding = 150
    state.qte.x = love.math.random(padding, Config.GAME_WIDTH - padding)
    state.qte.y = love.math.random(padding, Config.GAME_HEIGHT - padding)
end

function SlotQTE.update(dt, state)
    if not state.qte.active then return end
    
    if state.qte.status == "ACTIVE" then
        state.qte.timer = state.qte.timer - dt
        
        -- Shrink radius linearly: from start_radius to min_radius over duration seconds
        local shrink_progress = 1.0 - (state.qte.timer / state.qte.duration)
        shrink_progress = math.max(0, math.min(1.0, shrink_progress))
        local radius_range = state.qte.start_radius - state.qte.min_radius
        state.qte.radius = state.qte.start_radius - (shrink_progress * radius_range)
        
        -- QTE fails if time expires
        if state.qte.timer <= 0 then
            state.qte.status = "FAILED"
            state.qte.color = {1, 0, 0, 1}
            state.qte.radius = state.qte.min_radius
            state.qte.timer = 0.5
        end
    elseif state.qte.status == "RESOLVED" then
        state.qte.timer = state.qte.timer - dt
        if state.qte.timer <= 0 then
            state.qte.active = false
            state.qte.status = "IDLE"
        end
    elseif state.qte.status == "FAILED" then
        state.qte.timer = state.qte.timer - dt
        if state.qte.timer <= 0 then
            state.qte.active = false
            state.qte.status = "IDLE"
        end
    end
end

function SlotQTE.draw(state)
    if not state.qte.active then return end
    
    -- Draw Circle
    love.graphics.setColor(state.qte.color)
    love.graphics.circle("fill", state.qte.x, state.qte.y, state.qte.radius)
    
    -- Draw Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", state.qte.x, state.qte.y, state.qte.radius)
    love.graphics.setLineWidth(1)
end

function SlotQTE.check_click(state, x, y)
    if not state.qte.active or state.qte.status ~= "ACTIVE" then return false end
    
    local dist = math.sqrt((x - state.qte.x)^2 + (y - state.qte.y)^2)
    
    if dist <= state.qte.radius then
        -- Clicked! Turn Cyan
        state.qte.color = {0, 1, 1, 1} -- Cyan
        state.qte.status = "RESOLVED"
        state.qte.timer = 0.5 -- Short delay before disappearing
        return true
    end
    return false
end

return SlotQTE