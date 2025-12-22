-- conf.lua
local Config = {}

-- 1. WINDOW & RESOLUTION (Updated to 1400x788 for 16:9 aspect ratio)
Config.GAME_WIDTH = 1400
Config.GAME_HEIGHT = 788

-- 2. SPRITE SETTINGS
-- Sprite atlas: use a 160x160 `assets/slot_token_array.png` arranged as 5x5 icons (32x32).
-- The slot code will load the first row of this atlas as the primary symbols.
Config.SOURCE_SPRITE_WIDTH = 32
Config.SOURCE_SPRITE_HEIGHT = 32
Config.TARGET_DISPLAY_SIZE = 120

-- 3. VISUALS
Config.BACKING_SQUARE_COLOR = {0.2, 0.2, 0.2}
Config.BACKING_SQUARE_SIZE = 140
Config.SLOT_WIDTH = 200
Config.SLOT_HEIGHT = 400
Config.SLOT_GAP = 20
Config.SLOT_COUNT = 5 

-- 4. ANIMATION PHYSICS
Config.DRIFT_SPEED = 1.5
Config.DRIFT_RANGE = 6.0
Config.ROW_LANDING_DELAY = 0.15
Config.DROP_DISTANCE = 300 
Config.STOP_DURATION = 0.5 
Config.SPIN_DURATION = 1.0 

-- 6. FONTS
Config.FONT_SIZE = 24         -- Used for Bankroll, Payout, Streak
Config.INFO_FONT_SIZE = 14    -- Used for general UI instructions
Config.DIALOGUE_FONT_SIZE = 54 -- Used for top conversational dialogue
Config.RESULT_FONT_SIZE = 48  -- Used as the base size for splash effects

-- 7. CALCULATED VALUES
Config.SPRITE_SCALE = Config.TARGET_DISPLAY_SIZE / Config.SOURCE_SPRITE_WIDTH
Config.SYMBOL_SPACING = Config.BACKING_SQUARE_SIZE * 1.15

-- Layout Calculations
local total_slot_w = (Config.SLOT_WIDTH * Config.SLOT_COUNT) + (Config.SLOT_GAP * (Config.SLOT_COUNT - 1))
Config.PADDING_X = ((Config.GAME_WIDTH - total_slot_w) / 2) - 30 
Config.TOTAL_SLOTS_WIDTH = total_slot_w

-- Vertical Layout Calculations
Config.MESSAGE_Y = 30 
local bank_bot = 20 
local bank_top = Config.GAME_HEIGHT - Config.FONT_SIZE - bank_bot - 5
local dial_bot = Config.MESSAGE_Y + Config.DIALOGUE_FONT_SIZE + 10

-- NEW: High Streak Display Position (Below dialogue)
Config.HIGH_STREAK_Y = dial_bot 
local high_streak_bot = Config.HIGH_STREAK_Y + Config.FONT_SIZE + 10

-- Recalculate Available Space for slots
local new_avail_space = bank_top - high_streak_bot

-- Bottom Text Positions
Config.PAYOUT_Y = bank_top  -- Payout aligned with balance
Config.BANKROLL_Y = bank_top
Config.RESULT_Y = bank_top 

-- Slot Vertical Centering
local center_point = high_streak_bot + (new_avail_space / 2)
Config.SLOT_Y = center_point - (Config.SLOT_HEIGHT / 2) + 50 

-- Streak Indicator Position (Left of Bankroll)
Config.STREAK_X = 20
Config.STREAK_Y = bank_top

-- 8. LINEAR LEVER CONFIGURATION (Relative to new SLOT_Y)
Config.LEVER_TRACK_X = Config.PADDING_X + total_slot_w + 100 
Config.LEVER_TRACK_Y = Config.SLOT_Y + 20
Config.LEVER_TRACK_WIDTH = 15
Config.LEVER_TRACK_HEIGHT = Config.SLOT_HEIGHT - 40 
Config.LEVER_KNOB_RADIUS = 30
Config.LEVER_KNOB_COLOR = {0.9, 0.1, 0.1} 
Config.LEVER_TRACK_COLOR = {0.15, 0.15, 0.15}

-- 9. LEFT BUTTONS & DISPLAY CONFIGURATION 
Config.BUTTON_WIDTH = 120  
Config.BUTTON_HEIGHT = 80  
Config.BUTTON_GAP = 15

-- Fixed anchor point
Config.BUTTON_START_X = 20 

-- FIX: Shift entire UI stack UPWARDS by 100 pixels relative to the previous position.
-- New shift is 20 - 100 = -80.
local VERTICAL_SHIFT = -80 
Config.BUTTON_START_Y = Config.SLOT_Y + VERTICAL_SHIFT 

-- Display Box Constants (standardized with multiplier boxes)
Config.BET_BOX_WIDTH = 120 
Config.BET_BOX_HEIGHT = 60  -- Match multiplier box height
Config.BET_BOX_GAP = 10

-- Multiplier Box Constants
Config.MULTIPLIER_BOX_WIDTH = Config.BUTTON_WIDTH  
Config.MULTIPLIER_BOX_HEIGHT = 60  

-- START POINT BELOW BUTTONS (Y = BUTTON_START_Y + Button Stack Height)
local controls_start_y = Config.BUTTON_START_Y + (2 * Config.BUTTON_HEIGHT) + Config.BUTTON_GAP + 28 

-- All indicator boxes use same X position and width
Config.INDICATOR_BOX_START_X = Config.BUTTON_START_X
Config.INDICATOR_BOX_WIDTH = 120
Config.INDICATOR_BOX_HEIGHT = 60

-- 1. PERCENTAGE CALCULATION DISPLAY (FLAT + %)
Config.PERCENT_BOX_Y = controls_start_y + Config.BET_BOX_GAP
-- 2. TOTAL BET BOX
Config.TOTAL_BET_BOX_Y = Config.PERCENT_BOX_Y + Config.INDICATOR_BOX_HEIGHT + Config.BET_BOX_GAP

-- Multiplier Box X Anchor (same as indicator boxes for alignment)
Config.MULTIPLIER_BOX_START_X = Config.INDICATOR_BOX_START_X
Config.MULTIPLIER_BOX_WIDTH = Config.INDICATOR_BOX_WIDTH

-- Atlas row selection: which row (0-based) of the `assets/slot_token_array.png` atlas to use for slot icons
Config.SLOT_ATLAS_ROW = 0

-- 3. STREAK MULTIPLIER 
Config.MULTIPLIER_STREAK_Y = Config.TOTAL_BET_BOX_Y + Config.INDICATOR_BOX_HEIGHT + Config.BET_BOX_GAP
-- 4. SPIN MULTIPLIER 
Config.MULTIPLIER_SPIN_Y = Config.MULTIPLIER_STREAK_Y + Config.INDICATOR_BOX_HEIGHT + Config.BET_BOX_GAP


Config.BUTTON_COLORS = {
    FLAT = {0.15, 0.15, 0.15, 0.8},  -- Translucent grey (matches UI boxes)
    PERCENT = {0.15, 0.15, 0.15, 0.8}  -- Translucent grey (matches UI boxes)
}

Config.BUTTON_BORDER_COLORS = {
    FLAT = {1, 0.84, 0},  -- Gold border
    PERCENT = {1, 0.2, 0.8}  -- Pink border
}

-- Settings Button Configuration
Config.SETTINGS_BTN_SIZE = 50
Config.SETTINGS_BTN_X = Config.LEVER_TRACK_X + (Config.LEVER_TRACK_WIDTH / 2) - (Config.SETTINGS_BTN_SIZE / 2)
Config.SETTINGS_BTN_Y = Config.LEVER_TRACK_Y + Config.LEVER_TRACK_HEIGHT + Config.LEVER_KNOB_RADIUS + 30 
Config.SETTINGS_ASSET = "assets/settings.png" 

-- 10. BETTING MECHANICS (Hybrid Bet)
Config.INITIAL_BANKROLL = 1000  
Config.FLAT_INCREMENT = 100    
Config.PERCENT_INCREMENT = 0.005 
Config.MAX_PERCENT_BET = 0.5   

return Config