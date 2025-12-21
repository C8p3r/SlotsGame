-- payout_system.lua
-- Centralize payout calculation and scoring-trigger animations

local UpgradeEffects = require("systems.upgrade_effects")
local UpgradeSprite = require("systems.upgrade_sprite")

local PayoutSystem = {}

-- Internal trigger queue state for scoring animations
local _trigger_queue = nil
local _trigger_index = 0
local _trigger_timer = 0
local _trigger_callback = nil

-- Calculate payout given a base spin multiplier and bet amount.
-- spin_multiplier: base multiplier derived from symbol pattern (e.g. 3.0)
-- bet_amount: base bet before upgrade-modified bet adjustments
-- vals: optional per-slot values (passed to UpgradeEffects for conditional effects)
-- state: optional game state (used for percent-based bet increases)
-- opts: optional table: { total_multiplier = 1.0 } (streak multiplier, etc.)
-- Returns a table with fields: adjusted_multiplier, adjusted_bet, initial_win_amount, final_win_amount, mods
function PayoutSystem.calculate(spin_multiplier, bet_amount, vals, state, opts)
    opts = opts or {}
    local total_multiplier = opts.total_multiplier or 1.0

    local mods = UpgradeEffects.get_score_modifiers(vals, state) or {}

    local adjusted_multiplier = spin_multiplier or 0
    adjusted_multiplier = adjusted_multiplier * (1 + (mods.scaling_multiplier or 0))
    adjusted_multiplier = adjusted_multiplier + (mods.flat_multiplier or 0)

    local adjusted_bet = bet_amount or 0
    adjusted_bet = adjusted_bet + (mods.flat_bet_increase or 0)
    adjusted_bet = adjusted_bet + math.floor(((mods.percent_balance_bet_increase or 0) * ((state and state.bankroll) or 0)))
    adjusted_bet = math.floor(adjusted_bet * (1 + (mods.scaling_bet_increase or 0)))

    local initial_win_amount = math.floor(adjusted_bet * adjusted_multiplier)
    local final_win_amount = math.floor(initial_win_amount * total_multiplier)

    return {
        adjusted_multiplier = adjusted_multiplier,
        adjusted_bet = adjusted_bet,
        initial_win_amount = initial_win_amount,
        final_win_amount = final_win_amount,
        mods = mods
    }
end

-- Start a trigger sequence for scoring-time visual pulses.
-- queue: array of entries { sprite = <UpgradeSprite>, duration = 0.45, scale = 1.5, gap = 0.12 }
-- callback: function called when sequence finishes
function PayoutSystem.start_trigger_sequence(queue, callback)
    if not queue or #queue == 0 then
        if callback then callback() end
        return
    end
    _trigger_queue = queue
    _trigger_index = 0
    _trigger_timer = 0
    _trigger_callback = callback
end

function PayoutSystem.update(dt)
    if not _trigger_queue or #_trigger_queue == 0 then return end

    if _trigger_timer > 0 then
        _trigger_timer = _trigger_timer - dt
        if _trigger_timer <= 0 then
            _trigger_index = _trigger_index + 1
            if _trigger_index > #_trigger_queue then
                local cb = _trigger_callback
                _trigger_callback = nil
                _trigger_queue = nil
                _trigger_index = 0
                _trigger_timer = 0
                if cb then cb() end
                return
            else
                local entry = _trigger_queue[_trigger_index]
                if entry and entry.sprite then
                    UpgradeSprite.start_pulse(entry.sprite, entry.duration or 0.45, entry.scale or 1.5)
                    _trigger_timer = (entry.duration or 0.45) + (entry.gap or 0.12)
                else
                    _trigger_timer = 0
                end
            end
        end
    else
        -- start first trigger
        _trigger_index = 1
        local entry = _trigger_queue[_trigger_index]
        if entry and entry.sprite then
            UpgradeSprite.start_pulse(entry.sprite, entry.duration or 0.45, entry.scale or 1.5)
            _trigger_timer = (entry.duration or 0.45) + (entry.gap or 0.12)
        else
            local cb = _trigger_callback
            _trigger_callback = nil
            _trigger_queue = nil
            _trigger_index = 0
            _trigger_timer = 0
            if cb then cb() end
        end
    end
end

function PayoutSystem.is_animating()
    return _trigger_queue ~= nil
end

-- Convenience: build a trigger queue from an array of sprites
function PayoutSystem.build_queue_from_sprites(sprites, opts)
    opts = opts or {}
    local q = {}
    for _, s in ipairs(sprites or {}) do
        table.insert(q, { sprite = s, duration = opts.duration or 0.45, scale = opts.scale or 1.5, gap = opts.gap or 0.12 })
    end
    return q
end

return PayoutSystem
