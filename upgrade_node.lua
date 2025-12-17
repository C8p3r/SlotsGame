-- upgrade_node.lua
-- Upgrade node system for managing upgradeable game elements

local Config = require("conf")

local UpgradeNode = {}

-- Selected/acquired upgrades (those bought from the shop)
local selected_upgrades = {}  -- Table of upgrade IDs that have been selected
local MAX_SELECTED_UPGRADES = 5

-- Flying upgrade animation state
local flying_upgrades = {}  -- Table of {upgrade_id, start_x, start_y, duration, elapsed}

-- Shift animation state (when new upgrades push others to the right)
local shift_animations = {}  -- Table of {upgrade_index, duration, elapsed}

-- Define all 50 upgrades (5 cols × 10 rows from upgrade_units_UI.png)
local UPGRADE_DEFINITIONS = {
    -- Row 1
    {id = 1, name = "Fire Burst", benefit = "+25% Symbol Value", downside = "Cooldown: 3 spins", flavor = "Ignite the reels with explosive potential"},
    {id = 2, name = "Lucky Strike", benefit = "+40% Critical Hit Chance", downside = "-10% Base Wins", flavor = "Harness the power of fortune itself"},
    {id = 3, name = "Shield Generator", benefit = "-50% Spin Loss", downside = "-15% Max Win", flavor = "Protect your balance from chaos"},
    {id = 4, name = "Momentum", benefit = "+20% Per Consecutive Win", downside = "Resets on loss", flavor = "Build speed with each victory"},
    {id = 5, name = "Quantum Leap", benefit = "+60% Random Jackpot", downside = "Unpredictable", flavor = "Defy probability's expectations"},
    
    -- Row 2
    {id = 6, name = "Time Warp", benefit = "+35% QTE Duration", downside = "-20% Circle Shrink Speed", flavor = "Bend time to your advantage"},
    {id = 7, name = "Wealth Magnet", benefit = "+50% Gem Gain", downside = "Drains spins", flavor = "Attract riches from the void"},
    {id = 8, name = "Precision", benefit = "+45% Accuracy", downside = "-25% Spin Speed", flavor = "Perfect your aim with laser focus"},
    {id = 9, name = "Void Echo", benefit = "+35% Damage Reflection", downside = "-10% Defense", flavor = "Let your failures echo back"},
    {id = 10, name = "Crystalline Form", benefit = "+100% Blockable Hits", downside = "-30% Speed", flavor = "Become unbreakable crystal"},
    
    -- Row 3
    {id = 11, name = "Inferno Aura", benefit = "+55% Fire Damage", downside = "+10% Heat Buildup", flavor = "Embrace the burning flame"},
    {id = 12, name = "Frostbolt", benefit = "+40% Freeze Duration", downside = "-20% Mobility", flavor = "Freeze time itself"},
    {id = 13, name = "Static Charge", benefit = "+50% Electricity Damage", downside = "Chains nearby enemies", flavor = "Channel pure electric fury"},
    {id = 14, name = "Verdant Growth", benefit = "+60% Healing", downside = "Slower regen", flavor = "Nature's nurturing embrace"},
    {id = 15, name = "Shadow Clone", benefit = "+2 Clones", downside = "-40% Clone Health", flavor = "Multiply your presence"},
    
    -- Row 4
    {id = 16, name = "Berserk Mode", benefit = "+100% Attack Power", downside = "-50% Defense", flavor = "Cast off restraint and fury"},
    {id = 17, name = "Invisible Step", benefit = "+70% Evasion", downside = "-30% Damage", flavor = "Become one with the shadows"},
    {id = 18, name = "Restoration", benefit = "Full HP Restore", downside = "-50% Spin Speed", flavor = "Heal all wounds instantly"},
    {id = 19, name = "Gravity Well", benefit = "+40% Pull Strength", downside = "Slows movement", flavor = "Command the very fabric of space"},
    {id = 20, name = "Phoenix Fire", benefit = "Resurrect Once", downside = "Long cooldown", flavor = "Rise anew from the ashes"},
    
    -- Row 5
    {id = 21, name = "Blessing", benefit = "+25% All Stats", downside = "+20% Cost", flavor = "Divine favor shines upon you"},
    {id = 22, name = "Curse Breaker", benefit = "+50% Resist", downside = "Attracts curses", flavor = "Shatter magical chains"},
    {id = 23, name = "Thunderstrike", benefit = "+65% Lightning Damage", downside = "Attracts enemies", flavor = "Call down celestial wrath"},
    {id = 24, name = "Void Drain", benefit = "+45% Life Steal", downside = "-15% Max HP", flavor = "Siphon vitality from your foes"},
    {id = 25, name = "Mirror Shield", benefit = "Reflect 50% Damage", downside = "-20% Block Chance", flavor = "Turn attacks upon their source"},
    
    -- Row 6
    {id = 26, name = "Acceleration", benefit = "+80% Movement Speed", downside = "-50% Control", flavor = "Rush forward without hesitation"},
    {id = 27, name = "Meditation", benefit = "+30% Mana Regen", downside = "-40% Action Speed", flavor = "Find peace in the chaos"},
    {id = 28, name = "Savage Blade", benefit = "+90% Slash Damage", downside = "-30% Durability", flavor = "Unleash primal cutting power"},
    {id = 29, name = "Ethereal Form", benefit = "Phase Through Walls", downside = "-50% Physical Damage", flavor = "Exist between realities"},
    {id = 30, name = "Fortified", benefit = "+70% Armor", downside = "-35% Speed", flavor = "Steel yourself against all harm"},
    
    -- Row 7
    {id = 31, name = "Blood Pact", benefit = "+50% Max HP", downside = "-25% Healing", flavor = "Trade vitality for power"},
    {id = 32, name = "Sacred Ground", benefit = "Gain Safe Zone", downside = "Immobilized within", flavor = "Create a sanctified space"},
    {id = 33, name = "Rend", benefit = "+55% Armor Penetration", downside = "-20% Attack Speed", flavor = "Tear through defenses"},
    {id = 34, name = "Regeneration", benefit = "+40% HP Recovery", downside = "-10% Damage", flavor = "Endless vitality flows within"},
    {id = 35, name = "Smoke Bomb", benefit = "+50% Escape Chance", downside = "-30% Offense", flavor = "Vanish without a trace"},
    
    -- Row 8
    {id = 36, name = "Primal Roar", benefit = "+60% Shout Damage", downside = "Deafens you", flavor = "Let loose an ancient howl"},
    {id = 37, name = "Insight", benefit = "+35% Critical Damage", downside = "-25% Base Damage", flavor = "See weakness in all things"},
    {id = 38, name = "Purify", benefit = "+80% Status Cleanse", downside = "-30% Max Health", flavor = "Cleanse all corruption"},
    {id = 39, name = "Bloodlust", benefit = "+70% Lifesteal", downside = "Constant aggression", flavor = "Hunger for enemy essence"},
    {id = 40, name = "Anchor", benefit = "+90% Knockback Resist", downside = "-40% Movement", flavor = "Root yourself in place"},
    
    -- Row 9
    {id = 41, name = "Starlight", benefit = "+50% Holy Damage", downside = "-20% Dark Resistance", flavor = "Harness celestial radiance"},
    {id = 42, name = "Abyss", benefit = "+60% Dark Damage", downside = "-25% Light Resistance", flavor = "Embrace the infinite void"},
    {id = 43, name = "Balance", benefit = "+25% All Resistances", downside = "-15% All Damage", flavor = "Walk the middle path"},
    {id = 44, name = "Eruption", benefit = "+75% Area Damage", downside = "Damages self too", flavor = "Detonate with volcanic force"},
    {id = 45, name = "Whisper", benefit = "+40% Poison Damage", downside = "-10% Healing", flavor = "Spread toxic whispers"},
    
    -- Row 10
    {id = 46, name = "Ascension", benefit = "+85% Experience Gain", downside = "-20% Base Stats", flavor = "Rise above your limits"},
    {id = 47, name = "Decay", benefit = "+50% Debuff Duration", downside = "-30% Healing", flavor = "Let weakness consume them"},
    {id = 48, name = "Resonance", benefit = "+45% Buff Duration", downside = "-25% Buff Strength", flavor = "Amplify magical harmonies"},
    {id = 49, name = "Apex", benefit = "+55% Power At Full Health", downside = "Vulnerable when damaged", flavor = "Peak performance only"},
    {id = 50, name = "Genesis", benefit = "+100% Respawn Speed", downside = "-50% Combat Power", flavor = "Rebirth endless cycles"},
}

-- Track assigned upgrades per shop session
local shop_assigned_upgrades = {}

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

-- Generate 3 unique random upgrades for the shop
function UpgradeNode.generate_shop_upgrades()
    shop_assigned_upgrades = {}
    local available = {}
    
    -- Create list of all upgrade IDs
    for i = 1, 50 do
        table.insert(available, i)
    end
    
    -- Pick 3 random unique upgrades
    for i = 1, 3 do
        local idx = math.random(1, #available)
        table.insert(shop_assigned_upgrades, available[idx])
        table.remove(available, idx)
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

-- Get all currently assigned upgrades
function UpgradeNode.get_assigned_upgrades()
    return shop_assigned_upgrades
end

-- ============================================================================
-- SELECTED UPGRADES SYSTEM (acquired from shop)
-- ============================================================================

function UpgradeNode.select_upgrade(upgrade_id)
    if #selected_upgrades < MAX_SELECTED_UPGRADES then
        -- Insert new upgrade at position 1 (leftmost)
        table.insert(selected_upgrades, 1, upgrade_id)
        -- Mark existing upgrades for shift animation (they move right)
        shift_animations = {}
        for i = 2, #selected_upgrades do
            table.insert(shift_animations, {
                upgrade_index = i,
                from_index = i - 1,
                to_index = i,
                duration = 0.6,
                elapsed = 0
            })
        end
        return true
    end
    return false
end

function UpgradeNode.get_selected_upgrades()
    return selected_upgrades
end

function UpgradeNode.add_flying_upgrade(upgrade_id, start_x, start_y)
    local Config = require("conf")
    local UIConfig = require("ui/ui_config")
    
    -- Flying sprite will be 128x128 (4x scale of 32x32, matching shop display)
    local flying_sprite_size = 128
    
    -- Adjust start position to account for sprite size (convert from center to top-left)
    local adjusted_start_x = start_x - flying_sprite_size / 2
    local adjusted_start_y = start_y - flying_sprite_size / 2
    
    -- New upgrades always fly to position 1 (leftmost)
    local upgrade_index = 1
    
    -- Display box dimensions
    local BOX_WIDTH = Config.SLOT_WIDTH
    local BOX_GAP = Config.SLOT_GAP
    local start_x_box = Config.PADDING_X + 30
    local box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
    local BOX_HEIGHT = Config.SLOT_Y - box_y - 20
    local total_width = (BOX_WIDTH * UIConfig.DISPLAY_BOX_COUNT) + (BOX_GAP * (UIConfig.DISPLAY_BOX_COUNT - 1))
    
    -- Calculate where this upgrade will be positioned (matching drawUpgradesLayer logic)
    local icon_display_size = 64  -- Size in display box
    local usable_width = total_width - 20
    local spacing_x = usable_width / (5 + 1)  -- Max 5 upgrades
    local center_y = box_y + BOX_HEIGHT / 2
    
    -- Target position for the flying sprite (left-aligned, always position 1)
    -- The sprite will be 128x128, so we adjust for left alignment
    local target_x = start_x_box + 10 + spacing_x * upgrade_index
    local target_y = center_y - flying_sprite_size / 2
    
    table.insert(flying_upgrades, {
        upgrade_id = upgrade_id,
        start_x = adjusted_start_x,
        start_y = adjusted_start_y,
        target_x = target_x,
        target_y = target_y,
        duration = 0.6,  -- Animation duration
        elapsed = 0
    })
end

function UpgradeNode.update_flying_upgrades(dt)
    for i, upgrade in ipairs(flying_upgrades) do
        upgrade.elapsed = upgrade.elapsed + dt
        -- Don't remove flying upgrades - keep them visible at their landing position
    end
end

function UpgradeNode.update_shift_animations(dt)
    local to_remove = {}
    for i, shift in ipairs(shift_animations) do
        shift.elapsed = shift.elapsed + dt
        if shift.elapsed >= shift.duration then
            table.insert(to_remove, i)
        end
    end
    
    -- Remove completed shift animations
    for i = #to_remove, 1, -1 do
        table.remove(shift_animations, to_remove[i])
    end
end

function UpgradeNode.get_shift_animations()
    return shift_animations
end

function UpgradeNode.get_flying_upgrades()
    return flying_upgrades
end

function UpgradeNode.get_max_selected_upgrades()
    return MAX_SELECTED_UPGRADES
end

function UpgradeNode.remove_selected_upgrade(index)
    table.remove(selected_upgrades, index)
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
