-- game_info.lua
-- Simple Game Info menu (styled like the shop). Toggle via a button above the lever.

local Config = require("conf")
local UIConfig = require("ui.ui_config")
local Shop = require("ui.shop")

local GameInfo = {}

local is_open = false
local info_entrance_timer = 0
local info_entrance_duration = 0.4

-- Match shop menu dimensions/position
local INFO_W = Config.GAME_WIDTH * 0.77
local INFO_H = Config.GAME_HEIGHT * 0.5
local INFO_X = (Config.GAME_WIDTH - INFO_W) / 2
local INFO_Y = (Config.GAME_HEIGHT - INFO_H) / 2 + 92

local button_w = 96
local button_h = 96

function GameInfo.initialize()
    is_open = false
    info_entrance_timer = 0
end

function GameInfo.is_open()
    return is_open
end

function GameInfo.open()
    is_open = true
    info_entrance_timer = info_entrance_duration
end

function GameInfo.close()
    is_open = false
    info_entrance_timer = 0
end

function GameInfo.toggle()
    if is_open then GameInfo.close() else GameInfo.open() end
end

function GameInfo.update(dt)
    if is_open then
        info_entrance_timer = math.min(info_entrance_duration, info_entrance_timer + dt)
    else
        info_entrance_timer = math.max(0, info_entrance_timer - dt)
    end
end

-- Compute button position: to the right of the display area / above lever
function GameInfo.get_button_rect()
    local bx = Config.LEVER_TRACK_X + Config.LEVER_TRACK_WIDTH + 12 - 70
    local by = Config.SLOT_Y - 160 + 48 - (button_h * 0.25)
    return bx, by, button_w, button_h
end

function GameInfo.check_button_click(gx, gy)
    local bx, by, bw, bh = GameInfo.get_button_rect()
    return gx >= bx and gx <= bx + bw and gy >= by and gy <= by + bh
end

-- Check using screen coordinates (handles different window scales/offsets)
function GameInfo.check_button_click_screen(sx, sy)
    local w, h = love.graphics.getDimensions()
    local s = math.min(w / Config.GAME_WIDTH, h / Config.GAME_HEIGHT)
    local ox = (w - Config.GAME_WIDTH * s) / 2
    local oy = (h - Config.GAME_HEIGHT * s) / 2
    local gx = (sx - ox) / s
    local gy = (sy - oy) / s
    return GameInfo.check_button_click(gx, gy)
end

function GameInfo.draw_button()
    local bx, by, bw, bh = GameInfo.get_button_rect()
    love.graphics.push()
    love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)
    local f = love.graphics.newFont("splashfont.otf", 28)
    love.graphics.setFont(f)
    local lines
    if is_open then
        lines = {"CLOSE", "INFO"}
    else
        lines = {"GAME", "INFO"}
    end
    local fh = f:getHeight()
    local spacing = 2
    local total_h = #lines * fh + (#lines - 1) * spacing
    local start_y = by + (bh - total_h) / 2
    for i, ln in ipairs(lines) do
        local tw = f:getWidth(ln)
        love.graphics.print(ln, bx + (bw - tw) / 2, start_y)
        start_y = start_y + fh + spacing
    end
    love.graphics.pop()
end

function GameInfo.draw()
    if not (is_open or info_entrance_timer > 0) then return end

    -- Compute own entrance slide (from bottom) using entrance timer
    local progress = info_entrance_duration > 0 and (info_entrance_timer / info_entrance_duration) or 1
    local ease = 1 - (1 - progress) ^ 3
    local own_slide = (1 - ease) * Config.GAME_HEIGHT

    -- Use the shop's slide offset when the shop is open/animating so the panel aligns;
    -- otherwise use our own slide for entrance/exit animation.
    local slide_offset = 1
    -- if Shop and Shop.is_open and Shop.is_open() and Shop.get_slide_offset then
    --     slide_offset = Shop.get_slide_offset()
    -- else
    --     slide_offset = own_slide
    -- end

    print("[GameInfo] draw: is_open=", tostring(is_open), "info_timer=", info_entrance_timer, "slide_offset=", slide_offset)

    love.graphics.push()
    love.graphics.translate(0, slide_offset)

    -- Match shop menu background color/opacity and border
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", INFO_X, INFO_Y, INFO_W, INFO_H, 10, 10)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", INFO_X, INFO_Y, INFO_W, INFO_H, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title (match shop title style)
    love.graphics.setColor(1, 1, 0, 1)
    local title_font = love.graphics.newFont("splashfont.otf", 28)
    love.graphics.setFont(title_font)
    local title = "GAME INFO"
    local tx = INFO_X + 20
    local ty = INFO_Y + 18
    love.graphics.print(title, tx, ty)

    -- Body text (match shop stats font size and color)
    love.graphics.setColor(1, 1, 1, 1)
    local body_font = love.graphics.newFont("splashfont.otf", 16)
    love.graphics.setFont(body_font)
    local lines = {
        "- Objective: Reach the round goal to open the shop.",
        "- Spins per round: 100 (use spins in the shop to gain gems).",
        "- Upgrades affect payouts and shop economy.",
        "- QTEs can trigger from near-miss results to give bonuses.",
        "- Check the Upgrade tooltips for exact effect numbers."
    }
    local ly = ty + 36
    for i, l in ipairs(lines) do
        love.graphics.print(l, tx, ly)
        ly = ly + 22
    end

    love.graphics.pop()
end

return GameInfo
