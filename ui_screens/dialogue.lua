-- dialogue.lua
local Dialogue = {}

-- DIALOGUE SETS BASED ON OUTCOME AND STREAK STATUS
-- Streak Status: Positive (>= 0) or Negative (< 0)

-- 1. WINNING WHILE POSITIVE STREAK (Feeling unstoppable)
local win_positive_messages = {
    "CAN'T STOP WINNING!",
    "MY ROMAN EMPIRE.",
    "Brokies Stay Mad.",
    "fuck poor people",
    "quit your job",
    "welcome back retirement fund",
    "who said gambling was bad. retard",
    "money long like a leg",
    "DIP WAS TEMPORARY.",
    "WE FOUND THE CHEAT CODE.",
    "FED, BRACE FOR IMPACT.",
    "2021 CRYPTO RECOUPED.",
    "WE ARE NOT THE SAME.",
    "DOPAMINE SPIKE! MORE!",
    "BETTER THAN LANDLORD WIN.",
    "MY BANK ACCOUNT TRENDS.",
    "House odds? more like wilson yaoi",
    "variance fears ts",
    "and they said statomer cant teach",
    "hustlin' type shit",
    "I can afford unlimted minutes with your mom now",
    "SOFT-LAUNCH RETIREMENT.",
    "GENERATIONAL WEALTH.",
    "UNIVERSE SAID 'YOU WON.'",
    "WRITE A SELF-HELP BOOK.",
    "FEELING DANGEROUS."
}

-- 2. WINNING WHILE NEGATIVE STREAK (Relief, turning the corner)
local win_negative_messages = {
    "LIFESAVER. TURN IT.",
    "TIDE IS CHANGING!",
    "VIBES SHIFTED.",
    "RESET BUTTON HIT.",
    "AVOIDED THE EX.",
    "ACTUAL DOPAMINE RELEASE.",
    "CHEAT MEAL LEFT.",
    "SLIGHTLY LESS POOR.",
    "BACK TO THE TOTE BAG.",
    "REDEMPTION ARC.",
    "HELLO, SOLVENCY.",
    "SURVIVED DEPRESSION.",
    "SUFFERING PAYS OFF.",
    "DELAYED THE BREAKDOWN.",
    "MENTAL HEALTH UP 3.",
    "ALMOST IN TOO DEEP.",
    "DESPAIR ERA ENDED.",
    "WORST IS OVER... FOR NOW.",
    "FINANCIAL KARMA.",
    "THERAPIST WILL BE PROUD.",
    "NO MORE SADBOY HOURS.",
    "I'M BACK. DEBT NERVOUS.",
    "FRAME THIS SCREENSHOT.",
    "VIRAL MARKETING WIN.",
    "BROKE THE POVERTY CURSE!",
    "VICTORY FOR THE BROKE."
}

-- 3. LOSING WHILE POSITIVE STREAK (Frustration, streak broken)
local lose_positive_messages = {
    "NO! STREAK BROKEN!",
    "WHY STOP NOW?",
    "NEED MOMENTUM BACK!",
    "MINOR SETBACK. SPIN.",
    "CASINO AI ATTACK!",
    "FINANCIAL BETRAYAL.",
    "SYSTEM IS RIGGED! MODS!",
    "BAD VIBE CHECK.",
    "GO TOUCH GRASS? NO.",
    "COMPLAINT FILED.",
    "RAGE-QUIT, WALLET OPEN.",
    "WORSE THAN SHADOW-BAN.",
    "I BLAME THE WI-FI.",
    "SPOILED SHOW FINALE.",
    "BAD BEAT NOT MY BRAND.",
    "RESISTING PHONE TOSS.",
    "AUDACITY OF THIS LOSS.",
    "NEED TO PROCESS TRAUMA.",
    "TAKING IT PERSONALLY.",
    "TRUST GUT, NOT MATH.",
    "RITUAL CLEANSING NOW.",
    "NOT A VIBE. AN ATTACK.",
    "TESTING MY COMMITMENT.",
    "DIVERSIFYING INTO DEBT.",
    "NO $12 COFFEE TODAY.",
    "ALGORITHM, CHILL OUT."
}

-- 4. LOSING WHILE NEGATIVE STREAK (Despair, digging the hole deeper)
local lose_negative_messages = {
    "WHERE'S THE HOUSE DEED?",
    "EMPTY RETIREMENT.",
    "START A GOFUNDME.",
    "ALAN... WE'RE FUCKED.",
    "IT'S SO JOVER.",
    "RESEARCHING VAN LIFE.",
    "CHECK CUSHIONS AGAIN.",
    "CREDIT SCORE LEFT CHAT.",
    "MY VILLAIN ORIGIN.",
    "STUDENT LOANS TEXTED.",
    "SELL GAMING SETUP.",
    "EMERGENCY RAMEN LEFT.",
    "EYES ARE LEAKING.",
    "B-PLOT TRAGIC COMEDY.",
    "ROCK BOTTOM'S BASEMENT?",
    "WALLET = BLACK HOLE.",
    "JOB: SANDWICH ARTIST.",
    "RENT $$. LANDLORD NOW?",
    "CREDITORS ARE CALLING.",
    "ALGO OF LIFE HATES ME.",
    "DIAL-UP TO SAVE CASH.",
    "STATUS: FINANCIALLY U/A.",
    "TAX WRITE-OFF? RIGHT?",
    "FINANCIALLY CANCELED.",
    "MORTGAGE THE CAT.",
    "SIDE HUSTLE TO CRISIS."
}

-- Default message when user is not spinning (e.g., initial state)
local default_message = "Settings"

local win_cycle = {}
local lose_cycle = {}

-- Shuffles a specific list
local function shuffle_list(list)
    local shuffled = {}
    for i = 1, #list do shuffled[i] = list[i] end
    for i = #shuffled, 2, -1 do
        local j = love.math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

-- Uses a cycle to retrieve messages for a specific set (ensuring rotation)
local cycles = {}
local current_indices = {}

local function get_next_message(message_list, cycle_key)
    if not cycles[cycle_key] or #cycles[cycle_key] == 0 then
        cycles[cycle_key] = shuffle_list(message_list)
        current_indices[cycle_key] = 0
    end
    
    current_indices[cycle_key] = current_indices[cycle_key] + 1
    if current_indices[cycle_key] > #cycles[cycle_key] then
        cycles[cycle_key] = shuffle_list(message_list)
        current_indices[cycle_key] = 1
    end
    return cycles[cycle_key][current_indices[cycle_key]]
end


function Dialogue.load()
    -- Initialize all cycles
    cycles["win_pos"] = shuffle_list(win_positive_messages)
    cycles["win_neg"] = shuffle_list(win_negative_messages)
    cycles["lose_pos"] = shuffle_list(lose_positive_messages)
    cycles["lose_neg"] = shuffle_list(lose_negative_messages)
    
    current_indices["win_pos"] = 0
    current_indices["win_neg"] = 0
    current_indices["lose_pos"] = 0
    current_indices["lose_neg"] = 0
end

-- Public function to retrieve contextual message
-- is_win (bool): true if win, false if loss
-- streak (int): The streak number (positive or negative)
function Dialogue.getContextualMessage(is_win, streak)
    local is_positive_streak = (streak >= 0)
    
    if is_win then
        if is_positive_streak then
            return get_next_message(win_positive_messages, "win_pos")
        else
            return get_next_message(win_negative_messages, "win_neg")
        end
    else
        if is_positive_streak then
            return get_next_message(lose_positive_messages, "lose_pos")
        else
            return get_next_message(lose_negative_messages, "lose_neg")
        end
    end
end

function Dialogue.getDefaultMessage()
    return default_message
end

return Dialogue