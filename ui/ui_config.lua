-- ui_config.lua
-- Centralized configuration for all UI elements
-- Contains colors, dimensions, fonts, animations, and positioning

local UIConfig = {}

-- ============================================================================
-- FONTS
-- ============================================================================
UIConfig.FONT_FILE = "splashfont.otf"
UIConfig.BUTTON_FONT_SIZE = 18
UIConfig.SYMBOL_FONT_SIZE = 24

-- ============================================================================
-- COLORS
-- ============================================================================

-- Box styling
UIConfig.BOX_BACKGROUND_COLOR = {0.08, 0.08, 0.08, 0.6}
UIConfig.BOX_BORDER_COLOR = {1, 1, 1}

-- Button styling
UIConfig.BUTTON_BACKGROUND_COLOR = {0.3, 0.3, 0.3}
UIConfig.BUTTON_BACKGROUND_DARK = {0.15, 0.15, 0.15}

-- Text colors
UIConfig.TEXT_WHITE = {1, 1, 1}
UIConfig.TEXT_YELLOW = {1, 1, 0}
UIConfig.TEXT_CYAN = {0.2, 1.0, 1.0}
UIConfig.TEXT_GREEN = {0.2, 1.0, 0.2}
UIConfig.TEXT_GRAY = {0.7, 0.7, 0.7}

-- Status colors
UIConfig.BANKROLL_POSITIVE = {0.2, 1.0, 0.2}
UIConfig.BANKROLL_NEGATIVE = {1, 0.2, 0.2}

-- Multiplier box colors
UIConfig.STREAK_BONUS_COLOR = {0.2, 1.0, 0.2, 1.0}
UIConfig.SPIN_MULTIPLIER_COLOR = {1.0, 0.8, 0.0, 1.0}

-- Overlay
UIConfig.OVERLAY_BLACK = {0, 0, 0, 1}

-- ============================================================================
-- DISPLAY BOXES
-- ============================================================================
UIConfig.DISPLAY_BOX_COUNT = 5
UIConfig.DISPLAY_BOX_COLOR = {0.15, 0.15, 0.15, 0.8}

-- Lucky keepsake box
UIConfig.LUCKY_BOX_WIDTH = 120
UIConfig.LUCKY_BOX_HEIGHT = 120

-- Bottom overlays
UIConfig.BOTTOM_BOX_HEIGHT = 40
UIConfig.BOTTOM_BOX_GAP = 5
UIConfig.BOTTOM_BOX_LEFT_OFFSET = 230

-- ============================================================================
-- BUTTONS
-- ============================================================================
UIConfig.BUTTON_ANIMATION_DEPTH = 5  -- Pixel offset when pressed
UIConfig.BUTTON_Y_OFFSET = 35        -- Vertical offset from config position
UIConfig.BUTTON_HEIGHT_ADJUSTED = 60 -- Height override for button rendering
UIConfig.BUTTON_BACKDROP_OFFSET = 5  -- Shadow depth offset
UIConfig.BUTTON_CORNER_RADIUS = 10   -- Border radius

-- Button border widths
UIConfig.BUTTON_BORDER_WIDTH = 2
UIConfig.BUTTON_LINE_WIDTH_DEFAULT = 1

-- Button symbol scaling
UIConfig.BUTTON_SYMBOL_SCALE = 0.8
UIConfig.BUTTON_SYMBOL_OFFSET_Y = 5

-- Button text scaling and positioning
UIConfig.BUTTON_TEXT_SCALE = 1.2
UIConfig.BUTTON_TEXT_OFFSET_Y = -15
UIConfig.BUTTON_TEXT_MIN_SCALE = 0.6  -- Minimum scale if text is too wide

-- ============================================================================
-- INDICATOR BOXES
-- ============================================================================
UIConfig.MULTIPLIER_BOX_CORNER_RADIUS = 5
UIConfig.MULTIPLIER_BOX_LABEL_OFFSET_Y = 5
UIConfig.MULTIPLIER_BOX_VALUE_FORMAT = "X%.2f"
UIConfig.MULTIPLIER_LABEL_COLOR = {0.7, 0.7, 0.7}

-- ============================================================================
-- BANKROLL AND PAYOUT
-- ============================================================================
UIConfig.BANKROLL_PAYOUT_PADDING = 10
UIConfig.BANKROLL_PAYOUT_CORNER_RADIUS = 5
UIConfig.BANKROLL_PAYOUT_LINE_SPACING = 10
UIConfig.BANKROLL_TEXT_FORMAT = "$$$: %.0f"
UIConfig.BET_TEXT_FORMAT = "BET: $%.0f"
UIConfig.PAYOUT_SEED = 400
UIConfig.BANKROLL_SEED = 200

-- ============================================================================
-- PERCENTAGE BOX
-- ============================================================================
UIConfig.PERCENT_BOX_TEXT_FORMAT = "$%.0f + %.1f%%"
UIConfig.PERCENT_BOX_LABEL_COLOR = UIConfig.TEXT_CYAN

-- Total bet box
UIConfig.TOTAL_BET_LABEL_COLOR = UIConfig.TEXT_GREEN

-- ============================================================================
-- ANIMATIONS
-- ============================================================================
UIConfig.BUTTON_PRESS_ANIMATION_DEPTH = 5
UIConfig.BOX_CORNER_RADIUS = 5

-- ============================================================================
-- STREAKS AND MULTIPLIERS
-- ============================================================================
UIConfig.STREAK_MULTIPLIER_BASE = 1.0
UIConfig.STREAK_MULTIPLIER_INCREMENT = 0.10

-- ============================================================================
-- BUTTON DEFINITIONS
-- ============================================================================
UIConfig.BUTTON_DEFINITIONS = {
    {
        y_offset = 15,
        type = "FLAT",
        symbol = "$",
        increment_text = "+100",
        label = "FLAT BET"
    },
    {
        y_offset = 0,  -- Will be set by code using Config.BUTTON_HEIGHT + Config.BUTTON_GAP
        type = "PERCENT",
        symbol = "%",
        increment_text = "+0.5%",
        label = "PERCENTAGE BET"
    },
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function UIConfig.getButtonDefinition(index)
    return UIConfig.BUTTON_DEFINITIONS[index]
end

function UIConfig.getButtonCount()
    return #UIConfig.BUTTON_DEFINITIONS
end

-- ============================================================================
-- SETTINGS MENU
-- ============================================================================

-- Menu dimensions (as ratio of game dimensions)
UIConfig.SETTINGS_MENU_WIDTH_RATIO = 0.9
UIConfig.SETTINGS_MENU_HEIGHT_RATIO = 0.9

-- Close button styling
UIConfig.SETTINGS_CLOSE_BTN_SIZE = 50
UIConfig.SETTINGS_CLOSE_BTN_PADDING = 15
UIConfig.SETTINGS_CLOSE_BTN_COLOR = {0.8, 0.1, 0.1, 1.0}
UIConfig.SETTINGS_CLOSE_BTN_LINE_WIDTH = 5

-- Menu styling
UIConfig.SETTINGS_MENU_BACKGROUND = {0.1, 0.1, 0.1, 0.95}
UIConfig.SETTINGS_MENU_BORDER_COLOR = {0.5, 0.5, 0.5, 1.0}
UIConfig.SETTINGS_MENU_BORDER_WIDTH = 3
UIConfig.SETTINGS_MENU_CORNER_RADIUS = 20

-- Settings button styling
UIConfig.SETTINGS_BTN_BACKDROP_ALPHA = 0.2
UIConfig.SETTINGS_BTN_BORDER_ALPHA = 0.5

-- Menu title
UIConfig.SETTINGS_MENU_TITLE = "Settings & Configuration"

return UIConfig
