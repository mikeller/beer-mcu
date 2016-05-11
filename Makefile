project_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

firmware:
		cd $(project_path)nodemcu-firmware/; docker run --rm -ti -v $(project_path)nodemcu-firmware/:/opt/nodemcu-firmware marcelstoer/nodemcu-build
