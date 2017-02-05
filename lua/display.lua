local M = {}

local screen
local displayWidth
local lineHeight
local lineColour

local spi = spi
local ucg = ucg
local rtctime = rtctime
local table = table
local string = string
local pairs = pairs

setfenv(1, M)

function Setup(csPin, dcPin)
    spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, spi.DATABITS_8, 8)
    screen = ucg.ili9341_18x240x320_hw_spi(csPin, dcPin)
    screen:begin(ucg.FONT_MODE_SOLID)
    screen:setRotate270()
    screen:clearScreen()
    screen:setFont(ucg.font_helvB12_hr)
    screen:setColor(1, 0, 0, 0)

    displayWidth = screen:getWidth()
    local ascent = screen:getFontAscent()
    local descent = screen:getFontDescent()
    lineHeight = ascent - descent
    lineColour = {
        { 255, 255, 255 },
        { 255, 127, 80 },
        { 255, 0, 0 },
        { 255, 127, 0 }
    }
end

function Update(data, heaterMainSwitch, wortTempTarget, wortTempHysteresis)
    local tm = rtctime.epoch2cal(data.timestamp)
    local lines = {
        string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]) .. " UTC",
        PrintTemp(data.wortTemp, "Wort: ") .. ", " .. PrintTemp(data.ambientTemp, "Amb.: "),
        "",
        PrintTemp(wortTempTarget, "Target: ") .. ", " .. PrintTemp(wortTempHysteresis, "Hyst.: ")
    }

    if (heaterMainSwitch) then
        lines[3] = lines[3] .. "MAIN "
    end

    if (data.heater ~= 0) then
        lines[3] = lines[3] .. "HEATER "
    end

    for index, line in pairs(lines) do
        screen:setColor(0, 0, 0)
        screen:drawBox(0, ascent + (index - 1) * lineHeight, displayWidth, lineHeight)
        if (lineColour[index]) then
            screen:setColor(lineColour[index][1], lineColour[index][2], lineColour[index][3])
        else
            screen.setColour(255, 255, 255)
        end
        screen:drawString(0, ascent + (index - 1) * lineHeight, 0, line)
    end
end

function PrintTemp(temp, tempName)
    local tempText = ""
    if (temp) then
        tempText = tempName .. string.format("%.1fC", temp)
    end

    return tempText
end

return M
