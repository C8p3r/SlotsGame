-- keepsakes.lua
-- Modular keepsake system with gameplay modifiers

local Config = require("conf")
local Keepsakes = {}

-- Keepsake state
local selected_keepsake = nil
local keepsake_spritesheet = nil
local keepsake_quads = {}
local blank_texture = nil

-- Grid dimensions
local GRID_COLS = 4
local GRID_ROWS = 4
local GRID_SIZE = GRID_COLS * GRID_ROWS -- 16 keepsakes

-- Define all keepsakes with their modifiers
-- Organize each keepsake as a table with id, name, effects, and splash info
local KEEPSAKE_DEFINITIONS = {
    {
        id = 1,
        name = "Lucky Coin",
        effects = {
            win_multiplier = 1.4,  -- 40% more winnings
            spin_cost_multiplier = 1.15,  -- but 15% more expensive spins
        },
        splash_text = "LUCKY BOOST",
        splash_timing = "score",
        splash_color = {1, 1, 0},  -- Yellow
        tooltip = {benefit = "+40% Wins", downside = "-15% Spin Cost", flavor = "An ancient coin that draws fortune to those brave enough to pay"}
    },
    {
        id = 2,
        name = "Mutant Clover",
        effects = {
            spin_cost_multiplier = 0.65,  -- 35% cheaper spins
            win_multiplier = 0.85,  -- but 15% less winnings
        },
        splash_text = "BARGAIN SPIN",
        splash_timing = "spin",
        splash_color = {1, 0.8, 0},  -- Gold
        tooltip = {benefit = "-35% Spin Cost", downside = "-15% Wins", flavor = "A humble clover blessed by nature itself"}
    },
    {
        id = 3,
        name = "Hex Ward",
        effects = {
            qte_target_lifetime_multiplier = 1.35,  -- 35% more time for QTE
            qte_circle_shrink_multiplier = 1.2,  -- but circle shrinks faster
        },
        splash_text = "MORE TIME!",
        splash_timing = "qte",
        splash_color = {0.5, 1, 0.8},  -- Cyan
        tooltip = {benefit = "+35% QTE Time", downside = "+20% Circle Shrink", flavor = "A protective sigil against the spinning wheel's haste"}
    },
    {
        id = 4,
        name = "Malachite Lump",
        effects = {
            streak_multiplier = 1.2,  -- 20% more streak bonus
            spin_cost_multiplier = 1.25,  -- but 25% more expensive
        },
        splash_text = "STREAK POWER",
        splash_timing = "score",
        splash_color = {0.2, 1, 0.5},  -- Green
        tooltip = {benefit = "+20% Streak Bonus", downside = "+25% Spin Cost", flavor = "Stone that stores the momentum of fortune"}
    },
    {
        id = 5,
        name = "Silver Locket",
        effects = {
            win_multiplier = 1.2,
            spin_cost_multiplier = 0.8,
            qte_target_lifetime_multiplier = 0.9,  -- -10% QTE time
        },
        splash_text = "BALANCED LUCK",
        splash_timing = "score",
        splash_color = {0.8, 0.8, 1},  -- Silver
        tooltip = {benefit = "+20% Wins, -20% Spins", downside = "-10% QTE Time", flavor = "A locket containing memories of perfect spins"}
    },
    {
        id = 6,
        name = "Eternal Hourglass",
        effects = {
            qte_circle_shrink_multiplier = 0.7,  -- 30% slower shrink
            qte_target_lifetime_multiplier = 0.85,  -- but 15% less time
        },
        splash_text = "SLOWER CIRCLE",
        splash_timing = "qte",
        splash_color = {1, 0.8, 1},  -- Pearl
        tooltip = {benefit = "-30% Circle Shrink", downside = "-15% QTE Time", flavor = "Shaped by the ocean's eternal patience"}
    },
    {
        id = 7,
        name = "Ruby Heart",
        effects = {
            win_multiplier = 1.5,  -- 50% more winnings
            streak_multiplier = 1.1,  -- 10% more streak
            qte_circle_shrink_multiplier = 1.3,  -- but circle shrinks 30% faster
        },
        splash_text = "RUBY BLESSING",
        splash_timing = "score",
        splash_color = {1, 0.2, 0.5},  -- Ruby
        tooltip = {benefit = "+50% Wins, +10% Streak", downside = "+30% Circle Shrink", flavor = "A heart that pulses with the thrill of risk"}
    },
    {
        id = 8,
        name = "Frigid Crown",
        effects = {
            qte_target_lifetime_multiplier = 1.4,  -- 40% more time
            qte_circle_shrink_multiplier = 0.7,  -- 30% slower shrink
            spin_cost_multiplier = 1.35,  -- but 35% more expensive
        },
        splash_text = "CROWN POWER",
        splash_timing = "qte",
        splash_color = {0.2, 0.8, 1},  -- Sapphire
        tooltip = {benefit = "+40% Time, -30% Shrink", downside = "+35% Spin Cost", flavor = "A crown of ice that commands the spinning wheel"}
    },
    {
        id = 9,
        name = "Voodoo Paper",
        effects = {
            spin_cost_multiplier = 0.7,  -- 30% cheaper
            streak_multiplier = 1.25,  -- 25% more streak
            win_multiplier = 0.9,  -- but 10% less base wins
        },
        splash_text = "EMERALD FAVOR",
        splash_timing = "score",
        splash_color = {0.2, 1, 0.5},  -- Emerald
        tooltip = {benefit = "-30% Spins, +25% Streak", downside = "-10% Wins", flavor = "A ritual scroll written in favor of the fortunate"}
    },
    {
        id = 10,
        name = "Lushious Paw",
        effects = {
            win_multiplier = 1.55,  -- 55% more winnings (huge!)
            spin_cost_multiplier = 1.4,  -- but 40% more expensive
            qte_target_lifetime_multiplier = 0.8,  -- QTE time reduced
        },
        splash_text = "LUCKY PAW",
        splash_timing = "score",
        splash_color = {1, 0.6, 0.2},  -- Orange
        tooltip = {benefit = "+55% Wins", downside = "+40% Spins, -20% QTE", flavor = "A paw print that leaves only prosperity behind"}
    },
    {
        id = 11,
        name = "Topaz Star",
        effects = {
            qte_target_lifetime_multiplier = 1.45,  -- 45% more QTE time
            spin_cost_multiplier = 1.2,  -- but 20% more expensive
        },
        splash_text = "STELLAR TIME",
        splash_timing = "spin",
        splash_color = {1, 1, 0.3},  -- Topaz
        tooltip = {benefit = "+45% QTE Time", downside = "+20% Spin Cost", flavor = "A star that guides through the challenge"}
    },
    {
        id = 12,
        name = "Verdant Gem",
        effects = {
            win_multiplier = 1.6,  -- 60% more wins
            qte_circle_shrink_multiplier = 1.4,  -- but circle shrinks much faster
        },
        splash_text = "NATURE'S GIFT",
        splash_timing = "score",
        splash_color = {0.8, 1, 1},  -- Diamond
        tooltip = {benefit = "+60% Wins", downside = "+40% Circle Shrink", flavor = "A pristine stone worth any price"}
    },
    {
        id = 13,
        name = "Rubbed Opal",
        effects = {
            spin_cost_multiplier = 0.6,  -- 40% cheaper
            win_multiplier = 1.25,  -- 25% more wins
            streak_multiplier = 0.95,  -- but -5% streak
        },
        splash_text = "OPAL GRACE",
        splash_timing = "score",
        splash_color = {0.8, 0.5, 1},  -- Opal
        tooltip = {benefit = "-40% Spins, +25% Wins", downside = "-5% Streak", flavor = "Iridescent stone reflecting every opportunity"}
    },
    {
        id = 14,
        name = "Refraction Occulus",
        effects = {
            qte_circle_shrink_multiplier = 0.65,  -- 35% slower shrink
            qte_target_lifetime_multiplier = 1.2,  -- 20% more time
            win_multiplier = 0.8,  -- but 20% less wins
        },
        splash_text = "CRYSTAL REFRACT",
        splash_timing = "qte",
        splash_color = {0.5, 1, 1},  -- Crystal
        tooltip = {benefit = "-35% Shrink, +20% Time", downside = "-20% Wins", flavor = "A lens that refracts fate itself"}
    },
    {
        id = 15,
        name = "Lunar Lens",
        effects = {
            win_multiplier = 1.35,  -- 35% more wins
            spin_cost_multiplier = 0.75,  -- 25% cheaper
            streak_multiplier = 1.15,  -- 15% more streak
            qte_target_lifetime_multiplier = 0.85,  -- but -15% QTE time
        },
        splash_text = "LUNAR FAVOR",
        splash_timing = "score",
        splash_color = {0.8, 0.9, 1},  -- Moonstone
        tooltip = {benefit = "+35% Wins, -25% Spins, +15% Streak", downside = "-15% QTE Time", flavor = "The moon watches over all who spin beneath her"}
    },
    {
        id = 16,
        name = "Abyssal Mirror",
        effects = {
            win_multiplier = 1.5,  -- 50% more wins
            qte_circle_shrink_multiplier = 0.75,  -- 25% slower shrink
            streak_multiplier = 1.3,  -- 30% more streak
            spin_cost_multiplier = 1.3,  -- but 30% more expensive
        },
        splash_text = "DARK POWER",
        splash_timing = "score",
        splash_color = {0.8, 0.2, 1},  -- Purple
        tooltip = {benefit = "+50% Wins, +30% Streak, -25% Shrink", downside = "+30% Cost", flavor = "A reflection of the void where all bets are devoured"}
    },
}

-- Load keepsake textures from spritesheet
function Keepsakes.load()
    -- Load spritesheet (128x128, 4x4 grid of 32x32 sprites)
    local ok_sheet, sheet = pcall(love.graphics.newImage, "assets/keepsakes/keepsakes_grid.png")
    if ok_sheet then
        keepsake_spritesheet = sheet
        keepsake_spritesheet:setFilter("nearest", "nearest")
        
        -- Create quads for each keepsake (32x32 each)
        for i = 1, GRID_SIZE do
            local idx = i - 1  -- 0-indexed
            local col = idx % GRID_COLS
            local row = math.floor(idx / GRID_COLS)
            local x = col * 32
            local y = row * 32
            keepsake_quads[i] = love.graphics.newQuad(x, y, 32, 32, 128, 128)
        end
    else
        -- Fallback: create blank texture if spritesheet not found
        local imgData = love.image.newImageData(32, 32)
        for x = 0, 31 do
            for y = 0, 31 do
                imgData:setPixel(x, y, 0.3, 0.3, 0.3, 1)
            end
        end
        blank_texture = love.graphics.newImage(imgData)
        blank_texture:setFilter("nearest", "nearest")
    end
end

-- Get keepsake definition by id
function Keepsakes.get_definition(id)
    if id < 1 or id > GRID_SIZE then return nil end
    return KEEPSAKE_DEFINITIONS[id]
end

-- Set selected keepsake
function Keepsakes.set(id)
    if id >= 1 and id <= GRID_SIZE then
        selected_keepsake = id
    end
end

-- Get selected keepsake id
function Keepsakes.get()
    return selected_keepsake
end

-- Check if keepsake is selected
function Keepsakes.is_selected(id)
    return selected_keepsake == id
end

-- Get keepsake texture (spritesheet quad)
function Keepsakes.get_texture(id)
    if id < 1 or id > GRID_SIZE then return nil end
    return keepsake_quads[id]
end

-- Get spritesheet image
function Keepsakes.get_spritesheet()
    return keepsake_spritesheet
end

-- Get all effects for selected keepsake
function Keepsakes.get_active_effects()
    if not selected_keepsake then return {} end
    local def = KEEPSAKE_DEFINITIONS[selected_keepsake]
    return def and def.effects or {}
end

-- Get effect multiplier
function Keepsakes.get_effect(effect_name)
    local effects = Keepsakes.get_active_effects()
    return effects[effect_name] or 1.0
end

-- Get selected keepsake name
function Keepsakes.get_name()
    if not selected_keepsake then return "None" end
    local def = KEEPSAKE_DEFINITIONS[selected_keepsake]
    return def and def.name or "Unknown"
end

-- Get splash text for selected keepsake
function Keepsakes.get_splash_text()
    if not selected_keepsake then return "" end
    local def = KEEPSAKE_DEFINITIONS[selected_keepsake]
    return def and def.splash_text or ""
end

-- Get splash timing for selected keepsake ("spin" or "score")
function Keepsakes.get_splash_timing()
    if not selected_keepsake then return nil end
    local def = KEEPSAKE_DEFINITIONS[selected_keepsake]
    return def and def.splash_timing or nil
end

-- Get splash color for selected keepsake
function Keepsakes.get_splash_color()
    if not selected_keepsake then return {1, 1, 1} end
    local def = KEEPSAKE_DEFINITIONS[selected_keepsake]
    return def and def.splash_color or {1, 1, 1}
end

-- Reset selection
function Keepsakes.reset()
    selected_keepsake = nil
end

-- Draw keepsake selection grid
function Keepsakes.draw_grid(start_x, start_y, cell_size, cell_gap, show_names)
    cell_size = cell_size or 80
    cell_gap = cell_gap or 10
    show_names = show_names or false
    
    for i = 1, GRID_SIZE do
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        local x = start_x + col * (cell_size + cell_gap)
        local y = start_y + row * (cell_size + cell_gap)
        
        -- Calculate drift effect
        local time = love.timer.getTime()
        local seed = i * 0.5  -- Unique seed per keepsake
        local dx = math.sin(time * Config.DRIFT_SPEED + seed) * Config.DRIFT_RANGE
        local dy = math.cos(time * Config.DRIFT_SPEED * 0.8 + seed * 1.5) * Config.DRIFT_RANGE
        
        -- Draw glow behind if selected
        if Keepsakes.is_selected(i) then
            -- Pulsating white glow
            local time = love.timer.getTime()
            local pulse = 0.2 + 0.15 * math.sin(time * 3)  -- Pulses between 0.2 and 0.35
            love.graphics.setColor(1, 1, 1, pulse)  -- Subtle pulsating white
            love.graphics.rectangle("fill", x, y, cell_size, cell_size, 5, 5)
        end
        
        -- Draw sprite from spritesheet
        if keepsake_spritesheet and keepsake_quads[i] then
            love.graphics.setColor(1, 1, 1, 1)  -- White, fully opaque
            -- Calculate integer scale factor for crisp appearance (32x32 source)
            local scale = math.floor(cell_size / 32)
            local actual_size = 32 * scale
            local offset_x = (cell_size - actual_size) / 2
            local offset_y = (cell_size - actual_size) / 2
            love.graphics.draw(keepsake_spritesheet, keepsake_quads[i], x + offset_x + dx, y + offset_y + dy, 0, scale, scale)
        elseif blank_texture then
            -- Fallback to blank texture
            love.graphics.setColor(1, 1, 1, 1)
            local scale = math.floor(cell_size / 32)
            local actual_size = 32 * scale
            local offset_x = (cell_size - actual_size) / 2
            local offset_y = (cell_size - actual_size) / 2
            love.graphics.draw(blank_texture, x + offset_x + dx, y + offset_y + dy, 0, scale, scale)
        end
        
        -- Draw name below if enabled
        if show_names then
            local def = KEEPSAKE_DEFINITIONS[i]
            local name = def and def.name or "Unknown"
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(love.graphics.getFont())
            local name_w = love.graphics.getFont():getWidth(name)
            local font_h = love.graphics.getFont():getHeight()
            love.graphics.print(name, x + cell_size / 2 - name_w / 2, y + cell_size + 3)
        end
    end
end

-- Check if click is within grid and return keepsake id
function Keepsakes.check_click(x, y, start_x, start_y, cell_size, cell_gap)
    cell_size = cell_size or 80
    cell_gap = cell_gap or 10
    
    for i = 1, GRID_SIZE do
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        local cell_x = start_x + col * (cell_size + cell_gap)
        local cell_y = start_y + row * (cell_size + cell_gap)
        
        if x >= cell_x and x <= cell_x + cell_size and
           y >= cell_y and y <= cell_y + cell_size then
            Keepsakes.set(i)
            return i
        end
    end
    
    return nil
end

-- Get keepsake at mouse position
function Keepsakes.get_hovered_keepsake(mouse_x, mouse_y, start_x, start_y, cell_size, cell_gap)
    cell_size = cell_size or 80
    cell_gap = cell_gap or 10
    
    for i = 1, GRID_SIZE do
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        local x = start_x + col * (cell_size + cell_gap)
        local y = start_y + row * (cell_size + cell_gap)
        
        if mouse_x >= x and mouse_x <= x + cell_size and
           mouse_y >= y and mouse_y <= y + cell_size then
            return i
        end
    end
    
    return nil
end

return Keepsakes
