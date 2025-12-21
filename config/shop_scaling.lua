-- shop_scaling.lua
-- Configurable scaling rules for shop goal progression
-- Export functions to compute multiplier and goal per round.

local ShopScaling = {}

-- Default parameters (tweakable)
ShopScaling.defaults = {
    threshold = 24,          -- after this many shops use post-formula
    post_growth_rate = 0.05, -- base growth factor applied after threshold
    post_power = 1.2,        -- exponent applied to extra rounds
}

-- Optional manual goals table: set explicit absolute goals per round (1-based).
-- If a value exists for a round in this table, `get_goal` will return it directly.
-- Useful for rounds 1..24 where you want exact control.
-- Example:
-- ShopScaling.manual_goals = { [1]=1000, [2]=1500, [3]=2250 }
ShopScaling.manual_goals = {
    -- Groups of three with a small dip on the first round of each group (1,4,7,...)
    [1]  = 1000,
    [2]  = 1250,
    [3]  = 1500,

    [4]  = 1750,
    [5]  = 2000,
    [6]  = 2250,

    [7]  = 2500,
    [8]  = 2750,
    [9]  = 3000,

    [10] = 3750,
    [11] = 4750,
    [12] = 6000,

    [13] = 7750,
    [14] = 9750,
    [15] = 12250,

    [16] = 15500,
    [17] = 19500,
    [18] = 24750,

    [19] = 31250,
    [20] = 39500,
    [21] = 50000,

    [22] = 63250,
    [23] = 80000,
    [24] = 100000,
}

-- Calculate multiplier for a given round (1-based).
-- base_multiplier: e.g. 1.5 (50% per-round increase)
-- opts: optional overrides (threshold, post_growth_rate, post_power)
function ShopScaling.multiplier_for_round(round, base_multiplier, opts)
    opts = opts or {}
    local threshold = opts.threshold or ShopScaling.defaults.threshold
    local post_growth_rate = opts.post_growth_rate or ShopScaling.defaults.post_growth_rate
    local post_power = opts.post_power or ShopScaling.defaults.post_power

    if not round or round < 1 then round = 1 end
    -- For rounds up to and including threshold, use exponential growth
    if (round - 1) <= threshold then
        return (base_multiplier or 1.0) ^ (round - 1)
    end

    -- After threshold, apply a tempered formula that scales more smoothly
    local pre = (base_multiplier or 1.0) ^ threshold
    local extra = (round - 1) - threshold
    -- Example post-threshold formula: multiply by (1 + rate * extra^power)
    local post_mult = 1 + post_growth_rate * (extra ^ post_power)
    return pre * post_mult
end

-- Convenience: get absolute goal for a round given a base goal amount
function ShopScaling.get_goal(base_goal, round, base_multiplier, opts)
    -- Prefer manual override if provided
    if ShopScaling.manual_goals and ShopScaling.manual_goals[round] then
        return ShopScaling.manual_goals[round]
    end
    local mult = ShopScaling.multiplier_for_round(round, base_multiplier, opts)
    return math.floor((base_goal or 0) * mult)
end

return ShopScaling
