local S = minetest.get_translator("travelnet")

minetest.register_privilege("travelnet_attach", {
	description = S("allows to attach travelnet boxes to travelnets of other players"),
	give_to_singleplayer = false
})

minetest.register_privilege("travelnet_remove", {
	description = S("allows to dig travelnet boxes which belog to nets of other players"),
	give_to_singleplayer = false
})
