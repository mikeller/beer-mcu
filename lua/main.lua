function Main()
    local code, reason = node.bootreason()
    Log("Reboot. Code: " .. code .. " reason: " .. reason)

    tmr.alarm(0, 1000, 1, UpdateState)

    cron.schedule("* * * * *", SendSensorData)
    cron.schedule("0 * * * *", function ()
        Log("Ping")
    end)
end

function Log(message)
    print(message)

    local logData = {
        timestamp = rtctime.get(),
        log = message
    }
    dataExchange.SendData(logData)
end

function UpdateState()
    DetectSensors()

   local newSensorData = {
         wortTemp = ReadTemp(1),
         ambientTemp = ReadTemp(2),
         heaterState = ReadHeaterState(),
         timestamp = rtctime.get()
    }
    sensorData = newSensorData
    local newHeaterState = sensorData.heaterState

    if (heaterMainSwitch) then
        if (sensorData.wortTemp >= wortTempTarget) then
            newHeaterState = 0
        elseif (sensorData.wortTemp < wortTempTarget - wortTempHysteresis) then
            newHeaterState = 1
        end
    else
        newHeaterState = 0
    end

    if (newHeaterState ~= sensorData.heaterState) then
        sensorData.heaterState = newHeaterState

        UpdateHeater(sensorData.heaterState)

        updateNeeded = true
    end

--    display.Update(sensorData, heaterMainSwitch, wortTempTarget, wortTempHysteresis)

    if (updateNeeded) then
        SendSensorData()
    end
end

function SendSensorData()
    if (sensorData.timestamp) then
        dataExchange.SendData(sensorData)
    end

    updateNeeded = false
end

function ReadTemp(sensorNumber)
    local tempVal
    if (sensorAddrs[sensorNumber]) then
        tempVal = ds.read(sensorAddrs[sensorNumber])
    end

    return tempVal
end

function ReadHeaterState()
    local state = 0
    if (gpio.read(out1) == gpio.LOW) then
        state = 1
    end

    return state
end

function HeaterCallback(code)
    if (code == 1) then
        heaterMainSwitch = true

        Log("Heater main switch set to on.")
    else
        heaterMainSwitch = false

        Log("Heater main switch set to off.")
    end

    updateNeeded = true
end

function WortTempTargetCallback(code)
    wortTempTarget = code

    Log("Wort temp target set to: " .. wortTempTarget)

    updateNeeded = true
end

function WortTempHysteresisCallback(code)
    wortTempHysteresis = code / 10

    Log("Wort temp hysteresis set to: " .. wortTempHysteresis)

    updateNeeded = true
end

function UpdateHeater(state)
    if (state == 1) then
        gpio.write(out1, gpio.LOW)

        Log("Switched heater on.")
    else
        gpio.write(out1, gpio.HIGH)

        Log("Switched heater off.")
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
--    display = assert(loadfile("display.lua"))()

    sensorData = {}
    heaterMainSwitch = false
    wortTempTarget = 20
    wortTempHysteresis = 0.5
    updateNeeded = false

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
--    display.Setup(disp_cs, disp_dc)

-- temperature sensors
    ds = require("ds18b20")
    ds.setup(onewire)
    DetectSensors()

    function DataExchangeSetup()
        dataExchange.Setup(Main, HeaterCallback, WortTempTargetCallback, WortTempHysteresisCallback)
    end

    networking.Setup(DataExchangeSetup)
end

Setup()
