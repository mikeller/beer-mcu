project_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

all:

lua:		ds18b20 init reboot_mcu

init:
		luatool/luatool/luatool.py -b 115200 -f init.lua

ds18b20:
		luatool/luatool/luatool.py -b 115200 -f nodemcu-firmware/lua_modules/ds18b20/ds18b20.lua -c

reboot_mcu:
		luatool/luatool/luatool.py -b 115200 -f empty.lua -r

firmware:	firmware_build firmware_deploy

firmware_build:
		cd $(project_path)nodemcu-firmware; \
                docker run --rm -ti -v $(project_path)nodemcu-firmware/:/opt/nodemcu-firmware -e "IMAGE_NAME=beer-mcu" -e "FLOAT_ONLY=1" mikeller/nodemcu-build

firmware_deploy:
		nodemcu-firmware/tools/esptool.py write_flash 0x00000 nodemcu-firmware/bin/nodemcu_float_beer-mcu.bin
