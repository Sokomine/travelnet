
-- "basic" travelnet box in yellow
travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet",
	recipe = travelnet.travelnet_recipe,
	color = "#ffff00"
})

travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_red",
	color = "#ff0000",
	dye = "dye:red"
})

travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_blue",
	color = "#0000ff",
	dye = "dye:blue"
})

travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_green",
	color = "#00ff00",
	dye = "dye:green"
})

travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_black",
	color = "#000000",
	dye = "dye:black",
	light_source = 0
})

travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_white",
	color = "#ffffff",
	dye = "dye:white",
	light_source = 14
})
