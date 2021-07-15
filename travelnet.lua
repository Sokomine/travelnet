
local default_travelnets = {
	-- "default" travelnet box in yellow
	{ nodename="travelnet:travelnet", color="#e0bb2d", dye="dye:yellow", recipe=travelnet.travelnet_recipe },
	{ nodename="travelnet:travelnet_red", color="#ce1a1a", dye="dye:red" },
	{ nodename="travelnet:travelnet_orange", color="#e2621b", dye="dye:orange" },
	{ nodename="travelnet:travelnet_blue", color="#0051c5", dye="dye:blue" },
	{ nodename="travelnet:travelnet_cyan", color="#00a6ae", dye="dye:cyan" },
	{ nodename="travelnet:travelnet_green", color="#53c41c", dye="dye:green" },
	{ nodename="travelnet:travelnet_dark_green", color="#2c7f00", dye="dye:dark_green" },
	{ nodename="travelnet:travelnet_violet", color="#660bb3", dye="dye:violet" },
	{ nodename="travelnet:travelnet_pink", color="#ff9494", dye="dye:pink" },
	{ nodename="travelnet:travelnet_magenta", color="#d10377", dye="dye:magenta" },
	{ nodename="travelnet:travelnet_brown", color="#572c00", dye="dye:brown" },
	{ nodename="travelnet:travelnet_grey", color="#a2a2a2", dye="dye:grey" },
	{ nodename="travelnet:travelnet_dark_grey", color="#3d3d3d", dye="dye:dark_grey" },
	{ nodename="travelnet:travelnet_black", color="#0f0f0f", dye="dye:black", light_source=0 },
	{ nodename="travelnet:travelnet_white", color="#ffffff", dye="dye:white", light_source=minetest.LIGHT_MAX },
}

for _, cfg in ipairs(default_travelnets) do
	travelnet.register_travelnet_box(cfg)
end
