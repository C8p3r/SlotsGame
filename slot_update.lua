-- slot_update.lua
local Config = require("conf")

local SlotUpdate = {}
local Slots = nil -- Reference injected by setSlotMachineModule

function SlotUpdate.update(dt, state)
    if not state then return end

    if (state.win_flash_timer or 0) > 0 then 
        state.win_flash_timer = state.win_flash_timer - dt 
    end
    
    if state.neon_glow_shader and state.neon_glow_shader:hasUniform("time") then
        state.neon_glow_shader:send("time", love.timer.getTime())
    end
    
    local current_time = love.timer.getTime()

    -- Update Block Game Timer (QTE)
    if state.block_game_active then
        
        state.block_game_timer = state.block_game_timer - dt
        
        -- Check for expired targets (Failure condition)
        for i, target in ipairs(state.qte_targets) do
            local elapsed_since_spawn = current_time - target.spawn_time
            
            if elapsed_since_spawn > target.lifetime then
                -- Target expired! QTE FAILED.
                state.block_game_active = false
                state.qte_targets = {} 
                state.block_splash_timer = state.BLOCK_SPLASH_DURATION
                state.splash_text = "TIMED OUT!"
                state.splash_color = state.FAIL_COLOR
                
                if Slots then Slots.resolve_spin_result(false) end 
                return -- EXIT immediately upon failure
            end

            -- Update target size for drawing
            if elapsed_since_spawn >= 0 then
                local time_left_ratio = 1.0 - (elapsed_since_spawn / target.lifetime)
                target.radius = state.QTE_MIN_RADIUS + (state.QTE_INITIAL_RADIUS - state.QTE_MIN_RADIUS) * time_left_ratio
            end
        end
        
        if state.block_game_timer <= 0 then
            -- If the total timer hits zero and targets remain, fail the QTE (safety net)
            if #state.qte_targets > 0 then
                state.block_game_active = false
                state.qte_targets = {} 
                state.block_splash_timer = state.BLOCK_SPLASH_DURATION
                state.splash_text = "TIMED OUT!"
                state.splash_color = state.FAIL_COLOR
                if Slots then Slots.resolve_spin_result(false) end 
                return
            end
        end
    end
    
    -- *** DEFERRED AUTO-SPIN CHECK ***
    if (state.auto_spin_timer or 0) > 0 then
        state.auto_spin_timer = state.auto_spin_timer - dt
        if state.auto_spin_timer <= 0 then
            if Slots then Slots.start_spin() end
            state.auto_spin_timer = 0
        end
    end

    state.strobe_timer = math.mod((state.strobe_timer or 0) + dt, 2.0)
    
    local target_speed_mod, target_range_mod = 1.0, 1.0
    if Slots then
        target_speed_mod, target_range_mod = Slots.calculate_target_wiggle_modifiers(state.consecutive_wins or 0)
    end
    
    local lerp_amount = math.min(1.0, (state.WIGGLE_LERP_RATE or 2.5) * dt)
    state.current_wiggle_speed_mod = (state.current_wiggle_speed_mod or 1.0) + (target_speed_mod - (state.current_wiggle_speed_mod or 1.0)) * lerp_amount
    state.current_wiggle_range_mod = (state.current_wiggle_range_mod or 1.0) + (target_range_mod - (state.current_wiggle_range_mod or 1.0)) * lerp_amount
    
    local all_stopped = true
    if state.is_spinning then
        state.spin_timer = (state.spin_timer or 0) - dt
        state.spin_delay_timer = (state.spin_delay_timer or 0) + dt
    end
    
    if not state.is_spinning and (state.jam_duration_timer or 0) > 0 then
        state.jam_duration_timer = state.jam_duration_timer - dt
        if state.jam_duration_timer < 0 then state.jam_duration_timer = 0 end
    end
    
    if (state.splash_timer or 0) > 0 then state.splash_timer = state.splash_timer - dt end
    if (state.streak_splash_timer or 0) > 0 then state.streak_splash_timer = state.streak_splash_timer - dt end
    if (state.break_splash_timer or 0) > 0 then state.break_splash_timer = state.break_splash_timer - dt end
    if (state.jam_splash_timer or 0) > 0 then state.jam_splash_timer = state.jam_splash_timer - dt end
    if (state.block_splash_timer or 0) > 0 then state.block_splash_timer = state.block_splash_timer - dt end

    if state.slots then
        for i = 1, #state.slots do
            local slot = state.slots[i]
            local stop_time = slot.stop_time or 0
            
            if state.is_spinning and not slot.is_stopped and (state.spin_delay_timer or 0) >= stop_time then
                slot.is_stopped = true
                
                -- Calculate required scroll offset to center winning symbol
                local final_index = slot.symbol_index
                local ideal_offset = (final_index - 1) * Config.SYMBOL_SPACING
                local target_y_in_slot = Config.SLOT_HEIGHT / 2
                
                -- FIX: Set scroll_offset based on target center, not previous value
                slot.scroll_offset = target_y_in_slot - ideal_offset 
                slot.stop_start_time = love.timer.getTime()
            end
            
            local total_anim_time = (slot.stop_duration or 0.5) + (Config.ROW_LANDING_DELAY * 2) 
            
            if slot.is_stopped and slot.stop_start_time then
                if (love.timer.getTime() - slot.stop_start_time) < total_anim_time then
                    all_stopped = false
                end
            end
            
            if not slot.is_stopped then
                local speed = (4000 + (i * 500)) * dt
                slot.scroll_offset = (slot.scroll_offset or 0) + speed
                
                if Slots and Slots.state and Slots.state.loaded_sprites then
                    local sprite_count = #Slots.state.loaded_sprites
                    if sprite_count > 0 then
                        local loop_h = sprite_count * Config.SYMBOL_SPACING
                        if slot.scroll_offset >= loop_h then
                            slot.scroll_offset = slot.scroll_offset % loop_h
                        end
                    end
                end
                all_stopped = false
            end
        end
    end
    
    if all_stopped and state.is_spinning then
        if Slots then Slots.resolve_spin_result() end
    end
end

function SlotUpdate.setSlotMachineModule(module)
    Slots = module
end

return SlotUpdate