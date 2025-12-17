-- difficulty.lua
local Difficulty = {}

Difficulty.SETTINGS = {
    EASY = {
        name = "EASY",
        duration = 4.0,
        lightning_color = {0.2, 1.0, 0.2, 1.0}  -- Bright Green
    },
    MEDIUM = {
        name = "MEDIUM",
        duration = 2.0,
        lightning_color = {1.0, 0.8, 0.2, 1.0}  -- Gold/Yellow
    },
    HARD = {
        name = "HARD",
        duration = 1.0,
        lightning_color = {1.0, 0.2, 0.2, 1.0}  -- Red
    }
}

-- Current difficulty selection (nil until selected)
local current_difficulty = nil

function Difficulty.set(difficulty_key)
    if Difficulty.SETTINGS[difficulty_key] then
        current_difficulty = difficulty_key
        return true
    end
    return false
end

function Difficulty.get()
    return current_difficulty
end

function Difficulty.is_selected()
    return current_difficulty ~= nil
end

function Difficulty.get_duration()
    if not current_difficulty then return 2.5 end -- Default to medium
    return Difficulty.SETTINGS[current_difficulty].duration
end

function Difficulty.get_color()
    if not current_difficulty then return {1.0, 1.0, 1.0, 1.0} end -- Default white
    return Difficulty.SETTINGS[current_difficulty].lightning_color
end

function Difficulty.reset()
    current_difficulty = nil
end

return Difficulty
