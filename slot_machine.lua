-- slot_machine.lua
local Config = require("conf")
local Dialogue = require("ui/dialogue") 
local SlotLogic = require("slot_logic") 
local SlotDraw = require("slot_draw")   
local SlotUpdate = require("slot_update") 
local SlotBorders = require("slot_borders")
local SlotSmoke = require("slot_smoke")
local BackgroundRenderer = require("background_renderer")
local Difficulty = require("difficulty")

local SlotMachine = {}

-- =============================================================================
--  STATE VARIABLES
-- =============================================================================
local state = {
    -- Gambling
    bankroll = Config.INITIAL_BANKROLL, 
    spin_count = 0,
    flat_bet_base = Config.FLAT_INCREMENT, 
    bet_percent = 0.0, 
    current_bet_amount = Config.FLAT_INCREMENT, 
    last_win_amount = 0,
    consecutive_wins = 0,
    high_streak = 0, 

    -- Machine State
    is_spinning = false,
    spin_timer = 0,
    spin_delay_timer = 0.0,

    -- Assets/Graphics Handles
    slots = {},
    loaded_sprites = {},
    symbol_canvas = nil,
    neon_glow_shader = nil,
    invert_shader = nil,
    scanline_shader = nil,
    symbol_font = nil,
    info_font = nil,
    dialogue_font = nil,
    result_font = nil,
    splash_font = nil,

    -- UI/Animation
    display_payout_string = "",
    display_payout_color = {1, 1, 1},
    winning_indices = {},
    strobe_timer = 0.0,
    win_flash_timer = 0,
    message = "",
    
    -- Multipliers
    current_spin_multiplier = 0.0, -- NEW: Multiplier from slot match (x0.5, x3, x100, etc.)
    multiplier_splash_timer = 0.0, -- NEW: Timer for multiplier splashes

    -- Wiggle LERP State
    WIGGLE_LERP_RATE = 2.5,
    current_wiggle_speed_mod = 1.0,
    current_wiggle_range_mod = 1.0,

    -- Splash State
    SPLASH_DURATION = 0.6,
    splash_timer = 0.0,
    splash_text = "",
    splash_color = {1, 1, 1},
    STREAK_SPLASH_DURATION = 1.0,
    streak_splash_timer = 0.0,
    streak_splash_text = "",
    streak_splash_color = {0, 1, 1},
    BREAK_SPLASH_DURATION = 1.5,
    break_splash_timer = 0.0,
    break_splash_text = "",
    break_splash_color = {1.0, 0.2, 0.2},
    JAM_DURATION = 3.0,
    jam_duration_timer = 0.0,
    jam_splash_timer = 0.0,
    JAM_SPLASH_DURATION = 0.5,
    JAM_TEXT = "JAM!",
    JAM_COLOR = {1.0, 0.8, 0.2},
    
    -- QTE State
    QTE_DURATION = 1.25, 
    QTE_TARGET_LIFETIME = 0.75, 
    QTE_TARGET_DELAY = 0.25,    
    QTE_INITIAL_RADIUS = 280, 
    QTE_MIN_RADIUS = 10, 
    block_game_active = false,
    block_game_timer = 0.0,
    qte_targets = {}, 
    block_splash_timer = 0.0,
    BLOCK_SPLASH_DURATION = 0.8,
    BLOCK_COLOR = {0.2, 1.0, 0.2},
    FAIL_COLOR = {1.0, 0.2, 0.2},
    
    -- NEW AUTO-SPIN STATE
    AUTO_SPIN_DELAY = 0.2, 
    auto_spin_timer = 0.0,
    
    -- Keepsake Effect Splash
    keepsake_splash_timer = 0.0,
    keepsake_splash_text = "",
    keepsake_splash_color = {0.2, 1.0, 0.8},
    KEEPSAKE_SPLASH_DURATION = 1.2,
    
    Dialogue = Dialogue,
}

SlotMachine.state = state

SlotLogic.setSlotMachineModule(SlotMachine)
SlotDraw.setSlotMachineModule(SlotMachine)
SlotUpdate.setSlotMachineModule(SlotMachine)
SlotBorders.setSlotMachineModule(SlotMachine)
SlotSmoke.setSlotMachineModule(SlotMachine)

-- =============================================================================
--  HELPER FUNCTIONS
-- =============================================================================

local function calculate_bet_amount()
    local b = math.abs(state.bankroll)
    local min_bankroll_for_calc = math.max(b, 100)
    
    local flat_component = state.flat_bet_base 
    local percent_component = math.floor(min_bankroll_for_calc * state.bet_percent)
    
    local calculated_bet = flat_component + percent_component
    
    if state.bankroll > 0 and calculated_bet < 1 then
        return 1
    end
    
    return math.max(1, calculated_bet) -- Enforce a minimum bet of 1
end

function SlotMachine.get_duration_multiplier(streak)
    local max_streak_for_speed = 8
    local max_speed_increase = 0.65 
    
    local positive_streak = math.max(0, streak)
    local multiplier = math.min(1.0, positive_streak / max_streak_for_speed)
    
    local reduction_factor = multiplier * max_speed_increase
    return 1.0 - reduction_factor
end

function SlotMachine.calculate_target_wiggle_modifiers(streak)
    local max_streak_for_speed = 5
    local multiplier = math.min(1.0, math.max(0, streak) / max_streak_for_speed)
    
    local speed_mod = 1.0 + (multiplier * 0.5) 
    local range_mod = 1.0 + (multiplier * 2.0) 
    
    return speed_mod, range_mod
end

-- --- Forwarded Drawing Helpers ---

function SlotMachine.get_wiggle_modifiers()
    return state.current_wiggle_speed_mod, state.current_wiggle_range_mod 
end

-- Trigger keepsake effect splash
function SlotMachine.trigger_keepsake_splash(effect_type, effect_value)
    local effect_text = ""
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
    else
        effect_text = "KEEPSAKE ACTIVE"
    end
    
    state.keepsake_splash_text = effect_text
    state.keepsake_splash_timer = state.KEEPSAKE_SPLASH_DURATION
end

function SlotMachine.calculate_symbol_y(slot_index, iterator_index)
    local slot = state.slots[slot_index]
    local current_y = slot.scroll_offset
    local loop_h = #state.loaded_sprites * Config.SYMBOL_SPACING
    
    current_y = current_y + (iterator_index - 1) * Config.SYMBOL_SPACING
    current_y = current_y % loop_h
    
    local center = Config.SLOT_HEIGHT / 2
    local dist = current_y - center
    if dist > (loop_h / 2) then current_y = current_y - loop_h
    elseif dist < -(loop_h / 2) then current_y = current_y + loop_h
    end
    
    local y = Config.SLOT_Y + current_y
    
    if slot.is_stopped then
        local actual_id = (iterator_index - 1) % #state.loaded_sprites + 1
        local progress = SlotMachine.get_symbol_drop_progress(slot, actual_id)
        y = y - Config.DROP_DISTANCE + (Config.DROP_DISTANCE * progress)
    end
    return y
end

function SlotMachine.get_symbol_drop_progress(slot, symbol_index)
    if not slot.is_stopped then return 0 end
    
    local count = #state.loaded_sprites
    local winner = slot.symbol_index
    local current = symbol_index
    
    local is_bottom = (current == (winner % count) + 1)
    local is_middle = (current == winner)
    local is_top = (current == (winner - 2) % count + 1) 
    
    local delay = 0
    if is_bottom then delay = 0
    elseif is_middle then delay = Config.ROW_LANDING_DELAY
    elseif is_top then delay = Config.ROW_LANDING_DELAY * 2
    end
    
    if not slot.stop_start_time then return 0 end

    local elapsed = love.timer.getTime() - slot.stop_start_time - delay
    local progress = math.min(1.0, elapsed / (slot.stop_duration or 0.5)) 
    return 1.0 - (1.0 - progress) ^ 3
end

-- =============================================================================
--  MAIN MODULE API
-- =============================================================================

function SlotMachine.getBankroll() return state.bankroll end
function SlotMachine.getBetPercent() return state.bet_percent end 
function SlotMachine.getFlatBetBase() return state.flat_bet_base end 
function SlotMachine.getCurrentBet() return calculate_bet_amount() end
function SlotMachine.getConsecutiveWins() return state.consecutive_wins end 
function SlotMachine.getHighStreak() return state.high_streak end 
function SlotMachine.getSpinMultiplier() return state.current_spin_multiplier end -- NEW
function SlotMachine.getStreakMultiplier() 
    return 1.0 + (math.max(0, state.consecutive_wins) * 0.1) -- 10% per streak
end -- NEW

function SlotMachine.getState()
    return state
end

function SlotMachine.is_spinning() return state.is_spinning end
function SlotMachine.is_jammed() return state.jam_duration_timer > 0 end
function SlotMachine.is_block_game_active() return state.block_game_active end

function SlotMachine.re_splash_jam()
    state.jam_splash_timer = state.JAM_SPLASH_DURATION
end

function SlotMachine.check_qte_click(x, y)
    if state.block_game_active then
        local hit_index = nil
        
        for i, target in ipairs(state.qte_targets) do
            local dist = math.sqrt((x - target.x)^2 + (y - target.y)^2)
            if (love.timer.getTime() >= target.spawn_time) and dist <= target.radius then
                hit_index = i
                break
            end
        end
        
        if hit_index then
            table.remove(state.qte_targets, hit_index)
            
            if #state.qte_targets == 0 then
                state.block_game_active = false
                state.block_game_timer = 0
                state.block_splash_timer = state.BLOCK_SPLASH_DURATION 
                state.splash_text = "BLOCKED!"
                state.splash_color = {0.8, 0.2, 1.0, 1.0} -- PURPLE FLASH
                SlotMachine.resolve_spin_result(true) -- Success
            end
        else
            state.block_game_active = false
            state.block_game_timer = 0
            state.qte_targets = {}
            state.block_splash_timer = state.BLOCK_SPLASH_DURATION 
            state.splash_text = "MISSED!"
            state.splash_color = state.FAIL_COLOR
            SlotMachine.resolve_spin_result(false) -- Fail
        end
        return true 
    end
    return false
end

function SlotMachine.adjustBet(type, direction) 
    if type == "FLAT" then
        state.flat_bet_base = state.flat_bet_base + (direction * Config.FLAT_INCREMENT)
        if state.flat_bet_base < Config.FLAT_INCREMENT then
             state.flat_bet_base = Config.FLAT_INCREMENT
        end
    elseif type == "PERCENT" then
        state.bet_percent = state.bet_percent + (direction * Config.PERCENT_INCREMENT)
        
        -- Clamp percentage values
        state.bet_percent = math.floor(state.bet_percent * 200 + 0.5) / 200 -- 0.005 is 1/200th
        
        if state.bet_percent > Config.MAX_PERCENT_BET then 
            state.bet_percent = Config.MAX_PERCENT_BET 
        end
        if state.bet_percent < 0.0 then 
            state.bet_percent = 0.0 
        end
    end
end

function SlotMachine.load()
    local font_file = "splashfont.otf"
    
    state.symbol_font = love.graphics.newFont(font_file, Config.FONT_SIZE)
    state.info_font = love.graphics.newFont(font_file, Config.INFO_FONT_SIZE)
    SlotMachine.info_font = state.info_font 
    state.dialogue_font = love.graphics.newFont(font_file, Config.DIALOGUE_FONT_SIZE)
    state.result_font = love.graphics.newFont(font_file, Config.RESULT_FONT_SIZE)
    state.splash_font = state.result_font 
    
    local function load_s(filename)
        local ok, s = pcall(love.graphics.newShader, filename)
        if not ok then return nil end
        return s
    end
    state.neon_glow_shader = load_s("shaders/neon_glow_shader.glsl")
    state.invert_shader = load_s("shaders/invert_rgb_shader.glsl")
    state.scanline_shader = load_s("shaders/scanline_shader.glsl")
    
    state.symbol_canvas = love.graphics.newCanvas(Config.GAME_WIDTH, Config.GAME_HEIGHT)
    
    for i, filename in ipairs(Config.SPRITE_FILES) do
        local ok, img = pcall(love.graphics.newImage, filename)
        if ok then
            img:setFilter("nearest", "nearest")
            table.insert(state.loaded_sprites, img)
        else
            local p = love.image.newImageData(32, 32)
            table.insert(state.loaded_sprites, love.graphics.newImage(p))
        end
    end
    
    local num_slots = Config.SLOT_COUNT or 5
    state.slots = {}
    for i = 1, num_slots do
        state.slots[i] = {
            symbol_index = love.math.random(1, #state.loaded_sprites),
            scroll_offset = love.math.random() * Config.SYMBOL_SPACING,
            is_stopped = true,
            stop_time = 0.0,
            stop_duration = Config.STOP_DURATION
        }
    end
    
    state.bankroll = Config.INITIAL_BANKROLL 
    state.flat_bet_base = Config.FLAT_INCREMENT
    state.bet_percent = 0.0
    state.current_bet_amount = calculate_bet_amount()
    state.consecutive_wins = 0
    state.high_streak = 0
    state.current_spin_multiplier = 0.0
    
    state.message = Dialogue.getDefaultMessage()
    Dialogue.load() 
end

function SlotMachine.start_spin()
    if state.is_spinning or state.block_game_active then return end
    
    local bet_to_place = calculate_bet_amount()
    
    state.current_bet_amount = bet_to_place 
    state.bankroll = state.bankroll - state.current_bet_amount
    state.spin_count = state.spin_count + 1
    
    state.winning_indices = {} 
    state.break_splash_timer = 0.0
    state.jam_duration_timer = 0.0
    state.qte_targets = {} 
    state.auto_spin_timer = 0.0 
    
    local duration_mult = SlotMachine.get_duration_multiplier(state.consecutive_wins)
    local dynamic_spin_duration = Config.SPIN_DURATION * duration_mult
    local dynamic_stop_duration = Config.STOP_DURATION * duration_mult
    
    state.is_spinning = true
    state.spin_delay_timer = 0.0
    state.message = "Gamblin'..."
    state.win_flash_timer = 0
    state.current_spin_multiplier = 0.0 -- Reset spin multiplier at start of spin
    
    local num_slots = #state.slots
    local stop_times = {}
    local stop_base = dynamic_spin_duration
    local stop_interval = 0.4  -- Time between each slot stopping (left to right), increased for more deliberate pauses
    
    local max_stop_time = 0

    for i = 1, num_slots do
        -- Each slot stops sequentially, with the leftmost (i=1) stopping first
        local t = stop_base + (i - 1) * stop_interval
        stop_times[i] = t
        if t > max_stop_time then max_stop_time = t end
    end
    
    state.spin_timer = max_stop_time + 0.1

    for i = 1, num_slots do
        state.slots[i].stop_time = stop_times[i]
        state.slots[i].is_stopped = false
        state.slots[i].final_y_offset = 0.0
        state.slots[i].stop_duration = dynamic_stop_duration 
        state.slots[i].symbol_index = love.math.random(1, #state.loaded_sprites)
    end
end

function SlotMachine.update(dt)
    SlotUpdate.update(dt, state)
end

function SlotMachine.draw()
    SlotDraw.draw(state)
end

function SlotMachine.resolve_spin_result(was_blocked)
    SlotLogic.resolve_spin_result(state, was_blocked)
    if state.consecutive_wins > state.high_streak then
        state.high_streak = state.consecutive_wins
    end
    -- Update background hue based on streak
    BackgroundRenderer.setStreakHue(state.consecutive_wins)
end

function SlotMachine.keypressed(key)
end

return SlotMachine