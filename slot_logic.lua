-- slot_logic.lua
local Config = require("conf")

local SlotLogic = {} 
local Slots = nil -- Reference injected by setSlotMachineModule

-- --- Helpers for Win Checking ---
function SlotLogic.check_consecutive_win(vals, count, winning_indices)
    local max_streak = 0
    local end_index = 0
    local current_streak = 0
    for i = 1, #vals do
        if i > 1 and vals[i] == vals[i-1] then current_streak = current_streak + 1 else current_streak = 1 end
        if current_streak >= count and current_streak > max_streak then max_streak = current_streak; end_index = i end
    end
    if max_streak >= count then
        for i = end_index - max_streak + 1, end_index do winning_indices[i] = true end
        return true, max_streak
    end
    return false, 0
end
function SlotLogic.check_full_house_win(vals, winning_indices)
    local counts = {}
    for i, v in ipairs(vals) do counts[v] = (counts[v] or 0) + 1 end
    local has3, has2 = false, false
    for _, c in pairs(counts) do if c == 3 then has3 = true elseif c == 2 then has2 = true end end
    if has3 and has2 then
        local k3, k2
        for k, c in pairs(counts) do if c == 3 then k3 = k elseif c == 2 then k2 = k end end
        for i = 1, #vals do if vals[i] == k3 or vals[i] == k2 then winning_indices[i] = true end end
        return true
    end
    return false
end
function SlotLogic.check_two_gap_two_win(vals, winning_indices)
    if #vals < 5 then return false end
    if (vals[1] == vals[2]) and (vals[4] == vals[5]) then
        winning_indices[1] = true; winning_indices[2] = true; winning_indices[4] = true; winning_indices[5] = true
        return true
    end
    return false
end
function SlotLogic.check_any_pair_win(vals, winning_indices)
    local found = false
    for i = 1, #vals - 1 do
        if vals[i] == vals[i+1] then winning_indices[i] = true; winning_indices[i+1] = true; found = true end
    end
    return found
end

-- Generates target position anchored to slots 1, 3, or 5.
local function generate_position_in_slot_zone(padding, radius, index)
    local slot_indices_map = {1, 3, 5}
    local slot_column_index = slot_indices_map[(index - 1) % 3 + 1] 
    
    local slot_base_x = Config.PADDING_X + (slot_column_index - 1) * (Config.SLOT_WIDTH + Config.SLOT_GAP)

    local x_start = slot_base_x + radius
    local x_end = slot_base_x + Config.SLOT_WIDTH - radius
    
    local y_start = Config.SLOT_Y + padding
    local y_end = Config.SLOT_Y + Config.SLOT_HEIGHT - padding
    
    if x_start >= x_end then
         local center_x = slot_base_x + Config.SLOT_WIDTH / 2
         x_start = center_x
         x_end = center_x
    end

    local x = love.math.random(x_start, x_end)
    local y = love.math.random(y_start, y_end)
    
    return x, y
end

-- --- Main Resolution Logic ---

function SlotLogic.resolve_spin_result(state, was_blocked)
    local spin_multiplier = 0.0
    local win_name = ""
    local result_color = {1, 1, 1}
    local initial_win_amount = 0
    local is_win = false
    
    local vals = {}
    for i = 1, #state.slots do table.insert(vals, state.slots[i].symbol_index) end
    
    state.winning_indices = {}
    
    -- --- 1. RUN ALL WIN CHECKS & DETERMINE BASE MULTIPLIER ---
    if SlotLogic.check_consecutive_win(vals, 5, state.winning_indices) then
        spin_multiplier = 100.0; win_name = "JACKPOT! (5-Kind)"; result_color = {1, 0.8, 0}
    elseif SlotLogic.check_consecutive_win(vals, 4, state.winning_indices) then
        spin_multiplier = 20.0; win_name = "Big Win! (4-Row)"; result_color = {0.2, 1, 0.2}
    elseif SlotLogic.check_full_house_win(vals, state.winning_indices) then
        spin_multiplier = 10.0; win_name = "Full House!"; result_color = {0.2, 0.8, 1}
    elseif SlotLogic.check_two_gap_two_win(vals, state.winning_indices) then
        spin_multiplier = 8.0; win_name = "Split Pair!"; result_color = {0.8, 0.2, 1}
    elseif SlotLogic.check_consecutive_win(vals, 3, state.winning_indices) then
        spin_multiplier = 3.0; win_name = "Nice! (3-Row)"; result_color = {0.5, 1, 0.5}
    elseif SlotLogic.check_any_pair_win(vals, state.winning_indices) then
        spin_multiplier = 0.5; win_name = "Pair Match"; result_color = {0.8, 0.8, 0.8}
    else
        spin_multiplier = 0.0; win_name = "FLOP!"; result_color = {1.0, 0.2, 0.2}
    end
    
    -- Store spin multiplier in state
    state.current_spin_multiplier = spin_multiplier

    initial_win_amount = math.floor(state.current_bet_amount * spin_multiplier)
    local streak_context = state.consecutive_wins
    
    -- Apply Streak Multiplier only if there is a base win (non-zero spin_multiplier)
    local total_multiplier = Slots.getStreakMultiplier()
    local final_win_amount = initial_win_amount * total_multiplier 
    
    local trigger_auto_spin = false 

    -- 3. INTERCEPT FOR BLOCK GAME SUCCESS
    if was_blocked == true then
        final_win_amount = math.ceil(state.current_bet_amount * 0.01) 
        is_win = true
        win_name = "BLOCKED!"
        result_color = state.BLOCK_COLOR
        trigger_auto_spin = true 
        state.current_spin_multiplier = 0.0 -- QTE win doesn't grant a spin multiplier
    elseif initial_win_amount > 0 then
        is_win = true
    else
        is_win = false
    end

    state.bankroll = state.bankroll + final_win_amount
    
    -- *** QTE CHECK ***
    if was_blocked == nil and is_win == false and streak_context >= 2 then 
        state.block_game_active = true
        state.qte_targets = {}
        
        local targets_to_spawn = 3 
        if streak_context > 10 then
            targets_to_spawn = targets_to_spawn + (streak_context - 10)
        end
        
        local current_time = love.timer.getTime()
        local min_padding = state.QTE_INITIAL_RADIUS + 20 
        
        for i = 1, targets_to_spawn do
            local spawn_offset = (i - 1) * state.QTE_TARGET_DELAY
            
            local zone_index = ((i - 1) % 3) + 1 
            
            local x_pos, y_pos = generate_position_in_slot_zone(min_padding, state.QTE_INITIAL_RADIUS, zone_index)
            
            local target = {
                x = x_pos,
                y = y_pos,
                radius = state.QTE_INITIAL_RADIUS,
                spawn_time = current_time + spawn_offset,
                lifetime = state.QTE_TARGET_LIFETIME,
            }
            table.insert(state.qte_targets, target)
        end
        
        local final_spawn_time = state.qte_targets[#state.qte_targets].spawn_time
        state.block_game_timer = (final_spawn_time - current_time) + state.QTE_TARGET_LIFETIME 

        state.is_spinning = false 
        return 
    end
    
    -- 4. UPDATE STREAK AND DIALOGUE
    if is_win then
        if was_blocked ~= true then 
            if state.consecutive_wins < 0 then
                state.consecutive_wins = 1 
            else
                state.consecutive_wins = state.consecutive_wins + 1 
            end
        end
        
        state.display_payout_string = "+ $" .. string.format("%.0f", final_win_amount)
        state.display_payout_color = {0.2, 1.0, 0.2} 
        state.win_flash_timer = 1.5
        state.message = state.Dialogue.getContextualMessage(true, streak_context)
        state.multiplier_splash_timer = 0.5 -- Trigger multiplier splash
        
        if state.consecutive_wins >= 2 then
            state.streak_splash_text = "x" .. state.consecutive_wins .. " STREAK!"
            local duration_mult = Slots.get_duration_multiplier(state.consecutive_wins)
            local speed_inverse_mult = 1.0 / duration_mult 
            if speed_inverse_mult > 3.0 then speed_inverse_mult = 3.0 end 
            state.streak_splash_timer = state.STREAK_SPLASH_DURATION / speed_inverse_mult
        else
            state.streak_splash_text = ""
            state.streak_splash_timer = 0.0
        end
        
        if trigger_auto_spin then
            state.auto_spin_timer = state.AUTO_SPIN_DELAY
        end

    else
        local qte_failed = (was_blocked == false)
        state.current_spin_multiplier = 0.0 -- Ensure multiplier is 0 on loss

        if streak_context >= 5 or qte_failed then 
            state.break_splash_text = "STREAK BROKEN!"
            state.break_splash_timer = state.BREAK_SPLASH_DURATION
            state.consecutive_wins = 0 
            
            if streak_context >= 5 or qte_failed then
                state.jam_duration_timer = state.JAM_DURATION 
                state.jam_splash_timer = state.JAM_SPLASH_DURATION 
            end
        else
            if state.consecutive_wins > 0 then
                state.consecutive_wins = -1 
            else
                state.consecutive_wins = state.consecutive_wins - 1 
            end
        end
        
        state.display_payout_string = "- $" .. string.format("%.0f", state.current_bet_amount)
        state.display_payout_color = {1.0, 0.2, 0.2}
        state.message = state.Dialogue.getContextualMessage(false, streak_context)
    end

    state.is_spinning = false
    
    if state.block_splash_timer == 0 then
        state.splash_text = win_name
        state.splash_color = result_color
        
        local duration_mult = Slots.get_duration_multiplier(state.consecutive_wins)
        local speed_inverse_mult = 1.0 / duration_mult 
        if speed_inverse_mult > 3.0 then speed_inverse_mult = 3.0 end 
        state.splash_timer = state.SPLASH_DURATION / speed_inverse_mult
    end
end

function SlotLogic.setSlotMachineModule(module)
    Slots = module
end

return SlotLogic