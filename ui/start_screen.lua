-- start_screen.lua
local StartScreen = {}

StartScreen.TITLE_TEXT = "McSlots Deluxe"
StartScreen.PROMPT_TEXT = "addiction ex machina"
StartScreen.INSTRUCTIONS = "Survive Poverty | Quip Harder | Lose Everything"
StartScreen.PAUSE_TITLE = "GAME PAUSED"
StartScreen.PAUSE_PROMPT = "Press ESC to Resume"

-- Font sizes for the main title and prompt
-- (Note: These sizes are used in main.lua's love.load function)
StartScreen.TITLE_SIZE = 160
StartScreen.PROMPT_SIZE = 32

return StartScreen