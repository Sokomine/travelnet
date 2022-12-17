# API

## travelnet.get_travelnets(playername, create)

Returns the per-player travelnet data, for example:

```lua
-- auto-create a new entry if it not exists
local travelnets = travelnet.get_travelnets(playername, true)

-- return the exsiting data, nil if no entry found
local travelnets = travelnet.get_travelnets(playername)
```

## travelnet.set_travelnets(playername, travelnets)

Sets and saves the updated travelnet data for the player
**NOTE**: this function also perists changes

```lua
-- retrieve the player-data
local travelnets = travelnet.get_travelnets(playername)
-- add a station stub
travelnets["my_networks"] = {}
-- save the modified data (calls `travelnet.save_data()` to persist the data)
travelnet.set_travelnets(playername, travelnets)
```

## travelnet.save_data(playername)

Saves the runtime travelnet data to disk
Can be used in place of `travelnet.set_travelnets` to save all player travelnet data that was modified

```lua
-- save 
local travelnets = travelnet.get_travelnets(playername)
-- call other function that might modify the data
other_fn(travelnet)
-- call "save_data" directly to persist changes of the runtime data
travelnet.save_data(playername)
```


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
