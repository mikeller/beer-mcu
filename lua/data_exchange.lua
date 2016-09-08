local M = {}

local url = "http://api.devicehub.net/v2/project/" .. config.projectNumber .. "/device/" .. config.deviceUuid .. "/"
local headers = "X-ApiKey: " .. config.apiKey .. "\r\nContent-Type: application/json\r\n"
local callback
local backlog = {}

local tmr = tmr
local print = print
local cjson = cjson
local http = http
local config = config
local table = table

setfenv(1, M)

function Setup(heaterCallback)
    if (heaterCallback) then
        callback = heaterCallback
        tmr.alarm(2, 60 * 1000, 1, CheckHeater)
    end
end

function CheckHeater()
    http.get(url .. "actuator/" .. config.heaterName .. "/state", headers, ProcessResult)
end

function ProcessResult(code, result)
    if (code < 0) then
        print("HTTP request failed: " .. code)
    else
        print("HTTP request successful: " .. code .. ", " .. result)

        local result = cjson.decode(result)
        callback(result[1].state)
    end
end
            
function SendData(data)
    local dataObject = {
        value = data.temp[1],
        timestamp = data.timestamp
    }
    local body = cjson.encode(dataObject)
    http.post(url .. "sensor/" .. config.sensor1Name .. "/data", headers, body, CheckResult)
    
    dataObject.value = data.temp[2]
    body = cjson.encode(dataObject)
    http.post(url .. "sensor/" .. config.sensor2Name .. "/data", headers, body, CheckResult)

    dataObject.value = data.heater
    body = cjson.encode(dataObject)
    http.post(url .. "sensor/" .. config.heaterName .. "/data", headers, body, CheckResult)

    if (data.log) then
        dataObject.value = data.log
        body = cjson.encode(dataObject)
        http.post(url .. "sensor/" .. config.logName .. "/data", headers, body, CheckResult)
    end

    function CheckResult(code, result)
        if (code < 200 or code >= 300) then
            local message = "HTTP request failed: " .. code
            if (result) then
                message = message .. ", result: " .. result
            end

            print(message)

            if (not data.isBacklogged) then
                data.log = message
                data.isBacklogged = true
                table.insert(backlog, data)
            end
        else
            print("HTTP request successful: " .. code .. ", " .. result)

            local result = cjson.decode(result)
            if (result.request_status == 1) then
                lastTimestamp = data.timestamp

                while (table.getn(backlog) > 0) do
                    backlogData = table.remove(backlog, 1)

                    SendData(backlogData)
                end
            end
        end
    end
end

return M
