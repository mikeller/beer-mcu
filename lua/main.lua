function main_loop()
    tmr.alarm(0, 1000, 1, update)
end

function update()
    local data = {}
    data.temp = {}
    data.temp[1] = readTemp(1)
    data.temp[2] = readTemp(2)
    data.timestamp = rtctime.get()

    updateDisplay(data)

    if (data.timestamp - 60 > lastTimestamp) then
        lastTimestamp = data.timestamp
        
        sendData(data)
    end
end

function sendData(data)
    local url = "http://api.devicehub.net/v2/project/" .. config.projectNumber .. "/device/" .. config.deviceUuid .. "/sensor/"
    local apiKey = "X-ApiKey: " .. config.apiKey .. "\r\nContent-Type: application/json\r\n"

    local dataObject = {
        value = data.temp[1],
        timestamp = data.timestamp
    }
    local body = cjson.encode(dataObject)
    http.post(url .. config.sensor1Name .. "/data", apiKey, body, checkResult)
    
    dataObject.value = data.temp[2]
    local body = cjson.encode(dataObject)
    http.post(url .. config.sensor2Name .. "/data", apiKey, body, checkResult)

    local timestamp = data.timestamp
    function checkResult(code, data)
        if (code < 0) then
            print("HTTP request failed: " .. code)
        else
            print("HTTP request successful: " .. code .. ", " .. data)

            local result = cjson.decode(data)
            if (result.request_status == 1) then
                lastTimestamp = timestamp
            end
        end
    end
end

function updateDisplay(data)
    local line = {}
    line[1] = printTemp(data.temp, 1) .. ", " .. printTemp(data.temp, 2)

    local tm = rtctime.epoch2cal(data.timestamp)
    line[2] = timeName .. string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]) .. " UTC"

    display:setColor(0, 0, 0)
    display:drawBox(0, 2 * lineHeight, displayWidth, 2 * lineHeight)
    display:setColor(255, 255, 255)
    display:drawString(lineX[1], lineY[1], 0, line[1])
    display:drawString(lineX[2], lineY[2], 0, line[2])
end

function printTemp(temp, sensorNumber)
    local tempText
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

function setup()
    dofile("config.lua")
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
end

dofile("setup.lua")

setup()

main_loop()
