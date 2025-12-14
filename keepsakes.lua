-- keepsakes.lua
-- Modular keepsake system with gameplay modifiers

local Config = require("conf")
local Keepsakes = {}

-- Keepsake state
local selected_keepsake = nil
local keepsake_textures = {}
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

-- Load keepsake textures
function Keepsakes.load()
    -- Load blank texture first
    local ok_blank, blank_img = pcall(love.graphics.newImage, "assets/keepsakes/keepsake_blank.png")
    if ok_blank then
        blank_texture = blank_img
    else
        -- Create a simple grey blank texture if file doesn't exist
        local imgData = love.image.newImageData(64, 64)
        for x = 0, 63 do
            for y = 0, 63 do
                imgData:setPixel(x, y, 0.3, 0.3, 0.3, 1)
            end
        end
        blank_texture = love.graphics.newImage(imgData)
        -- Use nearest filter for crisp appearance
        blank_texture:setFilter("nearest", "nearest")
    end
    
    for i = 1, GRID_SIZE do
        local texture_path = "assets/keepsakes/keepsake_" .. i .. ".png"
        local ok, img = pcall(love.graphics.newImage, texture_path)
        
        if ok then
            -- Use nearest filter for crisp, sharp scaling
            img:setFilter("nearest", "nearest")
            keepsake_textures[i] = img
        else
            -- Use blank texture as fallback
            keepsake_textures[i] = blank_texture
        end
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

-- Get keepsake texture
function Keepsakes.get_texture(id)
    if id < 1 or id > GRID_SIZE then return nil end
    return keepsake_textures[id]
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
        
        -- Draw cell background
        local bg_color = {0.2, 0.2, 0.2, 0.8}
        love.graphics.setColor(bg_color)
        love.graphics.rectangle("fill", x, y, cell_size, cell_size, 5, 5)
        
        -- Draw texture or blank
        local texture = keepsake_textures[i]
        if texture then
            love.graphics.setColor(1, 1, 1, 1)  -- White, fully opaque
            love.graphics.draw(texture, x, y, 0, cell_size / texture:getWidth(), cell_size / texture:getHeight())
        end
        
        -- Draw outline if selected
        if Keepsakes.is_selected(i) then
            love.graphics.setColor(1, 1, 0, 1)  -- Yellow outline
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", x, y, cell_size, cell_size, 5, 5)
            love.graphics.setLineWidth(1)
        else
            -- Normal border
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x, y, cell_size, cell_size, 5, 5)
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

return Keepsakes
