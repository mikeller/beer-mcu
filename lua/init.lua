function abortInit()
    -- initailize abort boolean flag
    abort = false
    print('Press ENTER to abort startup...')
    -- if <CR> is pressed, call abortTest
    uart.on('data', '\r', abortTest, 0)
    -- start timer to execute startup function in 5 seconds
    tmr.alarm(0, 5000, 0, startup)
end
    
function abortTest(data)
    -- user requested abort
    abort = true
    -- turns off uart scanning
    uart.on('data')
end

function startup()
    uart.on('data')

    if not abort then
        print('Starting main program...')
        dofile('main.lua')
    else
        print('Startup aborted.')
    end
end

tmr.alarm(0, 1000, 0, abortInit)
