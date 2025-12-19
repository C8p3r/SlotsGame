-- upgrade_node.lua
-- Upgrade node system for managing upgradeable game elements

local Config = require("conf")
local UIConfig = require("ui.ui_config")
local UpgradeSprite = require("systems.upgrade_sprite")

local UpgradeNode = {}

-- Track upgrades purchased in the current shop/session so they don't reappear
local purchased_this_round = {}

function UpgradeNode.mark_purchased(upgrade_id)
    if upgrade_id then purchased_this_round[upgrade_id] = true end
end

function UpgradeNode.is_purchased_this_round(upgrade_id)
    return purchased_this_round[upgrade_id]
end

function UpgradeNode.clear_purchased_this_round()
    purchased_this_round = {}
end

-- Trigger sequencing state for scoring-time visual pulses
local _trigger_queue = nil
local _trigger_index = 0
local _trigger_timer = 0
local _trigger_callback = nil
-- Acceleration settings for trigger sequencing: per-step multiplier (<1 speeds up)
local _trigger_accel = 0.85
local _trigger_min_multiplier = 0.25
local _trigger_base_multiplier = 0.5  -- initial multiplier (0.5 => 2x as fast initially)

-- Selected/acquired upgrades (stored as sprite objects)
local selected_upgrades = {}  -- Table of UpgradeSprite objects (those bought from the shop)
local MAX_SELECTED_UPGRADES = 5

-- Gem transaction settings
local SELL_RATE = 0.50  -- 50% of buy price is returned when selling

-- Rarity cost tiers
local RARITY_COSTS = {
    Standard = 8,
    Premium = 12,
    ["High-Roller"] = 16,
    VIP = 20
}

-- Rarity weights used for shop appearance likelihood (higher = more common)
local RARITY_WEIGHTS = {
    Standard = 60,
    Premium = 25,
    ["High-Roller"] = 10,
    VIP = 5,
}

-- Optional local RNG state for deterministic shop generation (LCG)
local shop_rng_state = nil

function UpgradeNode.set_shop_seed(seed)
    if seed == nil then
        shop_rng_state = nil
    else
        -- Use a 32-bit integer seed
        shop_rng_state = seed % 2147483647
        if shop_rng_state <= 0 then shop_rng_state = shop_rng_state + 2147483646 end
    end
end

-- Define all 50 upgrades (5 cols × 10 rows from upgrade_units_UI.png)
local UPGRADE_DEFINITIONS = {
    -- Row 1
    {id = 1, name = "Jack Spark", benefit = "+25% Win Scaling", downside = "Cooldown: 3 spins", flavor = "Ignite the reels with explosive potential", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.25 }},
    {id = 2, name = "Lucky Charge", benefit = "+40% Win Bonus (on score)", downside = "-10% Base Wins", flavor = "Luck favors the bold", rarity = "Premium", cost = 12,
        effects = { conditional = { flat_multiplier = 0.4 }, trigger = { type = "score" } }},
    {id = 3, name = "House Shield", benefit = "Reduced net loss on failures", downside = "-15% Max Win", flavor = "Protect your balance from chaos", rarity = "Standard", cost = 8,
        effects = { percent_balance_bet_increase = 0.00, flat_multiplier = 0.0, currency = { gem_gain_mult = 1.0 } }},
    {id = 4, name = "Winning Momentum", benefit = "+20% Per Consecutive Win", downside = "Resets on loss", flavor = "Build speed with each victory", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.20 }},
    {id = 5, name = "Quantum Gambit", benefit = "+60% Flat Win Bonus", downside = "Unpredictable", flavor = "Defy probability's expectations", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.6 }},

    -- Row 2
    {id = 6, name = "Time Buffer", benefit = "+35% QTE Time", downside = "Longer QTE cooldown", flavor = "Bend time to your advantage", rarity = "Premium", cost = 12,
        effects = { shop = { extra_items = 0 }, currency = {}, },
    },
    {id = 7, name = "Gem Magnet", benefit = "+50% Gem Gain", downside = "Consumes spins to power", flavor = "Attract riches from the void", rarity = "High-Roller", cost = 16,
        effects = { currency = { gem_gain_mult = 1.50 } }},
    {id = 8, name = "Tight Aim", benefit = "+18% Win Scaling", downside = "-25% Spin Speed", flavor = "Perfect your aim with laser focus", rarity = "Premium", cost = 12,
        effects = { scaling_multiplier = 0.18 }},
    {id = 9, name = "Echo Pulse", benefit = "+35% Slot-3 Bonus (conditional)", downside = "-10% Defense", flavor = "Let your failures echo back", rarity = "Premium", cost = 12,
        effects = { conditional = { flat_multiplier = 0.35 }, trigger = { type = "slot", slot = 3 } }},
    {id = 10, name = "Crystal Bank", benefit = "+100% Block Efficiency", downside = "-30% Speed", flavor = "Become unbreakable crystal", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 1.0 }},

    -- Row 3
    {id = 11, name = "Blaze Bet", benefit = "+55% Slot-1 Scaling (conditional)", downside = "+10% Heat Risk", flavor = "Embrace the burning flame", rarity = "Premium", cost = 12,
        effects = { conditional = { scaling_multiplier = 0.55 }, trigger = { type = "slot", slot = 1 } }},
    {id = 12, name = "Frost Bet", benefit = "+40% Flat Win Bonus", downside = "-20% Mobility", flavor = "Freeze time itself", rarity = "Standard", cost = 8,
        effects = { flat_multiplier = 0.4 }},
    {id = 13, name = "Chain Spark", benefit = "+50% Chain Scaling", downside = "Increased costs", flavor = "Channel pure electric fury", rarity = "Premium", cost = 12,
        effects = { scaling_multiplier = 0.50 }},
    {id = 14, name = "Green Return", benefit = "+15% Gem Gain", downside = "Slower regen", flavor = "Nature's nurturing embrace", rarity = "High-Roller", cost = 16,
        effects = { currency = { gem_gain_mult = 1.15 } }},
    {id = 15, name = "Shadow Split", benefit = "+20% Flat Bonus", downside = "-40% Clone Value", flavor = "Multiply your presence", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.2 }},

    -- Row 4
    {id = 16, name = "Rogue Surge", benefit = "+100% Flat Bonus", downside = "-50% Safety", flavor = "Cast off restraint and fury", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 1.0, percent_balance_bet_increase = 0.05 }},
    {id = 17, name = "Ghost Bet", benefit = "+30% Flat Bonus", downside = "-30% Reward Cap", flavor = "Become one with the shadows", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.3 }},
    {id = 18, name = "House Restore", benefit = "One-time Restore Bonus", downside = "-50% Spin Speed", flavor = "Heal all wounds instantly", rarity = "VIP", cost = 20,
        effects = { flat_bet_increase = 0 }},
    {id = 19, name = "Pull Odds", benefit = "+40% Slot-2 Scaling (conditional)", downside = "Slows other effects", flavor = "Command the very fabric of space", rarity = "Premium", cost = 12,
        effects = { conditional = { scaling_multiplier = 0.40 }, trigger = { type = "slot", slot = 2 } }},
    {id = 20, name = "Phoenix Stake", benefit = "+50% Flat Bonus", downside = "Long cooldown", flavor = "Rise anew from the ashes", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 0.5 }},

    -- Row 5
    {id = 21, name = "Blessing Bet", benefit = "+25% Win Scaling", downside = "+20% Shop Cost", flavor = "Divine favor shines upon you", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.25, shop = { reroll_cost_mult = 1.2 } }},
    {id = 22, name = "Curse Break", benefit = "+50% Flat Bonus", downside = "Attracts curses", flavor = "Shatter magical chains", rarity = "Premium", cost = 12,
        effects = { flat_multiplier = 0.5 }},
    {id = 23, name = "Thunderjack", benefit = "+65% Flat Bonus", downside = "Increases volatility", flavor = "Call down celestial wrath", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.65 }},
    {id = 24, name = "Void Exchange", benefit = "+45% Gem Conversion", downside = "-15% Max Win", flavor = "Siphon vitality from your foes", rarity = "Premium", cost = 12,
        effects = { currency = { gem_conversion_mult = 1.45 } }},
    {id = 25, name = "Mirror Bet", benefit = "Reflect 50% Reward", downside = "-20% Block Chance", flavor = "Turn attacks upon their source", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.5 }},

    -- Row 6
    {id = 26, name = "Turbo Spin", benefit = "+80% Win Scaling", downside = "-50% Control", flavor = "Rush forward without hesitation", rarity = "High-Roller", cost = 16,
        effects = { scaling_multiplier = 0.8 }},
    {id = 27, name = "Calm Returns", benefit = "+10% Gem Gain", downside = "-40% Action Speed", flavor = "Find peace in the chaos", rarity = "Standard", cost = 8,
        effects = { currency = { gem_gain_mult = 1.10 } }},
    {id = 28, name = "Blade Bet", benefit = "+90% Flat Bonus", downside = "-30% Durability", flavor = "Unleash primal cutting power", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 0.9 }},
    {id = 29, name = "Phase Play", benefit = "+35% Slot-5 Scaling (conditional)", downside = "-50% Physical Value", flavor = "Exist between realities", rarity = "VIP", cost = 20,
        effects = { conditional = { scaling_multiplier = 0.35 }, trigger = { type = "slot", slot = 5 } }},
    {id = 30, name = "Vaulted", benefit = "+70% Flat Bonus", downside = "-35% Speed", flavor = "Steel yourself against all harm", rarity = "Premium", cost = 12,
        effects = { flat_multiplier = 0.7 }},

    -- Row 7
    {id = 31, name = "Pact Wager", benefit = "+50% Flat Bonus", downside = "-25% Healing", flavor = "Trade vitality for power", rarity = "Premium", cost = 12,
        effects = { flat_multiplier = 0.5 }},
    {id = 32, name = "Sanctum Bet", benefit = "Minor shop bonus", downside = "Immobilized within", flavor = "Create a sanctified space", rarity = "High-Roller", cost = 16,
        effects = { shop = { extra_items = 0 } }},
    {id = 33, name = "Penetration Bet", benefit = "+55% Scaling", downside = "-20% Speed", flavor = "Tear through defenses", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.55 }},
    {id = 34, name = "Regrowth", benefit = "+5% Gem Gain", downside = "-10% Output", flavor = "Endless vitality flows within", rarity = "Premium", cost = 12,
        effects = { currency = { gem_gain_mult = 1.05 } }},
    {id = 35, name = "Smoke Out", benefit = "+25% Flat Bonus", downside = "-30% Offense", flavor = "Vanish without a trace", rarity = "Standard", cost = 8,
        effects = { flat_multiplier = 0.25 }},

    -- Row 8
    {id = 36, name = "Roar Jackpot", benefit = "+60% Flat Bonus", downside = "Visual deafness", flavor = "Let loose an ancient howl", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.6 }},
    {id = 37, name = "Keen Edge", benefit = "+35% Scaling", downside = "-25% Base Reward", flavor = "See weakness in all things", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.35 }},
    {id = 38, name = "Clear Bet", benefit = "+80% Flat Bonus", downside = "-30% Max Health", flavor = "Cleanse all corruption", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.8 }},
    {id = 39, name = "Frenzy Stake", benefit = "+70% Flat Bonus", downside = "Aggressive behavior", flavor = "Hunger for enemy essence", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 0.7 }},
    {id = 40, name = "Anchor Hold", benefit = "+90% Flat Bonus", downside = "-40% Movement", flavor = "Root yourself in place", rarity = "Premium", cost = 12,
        effects = { flat_multiplier = 0.9 }},

    -- Row 9
    {id = 41, name = "Stellar Chip", benefit = "+50% Scaling", downside = "-20% Dark Resistance", flavor = "Harness celestial radiance", rarity = "Premium", cost = 12,
        effects = { scaling_multiplier = 0.50 }},
    {id = 42, name = "Abyss Chip", benefit = "+60% Flat Bonus", downside = "-25% Light Resistance", flavor = "Embrace the infinite void", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.6 }},
    {id = 43, name = "Equilibrium", benefit = "+25% Scaling", downside = "-15% Output", flavor = "Walk the middle path", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.25 }},
    {id = 44, name = "Eruption Bet", benefit = "+75% Flat Bonus", downside = "Damages self too", flavor = "Detonate with volcanic force", rarity = "VIP", cost = 20,
        effects = { flat_multiplier = 0.75 }},
    {id = 45, name = "Silent Wager", benefit = "+40% Scaling", downside = "-10% Healing", flavor = "Spread toxic whispers", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.40 }},

    -- Row 10
    {id = 46, name = "Ascend Chip", benefit = "+85% Gem Gain", downside = "-20% Base Stats", flavor = "Rise above your limits", rarity = "VIP", cost = 20,
        effects = { currency = { gem_gain_mult = 1.85 } }},
    {id = 47, name = "Decay Wager", benefit = "+50% Flat Bonus", downside = "-30% Healing", flavor = "Let weakness consume them", rarity = "Premium", cost = 12,
        effects = { flat_multiplier = 0.5 }},
    {id = 48, name = "Resonant Bet", benefit = "+45% Scaling", downside = "-25% Buff Strength", flavor = "Amplify magical harmonies", rarity = "Standard", cost = 8,
        effects = { scaling_multiplier = 0.45 }},
    {id = 49, name = "Apex Stake", benefit = "+55% Flat Bonus", downside = "Vulnerable when damaged", flavor = "Peak performance only", rarity = "High-Roller", cost = 16,
        effects = { flat_multiplier = 0.55 }},
    {id = 50, name = "Genesis Spin", benefit = "Double Gem Conversion", downside = "-50% Combat Power", flavor = "Rebirth endless cycles", rarity = "VIP", cost = 20,
        effects = { currency = { gem_conversion_mult = 2.0 } }},
}

-- Track assigned upgrades per shop session
local shop_assigned_upgrades = {}

-- Generate 3 unique random upgrades for the shop
function UpgradeNode.generate_shop_upgrades(count)
    count = count or 3
    shop_assigned_upgrades = {}

    -- Build candidate list with weights derived from rarity
    local candidates = {}
    -- Allow upgrade effects to bias rare weights
    local UpgradeEffects = require("systems.upgrade_effects")
    local shop_mods = UpgradeEffects.get_shop_mods() or {}
    local rare_bonus = shop_mods.rare_weight_bonus or 0

    for id = 1, 50 do
        local def = UpgradeNode.get_definition(id)
        -- Skip upgrades already purchased this round or currently owned
        if not UpgradeNode.is_purchased_this_round(id) then
            local owned = false
            for _, s in ipairs(selected_upgrades) do if s.upgrade_id == id then owned = true; break end end
            if not owned then
                local rarity = def and def.rarity or "Standard"
                local weight = RARITY_WEIGHTS[rarity] or 1
                -- If upgrade effects increase rare likelihood, increase weight for rarer tiers
                if rarity ~= "Standard" and rare_bonus and rare_bonus > 0 then
                    weight = weight + rare_bonus
                end
                table.insert(candidates, { id = id, weight = weight })
            end
        end
    end

    -- Weighted pick without replacement
    local function pick_one()
        local total = 0
        for _, c in ipairs(candidates) do total = total + c.weight end
        if total <= 0 then return nil end

        -- RNG: use local LCG if seed set, otherwise math.random
        local r
        if shop_rng_state then
            -- LCG parameters (Park-Miller)
            shop_rng_state = (shop_rng_state * 16807) % 2147483647
            r = (shop_rng_state / 2147483647) * total
        else
            r = math.random() * total
        end

        local acc = 0
        for i, c in ipairs(candidates) do
            acc = acc + c.weight
            if r <= acc then
                local id = c.id
                table.remove(candidates, i)
                return id
            end
        end
        -- Fallback
        local last = table.remove(candidates)
        return last and last.id
    end

    for i = 1, count do
        local pick = pick_one()
        if pick then
            table.insert(shop_assigned_upgrades, pick)
        end
    end

    return shop_assigned_upgrades
end

-- Get the upgrade ID for a specific box (1-3)
function UpgradeNode.get_box_upgrade(box_index)
    if box_index >= 1 and box_index <= 3 and #shop_assigned_upgrades >= 3 then
        return shop_assigned_upgrades[box_index]
    end
    return nil
end

-- Initialize upgrade nodes
function UpgradeNode.initialize()
    print("[UPGRADE_NODE] Upgrade node system initialized")
end

-- Load upgrade node resources
function UpgradeNode.load()
    print("[UPGRADE_NODE] Upgrade nodes loaded")
end

-- Update upgrade nodes
-- Unified update: advances sprites, runs trigger sequencing, and cleans up removals
function UpgradeNode.update(dt)
    -- Update all sprites first (advance animations / wobble / pulses)
    for _, sprite in ipairs(selected_upgrades) do
        UpgradeSprite.update(sprite, dt)
    end

    -- Process scoring-time trigger queue (sequential pulses)
    if _trigger_callback and _trigger_queue and #_trigger_queue > 0 then
        if _trigger_timer > 0 then
            _trigger_timer = _trigger_timer - dt
            if _trigger_timer <= 0 then
                -- move to next trigger
                _trigger_index = _trigger_index + 1
                if _trigger_index > #_trigger_queue then
                    -- finished
                    local cb = _trigger_callback
                    _trigger_callback = nil
                    _trigger_queue = nil
                    _trigger_index = 0
                    _trigger_timer = 0
                    if cb then cb() end
                else
                    -- start next pulse
                    local entry = _trigger_queue[_trigger_index]
                    if entry and entry.sprite then
                        UpgradeSprite.start_pulse(entry.sprite, entry.duration or 0.45, entry.scale or 1.5)
                        local mult = math.max(_trigger_min_multiplier, (_trigger_base_multiplier or 1.0) * ((_trigger_accel or 1.0) ^ (_trigger_index - 1)))
                        local dur = (entry.duration or 0.45) * mult
                        local gap = (entry.gap or 0.12) * mult
                        _trigger_timer = dur + gap
                    else
                        -- skip invalid and continue
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
                local mult = math.max(_trigger_min_multiplier, (_trigger_base_multiplier or 1.0) * ((_trigger_accel or 1.0) ^ (_trigger_index - 1)))
                local dur = (entry.duration or 0.45) * mult
                local gap = (entry.gap or 0.12) * mult
                _trigger_timer = dur + gap
            else
                -- nothing to trigger
                local cb = _trigger_callback
                _trigger_callback = nil
                _trigger_queue = nil
                _trigger_index = 0
                _trigger_timer = 0
                if cb then cb() end
            end
        end
    end

    -- Finally, remove any sprites marked for deletion and animate repositioning if needed
    for i = #selected_upgrades, 1, -1 do
        local sprite = selected_upgrades[i]
        -- Ensure sprite animations advance (already updated above, but keep check)
        -- Remove completed departing sprites
        if sprite.to_remove then
            print(string.format("[UPGRADE_NODE] Removing upgrade %d at index %d", sprite.upgrade_id or -1, i))
            table.remove(selected_upgrades, i)
            UpgradeNode.animate_reposition_owned_upgrades(0.28)
        end
    end
end

-- Draw upgrade nodes
function UpgradeNode.draw()
    -- Draw logic goes here
end

-- Get upgrade definition by ID
function UpgradeNode.get_definition(id)
    if id >= 1 and id <= 50 then
        return UPGRADE_DEFINITIONS[id]
    end
    return nil
end

-- Get the buy cost of an upgrade
function UpgradeNode.get_buy_cost(upgrade_id)
    local def = UpgradeNode.get_definition(upgrade_id)
    if def then
        return def.cost
    end
    return 0
end

-- Get the sell value of an upgrade (based on sell rate)
function UpgradeNode.get_sell_value(upgrade_id)
    local buy_cost = UpgradeNode.get_buy_cost(upgrade_id)
    return math.floor(buy_cost * SELL_RATE)
end

function UpgradeNode.reposition_owned_upgrades()
    -- Immediately snap all owned upgrades to their correct positions based on indices
    -- No animations - just direct positioning for 100% reliability
    local flying_sprite_size = 128
    local usable_width = Config.SLOT_WIDTH * UIConfig.DISPLAY_BOX_COUNT
    local spacing_x = usable_width / (5 + 1)
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local center_y = box_y + BOX_HEIGHT / 2
    local start_x_box = Config.PADDING_X + 30

    for i, sprite in ipairs(selected_upgrades) do
        -- Ensure sprite has valid index
        sprite.index = i

        -- Calculate target position
        local target_x = start_x_box + 10 + spacing_x * i
        local target_y = center_y - flying_sprite_size / 2

        -- For purchasing sprites, update target and accelerate
        if sprite.state == "purchasing" then
            sprite.target_x = target_x
            sprite.target_y = target_y
            -- Accelerate remaining animation
            if sprite.animation_duration and sprite.animation_progress then
                local remaining = math.max(0, sprite.animation_duration - sprite.animation_progress)
                sprite.animation_duration = sprite.animation_progress + remaining * 0.5
            end
        else
            -- For all other sprites, snap directly to position and settle
            sprite.state = "owned"
            sprite.x = target_x
            sprite.y = target_y
            sprite.animation_progress = 0
            sprite.animation_duration = 0
            sprite.target_x = target_x
            sprite.target_y = target_y
        end
    end

end
-- Modified reposition: if any departing animations are active, use animated repositioning
local _orig_reposition = UpgradeNode.reposition_owned_upgrades
function UpgradeNode.reposition_owned_upgrades()
    -- If any sprite is departing, animate reposition instead of snapping
    for _, s in ipairs(selected_upgrades) do
        if s.state == "departing" or s.to_remove then
            UpgradeNode.animate_reposition_owned_upgrades(0.28)
            return
        end
    end
    -- No departing sprites: perform immediate snap
    local flying_sprite_size = 128
    local usable_width = Config.SLOT_WIDTH * UIConfig.DISPLAY_BOX_COUNT
    local spacing_x = usable_width / (5 + 1)
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local center_y = box_y + BOX_HEIGHT / 2
    local start_x_box = Config.PADDING_X + 30

    for i, sprite in ipairs(selected_upgrades) do
        sprite.index = i

        local target_x = start_x_box + 10 + spacing_x * i
        local target_y = center_y - flying_sprite_size / 2

        sprite.state = "owned"
        sprite.x = target_x
        sprite.y = target_y
        sprite.animation_progress = 0
        sprite.animation_duration = 0
        sprite.target_x = target_x
        sprite.target_y = target_y
    end
end

function UpgradeNode.select_upgrade(upgrade_id)
    if #selected_upgrades < MAX_SELECTED_UPGRADES then
        -- Create new upgrade sprite in owned state
        local sprite = UpgradeSprite.create(upgrade_id, "owned")
        
        -- Insert at position 1 (leftmost)
        table.insert(selected_upgrades, 1, sprite)
        
        -- Update indices for all selected upgrades
        for i, spr in ipairs(selected_upgrades) do
            spr.index = i
        end
        
        return true
    end
    return false
end

-- (Removed duplicate/older LERP-based reposition function)

function UpgradeNode.get_selected_upgrades()
    return selected_upgrades
end

function UpgradeNode.add_flying_upgrade(upgrade_id, start_x, start_y)
    -- Find the sprite for this upgrade and use its assigned index
    local target_sprite = nil
    for i, sprite in ipairs(selected_upgrades) do
        if sprite.upgrade_id == upgrade_id then
            target_sprite = sprite
            break
        end
    end
    if not target_sprite then return end

    -- Prefer the sprite's explicit index (set during selection/reorder);
    -- fall back to the current length if missing, and clamp to valid range
    local final_index = target_sprite.index or #selected_upgrades
    final_index = math.max(1, math.min(final_index, math.max(1, #selected_upgrades)))
    
    -- Flying sprite will be 128x128
    local flying_sprite_size = 128
    
    -- Adjust start position to account for sprite size
    local adjusted_start_x = start_x - flying_sprite_size / 2
    local adjusted_start_y = start_y - flying_sprite_size / 2
    
    -- Calculate target position based on final index
    local usable_width = Config.SLOT_WIDTH * UIConfig.DISPLAY_BOX_COUNT
    local spacing_x = usable_width / (5 + 1)
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local center_y = box_y + BOX_HEIGHT / 2
    local start_x_box = Config.PADDING_X + 30
    
    -- Position based on final index (use index as 1..n)
    local target_x = start_x_box + 10 + spacing_x * final_index
    local target_y = center_y - flying_sprite_size / 2
    
    -- Start the purchasing animation
    UpgradeSprite.start_purchasing(target_sprite, adjusted_start_x, adjusted_start_y, target_x, target_y, 0.6)
end

-- (duplicate update removed; unified `UpgradeNode.update` is defined earlier)

-- Called by SlotMachine to run visual pulses for upgrades before scoring calculations
-- vals: array of symbol indices per slot (1..num_slots)
function UpgradeNode.handle_score_triggers(vals, state, on_complete)
    -- If a trigger queue is already processing, bail immediately to avoid reentrant calls
    if _trigger_queue and #_trigger_queue > 0 then
        if on_complete then on_complete() end
        return
    end

    -- Build queue of selected upgrades to pulse. Respect per-upgrade trigger metadata if present.
    _trigger_queue = {}
    for _, sprite in ipairs(selected_upgrades) do
        local def = UpgradeNode.get_definition(sprite.upgrade_id)
        if def then
            local allow = false
            if def.trigger == nil then
                -- default: trigger on score
                allow = true
            elseif def.trigger.type == "score" then
                allow = true
            elseif def.trigger.type == "slot" then
                local slot_idx = def.trigger.slot or 1
                local symbol_cond = def.trigger.symbol -- optional
                if vals and vals[slot_idx] then
                    if not symbol_cond or vals[slot_idx] == symbol_cond then
                        allow = true
                    end
                end
            end
            if allow then
                table.insert(_trigger_queue, { sprite = sprite, duration = def.pulse_duration, scale = def.pulse_scale, text = def.flavor, color = def.pulse_color, gap = def.pulse_gap })
            end
        end
    end

    if #_trigger_queue == 0 then
        -- nothing to do
        if on_complete then on_complete() end
        return
    end

    _trigger_callback = on_complete
    _trigger_index = 0
    _trigger_timer = 0
end

function UpgradeNode.get_flying_upgrades()
    -- Return sprites that are in purchasing state
    local flying = {}
    for _, sprite in ipairs(selected_upgrades) do
        if sprite.state == "purchasing" then
            table.insert(flying, sprite)
        end
    end
    return flying
end

-- Update upgrade node animations and cleanup departing sprites
-- (update implemented above)

-- Animate repositioning of owned upgrades (instead of snapping)
function UpgradeNode.animate_reposition_owned_upgrades(duration)
    duration = duration or 0.28
    local flying_sprite_size = 128
    local usable_width = Config.SLOT_WIDTH * UIConfig.DISPLAY_BOX_COUNT
    local spacing_x = usable_width / (5 + 1)
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local center_y = box_y + BOX_HEIGHT / 2
    local start_x_box = Config.PADDING_X + 30

    for i, sprite in ipairs(selected_upgrades) do
        sprite.index = i
        local target_x = start_x_box + 10 + spacing_x * i
        local target_y = center_y - flying_sprite_size / 2
        -- Don't interrupt a departing sprite's removal animation
        if sprite.state ~= "departing" and not sprite.to_remove then
            UpgradeSprite.start_shifting(sprite, target_x, target_y, duration)
        end
    end
end

function UpgradeNode.get_shift_animations()
    return {}  -- No longer needed with new sprite system
end

function UpgradeNode.get_max_selected_upgrades()
    return MAX_SELECTED_UPGRADES
end

function UpgradeNode.remove_selected_upgrade(index)
    local sprite = selected_upgrades[index]
    if not sprite then return end
    if sprite.state ~= "departing" then
        sprite.state = "departing"
        sprite.animation_duration = 0.35
        sprite.animation_progress = 0
        sprite.to_remove = false
        sprite.display_alpha = 1
    end
end

function UpgradeNode.remove_upgrade(upgrade_id)
    -- Immediately remove the sprite for deterministic SELL behavior
    for i = #selected_upgrades, 1, -1 do
        local sprite = selected_upgrades[i]
        if sprite and sprite.upgrade_id == upgrade_id then
            print(string.format("[UPGRADE_NODE] Immediately removing upgrade %d at index %d (sell)", upgrade_id, i))
            table.remove(selected_upgrades, i)
            -- Re-layout remaining owned upgrades
            UpgradeNode.animate_reposition_owned_upgrades(0.18)
            return true
        end
    end
    return false
end

function UpgradeNode.reorder_selected_upgrade(from_index, to_index)
    if from_index >= 1 and from_index <= #selected_upgrades and
       to_index >= 1 and to_index <= #selected_upgrades then
        local upgrade = table.remove(selected_upgrades, from_index)
        table.insert(selected_upgrades, to_index, upgrade)
    end
end

function UpgradeNode.clear_selected_upgrades()
    selected_upgrades = {}
    flying_upgrades = {}
    shift_animations = {}
end

return UpgradeNode
