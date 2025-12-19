-- upgrade_effects.lua
-- Aggregate selected upgrade effects into usable modifiers for scoring and economy

local UpgradeNode = require("systems.upgrade_node")
local UpgradeEffects = {}

-- Helper: check if an upgrade's trigger matches current slot values
local function trigger_matches(def, vals)
    if not def or not def.trigger then return false end
    if def.trigger.type == "slot" then
        local slot_idx = def.trigger.slot or 1
        local symbol_cond = def.trigger.symbol
        if vals and vals[slot_idx] then
            if not symbol_cond or vals[slot_idx] == symbol_cond then return true end
        end
    elseif def.trigger.type == "score" then
        -- Trigger on any scored spin (caller should only ask when score occurred)
        return true
    end
    return false
end

-- Get aggregated score modifiers for current selected upgrades
-- vals: per-slot symbol indices (optional, for conditional effects)
function UpgradeEffects.get_score_modifiers(vals, state)
    local mods = {
        flat_multiplier = 0,
        flat_bet_increase = 0,
        scaling_multiplier = 0,
        scaling_bet_increase = 0,
        percent_balance_bet_increase = 0,
    }

    local selected = UpgradeNode.get_selected_upgrades() or {}
    for _, sprite in ipairs(selected) do
        local def = UpgradeNode.get_definition(sprite.upgrade_id)
        if def and def.effects then
            local e = def.effects
            -- Unconditional effects
            if e.flat_multiplier then mods.flat_multiplier = mods.flat_multiplier + e.flat_multiplier end
            if e.flat_bet_increase then mods.flat_bet_increase = mods.flat_bet_increase + e.flat_bet_increase end
            if e.scaling_multiplier then mods.scaling_multiplier = mods.scaling_multiplier + e.scaling_multiplier end
            if e.scaling_bet_increase then mods.scaling_bet_increase = mods.scaling_bet_increase + e.scaling_bet_increase end
            if e.percent_balance_bet_increase then mods.percent_balance_bet_increase = mods.percent_balance_bet_increase + e.percent_balance_bet_increase end

            -- Conditional: if def.trigger present and matches vals, apply same fields (simple behavior)
            if def.trigger and trigger_matches(def, vals) then
                if e.conditional then
                    local ce = e.conditional
                    if ce.flat_multiplier then mods.flat_multiplier = mods.flat_multiplier + ce.flat_multiplier end
                    if ce.flat_bet_increase then mods.flat_bet_increase = mods.flat_bet_increase + ce.flat_bet_increase end
                    if ce.scaling_multiplier then mods.scaling_multiplier = mods.scaling_multiplier + ce.scaling_multiplier end
                    if ce.scaling_bet_increase then mods.scaling_bet_increase = mods.scaling_bet_increase + ce.scaling_bet_increase end
                    if ce.percent_balance_bet_increase then mods.percent_balance_bet_increase = mods.percent_balance_bet_increase + ce.percent_balance_bet_increase end
                else
                    -- If no `conditional` block, fall back to applying top-level effects for matching trigger
                    if e.flat_multiplier then mods.flat_multiplier = mods.flat_multiplier + e.flat_multiplier end
                    if e.flat_bet_increase then mods.flat_bet_increase = mods.flat_bet_increase + e.flat_bet_increase end
                    if e.scaling_multiplier then mods.scaling_multiplier = mods.scaling_multiplier + e.scaling_multiplier end
                    if e.scaling_bet_increase then mods.scaling_bet_increase = mods.scaling_bet_increase + e.scaling_bet_increase end
                    if e.percent_balance_bet_increase then mods.percent_balance_bet_increase = mods.percent_balance_bet_increase + e.percent_balance_bet_increase end
                end
            end
        end
    end

    return mods
end

-- Shop/economy modifiers
function UpgradeEffects.get_shop_mods()
    local out = {
        extra_items = 0, -- additional items in shop
        rare_weight_bonus = 0.0, -- additive bonus applied to rare weights
        reroll_cost_mult = 1.0,
    }
    local selected = UpgradeNode.get_selected_upgrades() or {}
    for _, sprite in ipairs(selected) do
        local def = UpgradeNode.get_definition(sprite.upgrade_id)
        if def and def.effects and def.effects.shop then
            local s = def.effects.shop
            if s.extra_items then out.extra_items = out.extra_items + s.extra_items end
            if s.rare_weight_bonus then out.rare_weight_bonus = out.rare_weight_bonus + s.rare_weight_bonus end
            if s.reroll_cost_mult then out.reroll_cost_mult = out.reroll_cost_mult * s.reroll_cost_mult end
        end
    end
    return out
end

function UpgradeEffects.get_currency_mods()
    local out = {
        gem_conversion_mult = 1.0,
        gem_gain_mult = 1.0,
    }
    local selected = UpgradeNode.get_selected_upgrades() or {}
    for _, sprite in ipairs(selected) do
        local def = UpgradeNode.get_definition(sprite.upgrade_id)
        if def and def.effects and def.effects.currency then
            local c = def.effects.currency
            if c.gem_conversion_mult then out.gem_conversion_mult = out.gem_conversion_mult * c.gem_conversion_mult end
            if c.gem_gain_mult then out.gem_gain_mult = out.gem_gain_mult * c.gem_gain_mult end
        end
    end
    return out
end

return UpgradeEffects
