# API

## travelnet.register_travelnet_box

Lets you register your own travelnet boxes with a custom color, name and dye ingredient

Example for a pink travelnet:
```lua
travelnet.register_travelnet_box({
	nodename = "travelnet:travelnet_pink",
	color = "#FFC0CB",
	dye = "dye:pink"
})
```

## fully custom nodes

Any node can be travelnet box if configured accordingly

Example to override mese to act as a travelnet:
```lua
minetest.override_item("default:mese", {
	groups = {
		travelnet = 1
	},

	after_place_node  = function(pos, placer, itemstack)
		local meta = minetest.get_meta(pos);
		travelnet.reset_formspec( meta );
		meta:set_string("owner", placer:get_player_name());
	end,

	on_receive_fields = travelnet.on_receive_fields,

	on_punch = function(pos, node, puncher)
		travelnet.update_formspec(pos, puncher:get_player_name(), nil)
	end,

	can_dig = function( pos, player )
		return travelnet.can_dig( pos, player, 'mese travelnet box' )
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		travelnet.remove_box( pos, oldnode, oldmetadata, digger )
	end,
})
```
