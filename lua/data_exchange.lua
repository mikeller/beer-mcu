local M = {}

local endpoint = "/a/" .. config.apiKey .. "/p/" .. config.projectNumber .. "/d/" .. config.deviceUuid .. "/"
local heaterTopic = endpoint .. "actuator/" .. config.heaterName .. "/state"
local callback
local backlog = {}
local mqttClient

local tmr = tmr
local print = print
local cjson = cjson
local mqtt = mqtt
local config = config
local table = table

setfenv(1, M)

function Setup(mainCallback, heaterCallback)
    if (heaterCallback) then
        callback = heaterCallback
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

        if (topic == heaterTopic) then
            HeaterCallback(data)
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
        mqttClient:subscribe(endpoint .. "actuator/" .. config.heaterName .. "/state", 1, function(client)
            print("mqtt client subscribe success")
        end)

        mainCallback()
    end

    DoConnect()
end

function HeaterCallback(message)
    local result = cjson.decode(message)
    if (result) then
        callback(result.state)
    end
end

function SendData(data)
    local dataObject = {
        timestamp = data.timestamp
    }
    local body
    local success = true

    if (data.temp) then
        dataObject.value = data.temp[1]
        body = cjson.encode(dataObject)
        success = mqttClient:publish(endpoint .. "sensor/" .. config.sensor1Name .. "/data", body, 0, 1, PublishCallback) and success
    
        dataObject.value = data.temp[2]
        body = cjson.encode(dataObject)
        success = mqttClient:publish(endpoint .. "sensor/" .. config.sensor2Name .. "/data", body, 0, 1, PublishCallback) and success
    end

    if (data.heater) then
        dataObject.value = data.heater
        body = cjson.encode(dataObject)
        success = mqttClient:publish(endpoint .. "sensor/" .. config.heaterName .. "/data", body, 0, 1, PublishCallback) and success
    end

    if (data.log) then
        dataObject.value = data.log
        body = cjson.encode(dataObject)
        success = mqttClient:publish(endpoint .. "sensor/" .. config.logName .. "/data", body, 0, 1, PublishCallback) and success
    end

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
