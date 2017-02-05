local M = {}

local endpoint = "/a/" .. config.apiKey .. "/p/" .. config.projectNumber .. "/d/" .. config.deviceUuid .. "/"
local heaterMainTopic = endpoint .. "actuator/" .. config.heaterMainInput .. "/state"
local wortTempTargetTopic = endpoint .. "actuator/" .. config.wortTempTarget .. "/state"
local wortTempHysteresisTopic = endpoint .. "actuator/" .. config.wortTempHysteresis .. "/state"
local heaterCallback
local wortTempTargetCallback
local wortTempHysteresisCallback
local backlog = {}
local mqttClient

local tmr = tmr
local print = print
local cjson = cjson
local mqtt = mqtt
local config = config
local table = table
local tonumber = tonumber

setfenv(1, M)

function Setup(mainCallback, newHeaterCallback, newWortTempTargetCallback, newWortTempHysteresisCallback)
    if (newHeaterCallback) then
        heaterCallback = newHeaterCallback
    end

    if (newWortTempTargetCallback) then
        wortTempTargetCallback = newWortTempTargetCallback
    end

    if (newWortTempHysteresisCallback) then
        wortTempHysteresisCallback = newWortTempHysteresisCallback
    end

    mqttClient = mqtt.Client("beerMcu", 120, "", "")

    -- setup Last Will and Testament (optional)
    -- Broker will publish a message with qos = 0, retain = 0, data = "offline" 
    -- to topic "/lwt" if client don't send keepalive packet
    mqttClient:lwt("/lwt", "offline", 0, 0)
    
    mqttClient:on("connect", function(client)
        print ("mqtt client connected")
    end)
    mqttClient:on("offline", function(client)
        print ("mqtt client offline")
    end)

    mqttClient:on("message", function(client, topic, data) 
        local message = "mqtt client message for '" .. topic .. "': "
        if data ~= nil then
            message = message .. data
        end
        print(message)

        if (topic == heaterMainTopic) then
            DoCallback(heaterCallback, data)
        elseif (topic == wortTempTargetTopic) then
            DoCallback(wortTempTargetCallback, data)
        elseif (topic == wortTempHysteresisTopic) then
            DoCallback(wortTempHysteresisCallback, data)
        end
    end)

    function DoConnect()
        mqttClient:connect("mqtt.devicehub.net", 1883, 0, function(client)
            print("mqtt client connected")

            FinishSetup()
        end, function(client, reason)
            print("mqtt client connect failed reason: " .. reason .. ". retrying in 5s.")

            tmr.alarm(1, 5000, tmr.ALARM_SINGLE, DoConnect)
        end)
    end

    function FinishSetup()
        mqttClient:subscribe(heaterMainTopic, 1, function(client)
            print("mqtt client subscribed to  " .. heaterMainTopic)
        end)

        mqttClient:subscribe(wortTempTargetTopic, 1, function(client)
            print("mqtt client subscribed to  " .. wortTempTargetTopic)
        end)

        mqttClient:subscribe(wortTempHysteresisTopic, 1, function(client)
            print("mqtt client subscribed to  " .. wortTempHysteresisTopic)
        end)

        mainCallback()
    end

    DoConnect()
end

function DoCallback(callbackFunc, message)
    if (callbackFunc) then
        local result = cjson.decode(message)
        if (result) then
            local code = tonumber(result.state)
            if (code) then
                callbackFunc(code)
            end
        end
    end
end

function PublishSensor(sensorData, timestamp, sensorName)
    local result = true

    if (sensorData) then
        local dataObject = {
            timestamp = timestamp,
            value = sensorData
        }
        local body = cjson.encode(dataObject)
        result = mqttClient:publish(endpoint .. "sensor/" .. sensorName .. "/data", body, 0, 1, PublishCallback)
    end

    return result
end

function SendData(data)
    local dataObject = {
        timestamp = data.timestamp
    }
    local body
    local success = true

    success = PublishSensor(data.wortTemp, data.timestamp, config.wortTempSensor) and success

    success = PublishSensor(data.ambientTemp, data.timestamp, config.ambientTempSensor) and success

    success = PublishSensor(data.heaterState, data.timestamp, config.heaterOnSensor) and success

    success = PublishSensor(data.log, data.timestamp, config.logOutput) and success

    if (success) then
        lastTimestamp = data.timestamp

        local backlogSize = table.getn(backlog)
        if (backlogSize > 0 and not data.isBacklogged) then
            print("Sending " .. backlogSize .. " backlogged messages.")

            while (table.getn(backlog) > 0) do
                backlogData = table.remove(backlog, 1)

                SendData(backlogData)
            end
        end
    else
        print("publishing failed")

        if (not data.isBacklogged) then
            data.isBacklogged = true
            table.insert(backlog, data)
        end
    end

    function PublishCallback(client)
        print("mqtt client publish success")
    end
end

return M
