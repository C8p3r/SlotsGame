-- gambling.lua
local Config = require("conf")

local Gambling = {}

-- State
local bankroll = 50000
local spin_count = 0
local bet_percent = Config.INITIAL_BET_PERCENT or 0.25 -- Default to 25%
local current_bet_amount = 0
local last_win_amount = 0

-- Messages
local loss_messages_base = {
    "Sell the car!", "Call the loan shark!", "Where's the deed to the house?",
    "Check the couch cushions, again.", "Time to hock the plasma screen.",
    "Maybe just one more small loan...", "Ask your mother-in-law for a 'loan'.",
    "Empty the retirement account.", "The kids' college fund is looking plump.",
    "We need a payment extension.", "This must be rigged!",
    "Just one more spin, I feel it.",
}
local loss_messages_cycle = {}
local current_loss_message_index = 0

local function shuffle_messages()
    loss_messages_cycle = {}
    for i = 1, #loss_messages_base do
        loss_messages_cycle[i] = loss_messages_base[i]
    end
    for i = #loss_messages_cycle, 2, -1 do
        local j = love.math.random(i)
        loss_messages_cycle[i], loss_messages_cycle[j] = loss_messages_cycle[j], loss_messages_cycle[i]
    end
    current_loss_message_index = 0
end

function Gambling.load()
    bankroll = 50000
    spin_count = 0
    bet_percent = Config.INITIAL_BET_PERCENT or 0.25
    current_bet_amount = 0
    last_win_amount = 0
    shuffle_messages()
end

function Gambling.getBankroll()
    return bankroll
end

function Gambling.getBetPercent()
    return bet_percent
end

-- Returns the actual $ amount of the current bet
function Gambling.calculateBetAmount()
    local b = math.abs(bankroll)
    if b == 0 then b = 5000 end -- Fallback base if broke
    return math.floor(b * bet_percent)
end

-- Change bet by +/- 5%
-- direction: 1 for up, -1 for down, 100 for max
function Gambling.adjustBet(direction) 
    if direction == 100 then
        bet_percent = Config.MAX_BET_PERCENT
    else
        bet_percent = bet_percent + (direction * Config.BET_INCREMENT)
    end
    
    -- Clamp values (between 5% and 100%)
    -- Using math.floor/ceil to prevent floating point drift (e.g. 0.300000004)
    bet_percent = math.floor(bet_percent * 100 + 0.5) / 100
    
    if bet_percent > Config.MAX_BET_PERCENT then bet_percent = Config.MAX_BET_PERCENT end
    if bet_percent < Config.MIN_BET_PERCENT then bet_percent = Config.MIN_BET_PERCENT end
end

-- Logic to deduct money and track difficulty
function Gambling.placeBet()
    current_bet_amount = Gambling.calculateBetAmount()
    bankroll = bankroll - current_bet_amount
    spin_count = spin_count + 1
    return current_bet_amount
end

-- Logic to calculate winnings
function Gambling.resolveSpin(slots)
    local win_type = "lose"
    local message = ""
    local win_amount = 0
    
    -- Difficulty Scaling
    local win_multiplier = 1.0
    if spin_count > Config.DIFFICULTY_START_SPIN then
        local difficulty_factor = spin_count - Config.DIFFICULTY_START_SPIN
        win_multiplier = math.max(1.0, 2.0 - difficulty_factor * 0.05)
    else
        win_multiplier = 2.0
    end

    -- Check matches (consecutive from left)
    local match_count = 1
    local first_symbol = slots[1].symbol_index
    for i = 2, #slots do
        if slots[i].symbol_index == first_symbol then
            match_count = match_count + 1
        else
            break
        end
    end
    
    -- Payouts based on current bet amount
    if match_count >= 5 then
        win_amount = math.floor(current_bet_amount * 50 * win_multiplier)
        win_type = "jackpot"
        message = "5-OF-A-KIND JACKPOT!"
    elseif match_count == 4 then
        win_amount = math.floor(current_bet_amount * 20 * win_multiplier)
        win_type = "big_win"
        message = "BIG WINNER!"
    elseif match_count == 3 then
        win_amount = math.floor(current_bet_amount * 5 * win_multiplier)
        win_type = "small_win"
        message = "WINNER!"
    else
        win_type = "lose"
        if bankroll < 0 then
            if current_loss_message_index >= #loss_messages_cycle then
                shuffle_messages()
            end
            current_loss_message_index = current_loss_message_index + 1
            message = loss_messages_cycle[current_loss_message_index] or "You are broke!"
        else
            message = "No match. Settings"
        end
    end
    
    bankroll = bankroll + win_amount
    last_win_amount = win_amount
    
    return win_type, win_amount, message
end

return Gambling