local M = {}

local ntpServer = "pool.ntp.org"

local enduser_setup = enduser_setup
local wifi = wifi
local sntp = sntp
local rtctime = rtctime
local tmr = tmr
local print = print

setfenv(1, M)

function Setup(finishSetupCallback)
    enduser_setup.start(
        function()
            print("Connected to wifi as: " .. wifi.sta.getip())

            SynchNtp()

            finishSetupCallback()
        end,
        function(err, str)
            print("enduser_setup: Err #" .. err .. ": " .. str)
        end
    )
end

function SynchNtp()
    sntp.sync(ntpServer,
        function(sec, usec, server)
            print('NTP sync', sec, usec, server)

            rtctime.set(sec, usec)
        end,
        function()
            print('NTP failed, retrying in 5 s.')

            tmr.alarm(1, 5000, tmr.ALARM_SINGLE, SynchNtp)
        end
    )
end

return M
