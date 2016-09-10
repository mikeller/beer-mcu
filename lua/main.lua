function MainLoop()
    local code, reason = node.bootreason()
    local data = {
        timestamp = rtctime.get(),
        log = "Reboot. Code: " .. code .. " reason: " .. reason
    }
    dataExchange.SendData(data)

    tmr.alarm(0, 1000, 1, Update)
end

function Update()
    DetectSensors()
    local data = {
        temp = {
            ReadTemp(1),
            ReadTemp(2)
        },
        heater = 0,
        timestamp = rtctime.get()
    }

    if (gpio.read(out1) == gpio.LOW) then
        data.heater = 1
    end

    display.Update(data)

    if (data.timestamp - 60 > lastTimestamp) then
        lastTimestamp = data.timestamp
        
        dataExchange.SendData(data)
    end
end

function ReadTemp(sensorNumber)
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

function DetectSensors()
    if (not sensorAddrs or table.getn(sensorAddrs) < 2) then
        sensorAddrs = ds.addrs()
    end
end

function Setup()
    dofile("config.lua")
    
    local networking = assert(loadfile("networking.lua"))()
    dataExchange = assert(loadfile("data_exchange.lua"))()
    display = assert(loadfile("display.lua"))()

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
    display.Setup(disp_cs, disp_dc)

-- temperature sensors
    ds = require("ds18b20")
    ds.setup(onewire)
    DetectSensors()

    lastTimestamp = 0

    function DataExchangeSetup()
        dataExchange.Setup(MainLoop, HeaterCallback)
    end

    networking.Setup(DataExchangeSetup)
end

Setup()
