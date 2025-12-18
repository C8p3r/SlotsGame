-- upgrade_node.lua
-- Upgrade node system for managing upgradeable game elements

local Config = require("conf")
local UIConfig = require("ui.ui_config")
local UpgradeSprite = require("systems.upgrade_sprite")

local UpgradeNode = {}

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
    {id = 1, name = "Fire Burst", benefit = "+25% Symbol Value", downside = "Cooldown: 3 spins", flavor = "Ignite the reels with explosive potential", rarity = "Standard", cost = 8},
    {id = 2, name = "Lucky Strike", benefit = "+40% Critical Hit Chance", downside = "-10% Base Wins", flavor = "Harness the power of fortune itself", rarity = "Premium", cost = 12},
    {id = 3, name = "Shield Generator", benefit = "-50% Spin Loss", downside = "-15% Max Win", flavor = "Protect your balance from chaos", rarity = "Standard", cost = 8},
    {id = 4, name = "Momentum", benefit = "+20% Per Consecutive Win", downside = "Resets on loss", flavor = "Build speed with each victory", rarity = "Standard", cost = 8},
    {id = 5, name = "Quantum Leap", benefit = "+60% Random Jackpot", downside = "Unpredictable", flavor = "Defy probability's expectations", rarity = "High-Roller", cost = 16},
    
    -- Row 2
    {id = 6, name = "Time Warp", benefit = "+35% QTE Duration", downside = "-20% Circle Shrink Speed", flavor = "Bend time to your advantage", rarity = "Premium", cost = 12},
    {id = 7, name = "Wealth Magnet", benefit = "+50% Gem Gain", downside = "Drains spins", flavor = "Attract riches from the void", rarity = "High-Roller", cost = 16},
    {id = 8, name = "Precision", benefit = "+45% Accuracy", downside = "-25% Spin Speed", flavor = "Perfect your aim with laser focus", rarity = "Premium", cost = 12},
    {id = 9, name = "Void Echo", benefit = "+35% Damage Reflection", downside = "-10% Defense", flavor = "Let your failures echo back", rarity = "Premium", cost = 12},
    {id = 10, name = "Crystalline Form", benefit = "+100% Blockable Hits", downside = "-30% Speed", flavor = "Become unbreakable crystal", rarity = "VIP", cost = 20},
    
    -- Row 3
    {id = 11, name = "Inferno Aura", benefit = "+55% Fire Damage", downside = "+10% Heat Buildup", flavor = "Embrace the burning flame", rarity = "Premium", cost = 12},
    {id = 12, name = "Frostbolt", benefit = "+40% Freeze Duration", downside = "-20% Mobility", flavor = "Freeze time itself", rarity = "Standard", cost = 8},
    {id = 13, name = "Static Charge", benefit = "+50% Electricity Damage", downside = "Chains nearby enemies", flavor = "Channel pure electric fury", rarity = "Premium", cost = 12},
    {id = 14, name = "Verdant Growth", benefit = "+60% Healing", downside = "Slower regen", flavor = "Nature's nurturing embrace", rarity = "High-Roller", cost = 16},
    {id = 15, name = "Shadow Clone", benefit = "+2 Clones", downside = "-40% Clone Health", flavor = "Multiply your presence", rarity = "High-Roller", cost = 16},
    
    -- Row 4
    {id = 16, name = "Berserk Mode", benefit = "+100% Attack Power", downside = "-50% Defense", flavor = "Cast off restraint and fury", rarity = "VIP", cost = 20},
    {id = 17, name = "Invisible Step", benefit = "+70% Evasion", downside = "-30% Damage", flavor = "Become one with the shadows", rarity = "High-Roller", cost = 16},
    {id = 18, name = "Restoration", benefit = "Full HP Restore", downside = "-50% Spin Speed", flavor = "Heal all wounds instantly", rarity = "VIP", cost = 20},
    {id = 19, name = "Gravity Well", benefit = "+40% Pull Strength", downside = "Slows movement", flavor = "Command the very fabric of space", rarity = "Premium", cost = 12},
    {id = 20, name = "Phoenix Fire", benefit = "Resurrect Once", downside = "Long cooldown", flavor = "Rise anew from the ashes", rarity = "VIP", cost = 20},
    
    -- Row 5
    {id = 21, name = "Blessing", benefit = "+25% All Stats", downside = "+20% Cost", flavor = "Divine favor shines upon you", rarity = "Standard", cost = 8},
    {id = 22, name = "Curse Breaker", benefit = "+50% Resist", downside = "Attracts curses", flavor = "Shatter magical chains", rarity = "Premium", cost = 12},
    {id = 23, name = "Thunderstrike", benefit = "+65% Lightning Damage", downside = "Attracts enemies", flavor = "Call down celestial wrath", rarity = "High-Roller", cost = 16},
    {id = 24, name = "Void Drain", benefit = "+45% Life Steal", downside = "-15% Max HP", flavor = "Siphon vitality from your foes", rarity = "Premium", cost = 12},
    {id = 25, name = "Mirror Shield", benefit = "Reflect 50% Damage", downside = "-20% Block Chance", flavor = "Turn attacks upon their source", rarity = "High-Roller", cost = 16},
    
    -- Row 6
    {id = 26, name = "Acceleration", benefit = "+80% Movement Speed", downside = "-50% Control", flavor = "Rush forward without hesitation", rarity = "High-Roller", cost = 16},
    {id = 27, name = "Meditation", benefit = "+30% Mana Regen", downside = "-40% Action Speed", flavor = "Find peace in the chaos", rarity = "Standard", cost = 8},
    {id = 28, name = "Savage Blade", benefit = "+90% Slash Damage", downside = "-30% Durability", flavor = "Unleash primal cutting power", rarity = "VIP", cost = 20},
    {id = 29, name = "Ethereal Form", benefit = "Phase Through Walls", downside = "-50% Physical Damage", flavor = "Exist between realities", rarity = "VIP", cost = 20},
    {id = 30, name = "Fortified", benefit = "+70% Armor", downside = "-35% Speed", flavor = "Steel yourself against all harm", rarity = "Premium", cost = 12},
    
    -- Row 7
    {id = 31, name = "Blood Pact", benefit = "+50% Max HP", downside = "-25% Healing", flavor = "Trade vitality for power", rarity = "Premium", cost = 12},
    {id = 32, name = "Sacred Ground", benefit = "Gain Safe Zone", downside = "Immobilized within", flavor = "Create a sanctified space", rarity = "High-Roller", cost = 16},
    {id = 33, name = "Rend", benefit = "+55% Armor Penetration", downside = "-20% Attack Speed", flavor = "Tear through defenses", rarity = "Standard", cost = 8},
    {id = 34, name = "Regeneration", benefit = "+40% HP Recovery", downside = "-10% Damage", flavor = "Endless vitality flows within", rarity = "Premium", cost = 12},
    {id = 35, name = "Smoke Bomb", benefit = "+50% Escape Chance", downside = "-30% Offense", flavor = "Vanish without a trace", rarity = "Standard", cost = 8},
    
    -- Row 8
    {id = 36, name = "Primal Roar", benefit = "+60% Shout Damage", downside = "Deafens you", flavor = "Let loose an ancient howl", rarity = "High-Roller", cost = 16},
    {id = 37, name = "Insight", benefit = "+35% Critical Damage", downside = "-25% Base Damage", flavor = "See weakness in all things", rarity = "Standard", cost = 8},
    {id = 38, name = "Purify", benefit = "+80% Status Cleanse", downside = "-30% Max Health", flavor = "Cleanse all corruption", rarity = "High-Roller", cost = 16},
    {id = 39, name = "Bloodlust", benefit = "+70% Lifesteal", downside = "Constant aggression", flavor = "Hunger for enemy essence", rarity = "VIP", cost = 20},
    {id = 40, name = "Anchor", benefit = "+90% Knockback Resist", downside = "-40% Movement", flavor = "Root yourself in place", rarity = "Premium", cost = 12},
    
    -- Row 9
    {id = 41, name = "Starlight", benefit = "+50% Holy Damage", downside = "-20% Dark Resistance", flavor = "Harness celestial radiance", rarity = "Premium", cost = 12},
    {id = 42, name = "Abyss", benefit = "+60% Dark Damage", downside = "-25% Light Resistance", flavor = "Embrace the infinite void", rarity = "High-Roller", cost = 16},
    {id = 43, name = "Balance", benefit = "+25% All Resistances", downside = "-15% All Damage", flavor = "Walk the middle path", rarity = "Standard", cost = 8},
    {id = 44, name = "Eruption", benefit = "+75% Area Damage", downside = "Damages self too", flavor = "Detonate with volcanic force", rarity = "VIP", cost = 20},
    {id = 45, name = "Whisper", benefit = "+40% Poison Damage", downside = "-10% Healing", flavor = "Spread toxic whispers", rarity = "Standard", cost = 8},
    
    -- Row 10
    {id = 46, name = "Ascension", benefit = "+85% Experience Gain", downside = "-20% Base Stats", flavor = "Rise above your limits", rarity = "VIP", cost = 20},
    {id = 47, name = "Decay", benefit = "+50% Debuff Duration", downside = "-30% Healing", flavor = "Let weakness consume them", rarity = "Premium", cost = 12},
    {id = 48, name = "Resonance", benefit = "+45% Buff Duration", downside = "-25% Buff Strength", flavor = "Amplify magical harmonies", rarity = "Standard", cost = 8},
    {id = 49, name = "Apex", benefit = "+55% Power At Full Health", downside = "Vulnerable when damaged", flavor = "Peak performance only", rarity = "High-Roller", cost = 16},
    {id = 50, name = "Genesis", benefit = "+100% Respawn Speed", downside = "-50% Combat Power", flavor = "Rebirth endless cycles", rarity = "VIP", cost = 20},
}

-- Track assigned upgrades per shop session
local shop_assigned_upgrades = {}

-- Generate 3 unique random upgrades for the shop
function UpgradeNode.generate_shop_upgrades()
    shop_assigned_upgrades = {}

    -- Build candidate list with weights derived from rarity
    local candidates = {}
    for id = 1, 50 do
        local def = UpgradeNode.get_definition(id)
        local rarity = def and def.rarity or "Standard"
        local weight = RARITY_WEIGHTS[rarity] or 1
        table.insert(candidates, { id = id, weight = weight })
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

    for i = 1, 3 do
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
function UpgradeNode.update(dt)
    -- Update logic goes here
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

function UpgradeNode.update(dt)
    -- Update all sprites
    for _, sprite in ipairs(selected_upgrades) do
        UpgradeSprite.update(sprite, dt)
    end
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

function UpgradeNode.get_shift_animations()
    return {}  -- No longer needed with new sprite system
end

function UpgradeNode.get_max_selected_upgrades()
    return MAX_SELECTED_UPGRADES
end

function UpgradeNode.remove_selected_upgrade(index)
    table.remove(selected_upgrades, index)
end

function UpgradeNode.remove_upgrade(upgrade_id)
    -- Find the index of the upgrade sprite with this ID and remove it
    for i, sprite in ipairs(selected_upgrades) do
        if sprite.upgrade_id == upgrade_id then
            table.remove(selected_upgrades, i)
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
