function main_loop()
    tmr.alarm(0, 1000, 1, update)
end

function update()
    local data = {
        temp = {
            readTemp(1),
            readTemp(2)
        },
        heater = 0,
        timestamp = rtctime.get()
    }

    if (gpio.read(out1) == gpio.LOW) then
        data.heater = 1
    end

    updateDisplay(data)

    if (data.timestamp - 60 > lastTimestamp) then
        lastTimestamp = data.timestamp
        
        dataExchange.SendData(data)
    end
end

function updateDisplay(data)
    local line = {}
    line[1] = printTemp(data.temp, 1) .. ", " .. printTemp(data.temp, 2)
    if (data.heater) then
        line[1] = line[1] .. ", HEATING"
    end

    local tm = rtctime.epoch2cal(data.timestamp)
    line[2] = timeName .. string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]) .. " UTC"

    display:setColor(0, 0, 0)
    display:drawBox(0, 2 * lineHeight, displayWidth, 2 * lineHeight)
    display:setColor(255, 255, 255)
    display:drawString(lineX[1], lineY[1], 0, line[1])
    display:drawString(lineX[2], lineY[2], 0, line[2])
end

function printTemp(temp, sensorNumber)
    local tempText = ""
    if (temp[sensorNumber]) then
        tempText = tempName[sensorNumber] .. string.format("%.1fC", temp[sensorNumber])
    end

    return tempText
end

function readTemp(sensorNumber)
    local tempVal
    if (sensorAddrs[sensorNumber]) then
        tempVal = ds.read(sensorAddrs[sensorNumber])
    end
    return tempVal
end

function HeaterCallback(state)
    if (state == 0) then
        gpio.write(out1, gpio.HIGH)
    else 
        gpio.write(out1, gpio.LOW)
    end
end

function setup()
    dofile("config.lua")
    
    local networking = loadfile("networking.lua")()
    dataExchange = loadfile("data_exchange.lua")()

    networking.Setup()

-- ports
    out1 = 0
    out2 = 1
    local onewire = 3
    local disp_clk = 5
    local disp_cs = 6
    local disp_mosi = 7
    local disp_dc = 8

-- outputs
    gpio.mode(out1, gpio.OUTPUT)
    gpio.mode(out2, gpio.OUTPUT)

    gpio.write(out1, gpio.HIGH)
    gpio.write(out2, gpio.HIGH)

-- display
    spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, spi.DATABITS_8, 8)
    display = ucg.ili9341_18x240x320_hw_spi(disp_cs, disp_dc)
    display:begin(ucg.FONT_MODE_SOLID)
    display:setRotate270()
    display:clearScreen()
    display:setFont(ucg.font_helvB12_hr)
    display:setColor(1, 0, 0, 0)

    displayWidth = display:getWidth()
    local ascent = display:getFontAscent()
    local descent = display:getFontDescent()
    lineHeight = ascent - descent
    lineX = {}
    lineX[1] = 0
    lineX[2] = 0
    lineY = {}
    lineY[1] = lineHeight
    lineY[2] = 2 * lineHeight
    tempName = {}
    tempName[1] = "Fermenter: "
    tempName[2] = "Ambient: "
    timeName = "Time: "

-- temperature sensors
    ds = require("ds18b20")
    ds.setup(onewire)
    sensorAddrs = ds.addrs()

-- time
    lastTimestamp = 0

    dataExchange.Setup(HeaterCallback)
end

setup()

main_loop()
