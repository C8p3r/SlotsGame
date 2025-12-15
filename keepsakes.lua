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
-- Organize each keepsake as a table with id, name, and effects
local KEEPSAKE_DEFINITIONS = {
    {
        id = 1,
        name = "Lucky Coin",
        effects = {
            win_multiplier = 1.1,  -- 10% more winnings
        }
    },
    {
        id = 2,
        name = "Golden Bell",
        effects = {
            spin_cost_multiplier = 0.9,  -- 10% cheaper spins
        }
    },
    {
        id = 3,
        name = "Fortune Stone",
        effects = {
            qte_target_lifetime_multiplier = 1.1,  -- 10% more time for QTE
        }
    },
    {
        id = 4,
        name = "Jade Token",
        effects = {
            streak_multiplier = 1.05,  -- 5% more streak bonus
        }
    },
    {
        id = 5,
        name = "Silver Locket",
        effects = {
            win_multiplier = 1.05,
            spin_cost_multiplier = 0.95,
        }
    },
    {
        id = 6,
        name = "Pearl Charm",
        effects = {
            qte_circle_shrink_multiplier = 0.9,  -- Slower shrink
        }
    },
    {
        id = 7,
        name = "Ruby Heart",
        effects = {
            win_multiplier = 1.15,
            streak_multiplier = 1.02,
        }
    },
    {
        id = 8,
        name = "Sapphire Crown",
        effects = {
            qte_target_lifetime_multiplier = 1.15,
            qte_circle_shrink_multiplier = 0.85,
        }
    },
    {
        id = 9,
        name = "Emerald Locket",
        effects = {
            spin_cost_multiplier = 0.85,
            streak_multiplier = 1.03,
        }
    },
    {
        id = 10,
        name = "Rabits Paw",
        effects = {
            win_multiplier = 1.2,
            spin_cost_multiplier = 1.05,  -- Slightly more expensive but bigger wins
        }
    },
    {
        id = 11,
        name = "Topaz Star",
        effects = {
            qte_target_lifetime_multiplier = 1.2,
        }
    },
    {
        id = 12,
        name = "Diamond Shard",
        effects = {
            win_multiplier = 1.25,
            qte_target_lifetime_multiplier = 0.95,  -- Less time but bigger wins
        }
    },
    {
        id = 13,
        name = "Opal Whisper",
        effects = {
            spin_cost_multiplier = 0.8,
            win_multiplier = 1.08,
        }
    },
    {
        id = 14,
        name = "Crystal Prism",
        effects = {
            qte_circle_shrink_multiplier = 0.8,
            qte_target_lifetime_multiplier = 1.05,
        }
    },
    {
        id = 15,
        name = "Moonstone",
        effects = {
            win_multiplier = 1.12,
            spin_cost_multiplier = 0.92,
            streak_multiplier = 1.04,
        }
    },
    {
        id = 16,
        name = "Black Mirror",
        effects = {
            win_multiplier = 1.18,
            qte_circle_shrink_multiplier = 0.88,
            streak_multiplier = 1.06,
        }
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
            love.graphics.setColor(1, 1, 0, 0.3)  -- Yellow glow
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
