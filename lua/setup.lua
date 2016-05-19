local ntpServer = "pool.ntp.org"

function SetupNetwork()
  enduser_setup.start(
    function()
      print("Connected to wifi as:" .. wifi.sta.getip())

      SynchNtp()
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
    end,
    function()
      print('NTP failed!')
    end
  )
end

SetupNetwork()
