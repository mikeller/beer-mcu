function main_loop()
  tmr.alarm(0, 1000, 1, readTemps)
end

function readTemps()
  printTemp(1)
  printTemp(2)
end

function printTemp(sensorNumber)
  display:setColor(0, 0, 0)
  display:drawBox(lineX[sensorNumber], lineY[sensorNumber], lineHeight, dynamicWidth)
  local temp = "?"
  if (sensorAddrs[sensorNumber]) then
    local tempVal = readTemp[sensorNumber](sensorNumber)
    if (tempVal) then
      temp = string.format("%.1fC", tempVal)
    end
  end
  display:setColor(255, 255, 255)
  display:drawString(lineX[sensorNumber], lineY[sensorNumber], 0, temp)
end

function readFakeTemp()
  return adc.read(0) / 16
end

function readDsTemp(sensorNumber)
  return ds.read(sensorAddrs[sensorNumber])
end

function setup()
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
  display:setFont(ucg.font_ncenR14_hr)

  local displayHeight = display:getWidth()
  local displayWidth = display:getHeight()
  local ascent = display:getFontAscent()
  local descent = display:getFontDescent()
  local line1static = "temp1 = "
  local line2static = "temp2 = "
  lineHeight = ascent - descent
  lineX = {}
  lineX[1] = display:getStrWidth(line1static)
  lineX[2] = display:getStrWidth(line2static)
  lineY = {}
  lineY[1] = ascent
  lineY[2] = ascent + lineHeight
  dynamicWidth = display:getStrWidth("999.9C")
  display:drawString(0, lineY[1], 0, line1static)
  display:drawString(0, lineY[2], 0, line2static)
-- temperature sensors
  readTemp = {}

  ds = require("ds18b20")
  ds.setup(onewire)
  sensorAddrs = ds.addrs()
  readTemp[1] = readDsTemp
  readTemp[2] = readDsTemp
end

dofile("setup.lua")

setup()

main_loop()
