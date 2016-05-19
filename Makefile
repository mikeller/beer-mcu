project_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY:		all lua firmware firmware_build firmware_deploy

all:

lua:		deploy/ds18b20.lua deploy/main.lua deploy/setup.lua deploy/init.lua

deploy/setup.lua:	lua/setup.lua
		luatool/luatool/luatool.py -b 115200 -f lua/setup.lua && \
		touch deploy/setup.lua

deploy/main.lua:	lua/main.lua
		luatool/luatool/luatool.py -b 115200 -f lua/main.lua && \
		touch deploy/main.lua

deploy/init.lua:	lua/init.lua
		luatool/luatool/luatool.py -b 115200 -f lua/init.lua && \
		touch deploy/init.lua

deploy/ds18b20.lua:	nodemcu-firmware/lua_modules/ds18b20/ds18b20.lua
		luatool/luatool/luatool.py -b 115200 -f nodemcu-firmware/lua_modules/ds18b20/ds18b20.lua -c && \
		touch deploy/ds18b20.lua

firmware:	firmware_build firmware_deploy

firmware_build:	nodemcu-firmware/bin/nodemcu_float_beer-mcu.bin

nodemcu-firmware/bin/nodemcu_float_beer-mcu.bin:	nodemcu-firmware/app/include/user_config.h nodemcu-firmware/app/include/user_modules.h nodemcu-firmware/app/include/user_version.h 
		docker run --rm -ti -v $(project_path)nodemcu-firmware/:/opt/nodemcu-firmware -e "IMAGE_NAME=beer-mcu" -e "FLOAT_ONLY=1" mikeller/nodemcu-build
		#docker run --rm -ti -v $(project_path)nodemcu-firmware/:/opt/nodemcu-firmware -e "IMAGE_NAME=beer-mcu" -e "FLOAT_ONLY=1" marcelstoer/nodemcu-build

firmware_deploy:	deploy/nodemcu_float_beer-mcu.bin

deploy/nodemcu_float_beer-mcu.bin:	nodemcu-firmware/bin/nodemcu_float_beer-mcu.bin
		nodemcu-firmware/tools/esptool.py write_flash 0x00000 nodemcu-firmware/bin/nodemcu_float_beer-mcu.bin && \
		touch deploy/nodemcu_float_beer-mcu.bin
