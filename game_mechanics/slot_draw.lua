-- slot_draw.lua
local Config = require("conf")
local SlotBorders = require("game_mechanics.slot_borders")
local Background = require("systems.background_renderer")

local SlotDraw = {}

-- Requires access to SlotMachine module (passed via argument)
local Slots = nil 

-- Load greyscale shader
-- greyscale shader handled by BackgroundRenderer; no local shader needed here

local function draw_wavy_text(text, x, y, font, color, seed, scale, get_wiggle_modifiers)
    if not text or text == "" then return end 
    scale = scale or 1.0
    love.graphics.setFont(font)
    love.graphics.setColor(color)
    local time = love.timer.getTime()
    
    local global_speed_mod, global_range_mod = get_wiggle_modifiers()
    local base_drift_speed = Config.DRIFT_SPEED * global_speed_mod
    local base_drift_range = Config.DRIFT_RANGE * global_range_mod
    
    local drift_x = 0
    local drift_y = 0
    if seed then
         drift_x = math.sin(time * base_drift_speed + seed) * (base_drift_range * 0.15)
         drift_y = math.cos(time * base_drift_speed * 0.8 + seed * 1.5) * (base_drift_range * 0.15)
    end
    
    local cursor_x = x + drift_x
    local base_y = y + drift_y
    local frequency = 0.15 
    local speed = 2.0      
    local amplitude = 1.5  
    
    if Slots.is_spinning() and font == Slots.state.dialogue_font then
        speed = 4.0     
        amplitude = 3.0 
    end
    
    for i = 1, #text do
        local char = text:sub(i, i)
        local phase_offset = seed or 0
        local wave_y = math.sin(time * speed + i * frequency + phase_offset) * amplitude
        love.graphics.print(char, cursor_x, base_y + wave_y, 0, scale, scale)
        cursor_x = cursor_x + (font:getWidth(char) * scale)
    end
end

function SlotDraw.get_draw_wavy_text()
    return draw_wavy_text
end

local function draw_sprite_symbol(index, x_center, y_center, alpha, seed, loaded_sprites, get_wiggle_modifiers)
    if not x_center or not y_center then return end
    local sprite = loaded_sprites[index] 
    if not sprite then return end
    
    local time = love.timer.getTime()
    local dx, dy = 0, 0
    
    local global_speed_mod, global_range_mod = get_wiggle_modifiers()
    local base_drift_speed = Config.DRIFT_SPEED * global_speed_mod
    local base_drift_range = Config.DRIFT_RANGE * global_range_mod
    
    if seed then
        dx = math.sin(time * base_drift_speed + seed) * (base_drift_range * 0.5)
        dy = math.cos(time * base_drift_speed * 0.8 + seed * 1.5) * (base_drift_range * 0.5)
    end
    
    love.graphics.setColor(1, 1, 1, alpha)
    -- Support two sprite formats: Image directly, or {image=atlas, quad=quad}
    if type(sprite) == "table" and sprite.image and sprite.quad then
        -- Draw quad from atlas with origin centered
        love.graphics.draw(sprite.image, sprite.quad, x_center + dx, y_center + dy, 0, Config.SPRITE_SCALE, Config.SPRITE_SCALE, Config.SOURCE_SPRITE_WIDTH / 2, Config.SOURCE_SPRITE_HEIGHT / 2)
    else
        local ox = (Config.SOURCE_SPRITE_WIDTH * Config.SPRITE_SCALE) / 2
        local oy = (Config.SOURCE_SPRITE_HEIGHT * Config.SPRITE_SCALE) / 2
        love.graphics.draw(sprite, x_center - ox + dx, y_center - oy + dy, 0, Config.SPRITE_SCALE, Config.SPRITE_SCALE)
    end
end

-- Multiplier box drawing moved to ui.lua - UI.drawIndicatorBoxes()


function SlotDraw.draw(state)
    local num_slots = #state.slots
    if num_slots == 0 then return end
    
    local slot_height = Config.SLOT_HEIGHT or 400
    local slot_y_pos = Config.SLOT_Y or 100
    local center_target = slot_y_pos + (slot_height / 2)
    local half_height = slot_height / 2
    
    local total_width = (num_slots * Config.SLOT_WIDTH) + ((num_slots - 1) * Config.SLOT_GAP)
    local start_x = (Config.GAME_WIDTH - total_width) / 2
    
    local prev_canvas = love.graphics.getCanvas()

    if state.symbol_canvas then
        love.graphics.setCanvas(state.symbol_canvas)
            love.graphics.clear(0, 0, 0, 0)
        
            -- Desaturate the background only where slots are (stencil-based)
            local display_box_start_x = Config.PADDING_X + 30
            local display_box_y = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 40
            local display_box_width = (Config.SLOT_WIDTH * 5) + (Config.SLOT_GAP * 4)
            local display_box_height = Config.SLOT_Y - display_box_y - 20
            Background.drawDesaturatedSlots(start_x, slot_y_pos, Config.SLOT_WIDTH, slot_height, Config.SLOT_GAP, num_slots, display_box_start_x, display_box_y, display_box_width, display_box_height)

            local x_walker = start_x
        
        -- --- DRAW BLACK BACKGROUND RECTANGLES ---
        love.graphics.setShader()
        for i = 1, num_slots do
             local x = start_x + (i-1) * (Config.SLOT_WIDTH + Config.SLOT_GAP)
             love.graphics.setColor(0, 0, 0, 0.3)
             love.graphics.rectangle("fill", x, slot_y_pos, Config.SLOT_WIDTH, slot_height, 10, 10)
        end
        
        -- FIX: Apply Neon Glow Shader globally while drawing TO the canvas 
        if state.neon_glow_shader then
             love.graphics.setShader(state.neon_glow_shader)
             state.neon_glow_shader:send("intensity", 1.0) 
        end
        
        -- --- DRAW SYMBOLS (WITH SHADER ACTIVE) ---
        x_walker = start_x
        for i, slot in ipairs(state.slots) do
            local x = x_walker
            local x_center = x + Config.SLOT_WIDTH / 2 
            
            love.graphics.setScissor(x, slot_y_pos, Config.SLOT_WIDTH, slot_height)
            
            for j = 1, #state.loaded_sprites do
                local symbol_index = (j - 1) % #state.loaded_sprites + 1
                local y_center = Slots.calculate_symbol_y(i, j)
                
                if y_center then
                    local dist_y = math.abs(y_center - center_target)
                    local alpha = math.max(0, 1 - dist_y / (slot_height * 0.9))
                    local drift_seed = i * 13 + j * 7
                    
                    if slot.is_stopped then
                        if symbol_index ~= slot.symbol_index then
                            draw_sprite_symbol(symbol_index, x_center, y_center, alpha * 0.5, drift_seed, state.loaded_sprites, Slots.get_wiggle_modifiers)
                        end
                    else
                        draw_sprite_symbol(symbol_index, x_center, y_center, alpha * 0.6, drift_seed, state.loaded_sprites, Slots.get_wiggle_modifiers)
                    end
                end
            end
            
            love.graphics.setScissor()
            x_walker = x_walker + Config.SLOT_WIDTH + Config.SLOT_GAP
        end
        
        love.graphics.setShader() -- Unset shader before finishing canvas drawing
        love.graphics.setCanvas(prev_canvas)
    end
    
    -- --- DRAW CANVAS OUTPUT WITH SCANLINE/CRT EFFECT ---
    
    if state.symbol_canvas then
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(state.symbol_canvas, 0, 0)
    end


    local x_walker = start_x
    for i, slot in ipairs(state.slots) do
        local x = x_walker
        
        local is_winning_column = state.winning_indices[i]
        
        -- CALCULATE INVERSION PULSE BASED ON WIN FLASH TIMER
        local pulse_on = false
        if is_winning_column and state.win_flash_timer then
            local time_ratio = state.win_flash_timer / 1.5 
            local pulse_freq = 15.0 
            local pulse_magnitude = math.max(0, math.sin((1.5 - time_ratio) * pulse_freq * math.pi)) 
            
            if state.win_flash_timer > 0.0 and pulse_magnitude > 0.1 then
                pulse_on = true
            end
        end
        
        love.graphics.setScissor(x, slot_y_pos, Config.SLOT_WIDTH, slot_height)
        
        if slot.is_stopped then
            local final_scale_multiplier = 1.0
            local pulse_speed_multiplier = 1.0
            
            if is_winning_column and pulse_on then
                final_scale_multiplier = 1.2 
                pulse_speed_multiplier = 3.0 
            end

            for j = 1, #state.loaded_sprites do
                local symbol_index = (j - 1) % #state.loaded_sprites + 1
                local y_center = Slots.calculate_symbol_y(i, j)
                
                    if y_center then
                    local offset_y = math.abs(y_center - center_target)
                    
                    if symbol_index == slot.symbol_index and offset_y < half_height then
                        local drift_seed = i * 13 + j * 7
                        local x_center = x + Config.SLOT_WIDTH / 2
                        
                        -- Set inversion shader ONLY IF pulse is ON
                        if is_winning_column and pulse_on and state.invert_shader then
                            love.graphics.setShader(state.invert_shader)
                        end
                        
                        local original_scale = Config.SPRITE_SCALE
                        local draw_scale = original_scale * final_scale_multiplier
                        
                        local ox = (Config.SOURCE_SPRITE_WIDTH * draw_scale) / 2
                        local oy = (Config.SOURCE_SPRITE_HEIGHT * draw_scale) / 2
                        
                        local dx, dy = 0, 0
                        local global_speed_mod, global_range_mod = Slots.get_wiggle_modifiers()
                        local final_drift_speed = Config.DRIFT_SPEED * global_speed_mod * pulse_speed_multiplier
                        local final_drift_range = Config.DRIFT_RANGE * global_range_mod
                        local time = love.timer.getTime()
                            
                        dx = math.sin(time * final_drift_speed + drift_seed) * (final_drift_range * 0.5)
                        dy = math.cos(time * final_drift_speed * 0.8 + drift_seed * 1.5) * (final_drift_range * 0.5)
                        
                        love.graphics.setColor(1, 1, 1, 1.0)
                        local sprite_entry = state.loaded_sprites[symbol_index]
                        if type(sprite_entry) == "table" and sprite_entry.image and sprite_entry.quad then
                            love.graphics.draw(sprite_entry.image, sprite_entry.quad, x_center + dx, y_center + dy, 0, draw_scale, draw_scale, Config.SOURCE_SPRITE_WIDTH/2, Config.SOURCE_SPRITE_HEIGHT/2)
                        else
                            love.graphics.draw(sprite_entry, x_center - ox + dx, y_center - oy + dy, 0, draw_scale, draw_scale)
                        end
                        
                        -- Unset shader
                        love.graphics.setShader()
                    end
                end
            end
        end
        
        love.graphics.setScissor()
        
        love.graphics.setColor(0.6, 0.6, 0.6, 0.2)
        local padding = 10 
        love.graphics.rectangle("line", x, slot_y_pos, Config.SLOT_WIDTH, slot_height, 10, 10)
        
        x_walker = x_walker + Config.SLOT_WIDTH + Config.SLOT_GAP
    end
    
    -- MULTIPLIER BOXES moved to ui.lua - UI.drawIndicatorBoxes()
    
    -- --- DRAW QTE and UI ---
    
    -- 1. DRAW BLOCK GAME QTE TARGETS (Iterate through list)
    if state.block_game_active then
        love.graphics.push()
        
        local strobe_freq = 120.0 
        local strobe_intensity = 0.5 + 0.5 * math.sin(love.timer.getTime() * strobe_freq)
        
        local qte_color = {0.8, 0.2, 1.0, 0.8} -- Purple base color for electric ring
        
        for _, target in ipairs(state.qte_targets) do
            local x = target.x
            local y = target.y
            local radius = target.radius
            
            -- Only draw if target has spawned
            if love.timer.getTime() >= target.spawn_time then
                
                love.graphics.setBlendMode("add")
                
                -- Draw Electric Border (Purple)
                SlotBorders.draw_electric_circle(x, y, radius, state.consecutive_wins, qte_color)
                
                -- Draw White Strobe Fill (The "valid region")
                love.graphics.setColor(1.0, 1.0, 1.0, strobe_intensity * 0.6) 
                love.graphics.circle("fill", x, y, radius)
                
                -- Draw center dot
                love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
                love.graphics.circle("fill", x, y, 5)
                
                love.graphics.setBlendMode("alpha")
            end
        end

        love.graphics.pop()
    end
    
    
    -- 2. DIALOGUE (Top Center)
    if state.message and state.dialogue_font then
        local mw = state.dialogue_font:getWidth(state.message)
        draw_wavy_text(state.message, Config.GAME_WIDTH/2 - mw/2, Config.MESSAGE_Y, state.dialogue_font, {1, 0.9, 0}, 100, 1.0, Slots.get_wiggle_modifiers)
    end
    
    -- NEW: HIGH STREAK DISPLAY
    if Slots.getHighStreak() > 0 then
        love.graphics.setFont(state.info_font)
        local hs_text = "HIGH STREAK: x" .. Slots.getHighStreak()
        local tw = state.info_font:getWidth(hs_text)
        local tx = Config.GAME_WIDTH/2 - tw/2
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        draw_wavy_text(hs_text, tx, Config.HIGH_STREAK_Y, state.info_font, {0.8, 0.8, 0.8, 1}, 100, 1.0, Slots.get_wiggle_modifiers)
    end

    
    -- 3. DRAW DYNAMIC SPLASH TEXT (5 ECHOES FOR MONEY/WIN)
    if (state.splash_timer and state.splash_timer > 0) or (state.block_splash_timer and state.block_splash_timer > 0) then
        local duration_mult = Slots.get_duration_multiplier(state.consecutive_wins)
        local dynamic_duration = state.SPLASH_DURATION / (1.0 / duration_mult)
        local progress = 1.0 - ((state.splash_timer or 0) / dynamic_duration)
        
        local current_splash_text = state.splash_text
        local current_splash_color = state.splash_color
        local current_splash_timer = state.splash_timer or 0
        
        if state.block_splash_timer and state.block_splash_timer > 0 then
            current_splash_text = state.splash_text
            current_splash_color = state.splash_color
            current_splash_timer = state.block_splash_timer
            local current_splash_duration = state.BLOCK_SPLASH_DURATION 
            progress = 1.0 - (current_splash_timer / current_splash_duration)
        end
        
        local top_edge_y = Config.SLOT_Y 
        local bottom_edge_y = Config.SLOT_Y + Config.SLOT_HEIGHT

        local function draw_generic_splash(text, color, scale_factor, offset_x_rand, y_start, y_end, alpha_mult, speed_mult, seed_offset, max_angle_deg)
            local current_y = y_start + (y_end - y_start) * progress * speed_mult
            
            local alpha = math.min(1.0, 1.0 - (progress * 0.5)) * alpha_mult
            if current_splash_timer < 0.2 then 
                alpha = alpha * (current_splash_timer / 0.2) 
            end
            
            local final_color = {color[1], color[2], color[3], alpha} 
            
            local tw = state.splash_font:getWidth(text) * scale_factor
            local th = state.splash_font:getHeight() * scale_factor
            
            local ox = tw / 2
            local oy = th / 2

            local base_x = (Config.GAME_WIDTH / 2) + offset_x_rand
            
            love.graphics.push()
            love.graphics.translate(base_x, current_y)
            local angle = (love.math.random() * 2 * max_angle_deg - max_angle_deg) * (math.pi / 180) 
            love.graphics.rotate(angle)
            
            draw_wavy_text(text, -ox, -oy, state.splash_font, final_color, 300 + seed_offset, scale_factor, Slots.get_wiggle_modifiers)
            
            love.graphics.pop()
        end
        
        local ECHO_Y_START_BELOW = bottom_edge_y + 50 
        local ECHO_Y_END_BELOW = bottom_edge_y - 50 
        local MAIN_Y_START_ABOVE = top_edge_y - 50 
        local MAIN_Y_END_ABOVE = top_edge_y + 100 

        local echo_scale = 1.0 
        local echo_alpha = 0.5 
        local echo_speed = 1.5 
        
        -- Money Splash Echoes (5 Instances)
        local payout_text = state.display_payout_string 
        
            -- Center scatter (Base result)
            draw_generic_splash(current_splash_text, current_splash_color, 1.0, 0, MAIN_Y_START_ABOVE * 0.8, MAIN_Y_END_ABOVE * 0.8, 1.0, 1.0, 5, 1)

        -- Money Splash 1: Left Top
        draw_generic_splash(payout_text, state.display_payout_color, 0.7, -350, top_edge_y + 10, top_edge_y - 50, 0.7, 1.1, 10, 15)
        -- Money Splash 2: Center Bottom
        draw_generic_splash(payout_text, state.display_payout_color, 0.8, 50, bottom_edge_y - 50, bottom_edge_y + 50, 0.8, 1.0, 20, 10)
        -- Money Splash 3: Right Top
        draw_generic_splash(payout_text, state.display_payout_color, 0.9, 300, top_edge_y + 30, top_edge_y - 30, 0.9, 1.2, 30, 5)
        -- Money Splash 4: Left Bottom
        draw_generic_splash(payout_text, state.display_payout_color, 0.6, -150, bottom_edge_y - 10, bottom_edge_y + 30, 0.6, 0.9, 40, 20)
        -- Money Splash 5: Center Top (smaller)
        draw_generic_splash(payout_text, state.display_payout_color, 0.5, 0, top_edge_y - 20, top_edge_y - 80, 0.5, 1.3, 50, 2)
    end
    
    -- 4. DRAW DYNAMIC STREAK SPLASH TEXT
    if state.streak_splash_timer and state.streak_splash_timer > 0 then
        local duration_mult = Slots.get_duration_multiplier(state.consecutive_wins)
        local dynamic_duration = state.STREAK_SPLASH_DURATION / (1.0 / duration_mult)
        local progress = 1.0 - (state.streak_splash_timer / dynamic_duration)
        
        local STREAK_SCALE = 2.0 
        local STREAK_Y_START = Config.GAME_HEIGHT * 0.4 
        local STREAK_Y_END = STREAK_Y_START - 50 
        
        local current_y = STREAK_Y_START + (STREAK_Y_END - STREAK_Y_START) * progress 
        local alpha = 1.0 - progress 
        local streak_color_final = {state.streak_splash_color[1], state.streak_splash_color[2], state.streak_splash_color[3], alpha} 
        
        love.graphics.push()
        love.graphics.translate(Config.GAME_WIDTH / 2, current_y)
        love.graphics.rotate(math.sin(love.timer.getTime() * 4) * 0.05)
        local tw = state.splash_font:getWidth(state.streak_splash_text) * STREAK_SCALE
        local th = state.splash_font:getHeight() * STREAK_SCALE
        draw_wavy_text(state.streak_splash_text, -tw/2, -th/2, state.splash_font, streak_color_final, 400, STREAK_SCALE, Slots.get_wiggle_modifiers)
        love.graphics.pop()
    end
    
    -- 5. DRAW DYNAMIC BREAK SPLASH TEXT
    if state.break_splash_timer and state.break_splash_timer > 0 then
        local progress = 1.0 - (state.break_splash_timer / state.BREAK_SPLASH_DURATION) 
        local BREAK_SCALE = 3.0 
        local BREAK_Y_START = Config.GAME_HEIGHT * 0.3 
        local BREAK_Y_END = BREAK_Y_START + 50 
        local current_y = BREAK_Y_START + (BREAK_Y_END - BREAK_Y_START) * progress 
        local alpha = 1.0 - progress 
        local break_color_final = {state.break_splash_color[1], state.break_splash_color[2], state.break_splash_color[3], alpha} 
        love.graphics.push()
        love.graphics.translate(Config.GAME_WIDTH / 2, current_y)
        love.graphics.rotate(math.sin(love.timer.getTime() * 5) * 0.1) 
        local tw = state.splash_font:getWidth(state.break_splash_text) * BREAK_SCALE
        local th = state.splash_font:getHeight() * BREAK_SCALE
        draw_wavy_text(state.break_splash_text, -tw/2, -th/2, state.splash_font, break_color_final, 450, BREAK_SCALE, Slots.get_wiggle_modifiers)
        love.graphics.pop()
    end
    
    -- 6. DRAW JAM SPLASH OVER LEVER KNOB 
    if state.jam_splash_timer and state.jam_splash_timer > 0 then
        local knob_x = Config.LEVER_TRACK_X + (Config.LEVER_TRACK_WIDTH / 2)
        local knob_y_jammed_center = Config.LEVER_TRACK_Y + (Config.LEVER_TRACK_HEIGHT * (1/3))
        local TEXT_OFFSET_Y = Config.LEVER_KNOB_RADIUS + 10 
        local splash_center_y = knob_y_jammed_center + TEXT_OFFSET_Y
        local alpha_base = state.jam_splash_timer / state.JAM_SPLASH_DURATION
        local alpha = alpha_base * (0.7 + 0.3 * math.sin(love.timer.getTime() * 8))
        local color = {state.JAM_COLOR[1], state.JAM_COLOR[2], state.JAM_COLOR[3], alpha}
        love.graphics.push()
        love.graphics.translate(knob_x, splash_center_y)
        local wiggle_angle = math.sin(love.timer.getTime() * 10) * 0.05
        love.graphics.rotate(wiggle_angle)
        local tw = state.splash_font:getWidth(state.JAM_TEXT) * 1.5 
        local th = state.splash_font:getHeight() * 1.5
        draw_wavy_text(state.JAM_TEXT, -tw/2, -th/2, state.splash_font, color, 600, 1.5, Slots.get_wiggle_modifiers) 
        love.graphics.pop()
    end

    
    love.graphics.setFont(state.info_font)
    love.graphics.setColor(1, 1, 1)
end

function SlotDraw.setSlotMachineModule(module)
    Slots = module
end

-- Expose draw_wavy_text for use by other modules (like ui.lua)
function SlotDraw.draw_wavy_text(text, x, y, font, color, seed, scale, get_wiggle_modifiers)
    return draw_wavy_text(text, x, y, font, color, seed, scale, get_wiggle_modifiers)
end

return SlotDraw