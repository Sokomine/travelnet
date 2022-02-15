-- This version of the travelnet box allows to move up or down only.
-- The network name is determined automaticly from the position (x/z coordinates).
-- Author: Sokomine
local S = minetest.get_translator("travelnet")

function travelnet.show_nearest_elevator(pos, owner_name, param2)
	if not pos or not pos.x or not pos.z or not owner_name then
		return
	end

	if not travelnet.targets[owner_name] then
		minetest.chat_send_player(owner_name,
				S("Congratulations! This is your first elevator. " ..
					"You can build an elevator network by placing further elevators somewhere above " ..
					"or below this one. Just make sure that the x and z coordinate are the same."))
		return
	end

	local network_name = travelnet.elevator_network(pos)
	-- will this be an elevator that will be added to an existing network?
	if	    travelnet.targets[owner_name][network_name]
		-- does the network have any members at all?
		and next(travelnet.targets[owner_name][network_name], nil)
	then
		minetest.chat_send_player(owner_name,
				S("This elevator will automaticly connect to the " ..
					"other elevators you have placed at different heights. Just enter a station name " ..
					"and click on \"store\" to set it up. Or just punch it to set the height as station " ..
					"name."))
		return
	end

	local nearest_name, nearest_dist = travelnet.find_nearest_elevator_network(pos, owner_name)

	if not nearest_name then
		minetest.chat_send_player(owner_name,
				S("This is your first elevator. It differs from " ..
					"travelnet networks by only allowing movement in vertical direction (up or down). " ..
					"All further elevators which you will place at the same x,z coordinates at differnt " ..
					"heights will be able to connect to this elevator."))
		return
	end

	local direction_strings = {
		S("m to the right"),
		S("m behind this elevator and"),
		S("m to the left"),
		S("m in front of this elevator and")
	}
	local direction_indexes = { x=param2+1, z=((param2+1) % 4)+1 }

	-- Should X or Z be displayed first?
	local direction_order = ({ [0]={"z","x"}, [1]={"x","z"} })[param2 % 2]

	local text = S("Your nearest elevator network is located") .. " "

	for index, direction in ipairs(direction_order) do
		local nearest_dist_direction = nearest_dist[direction]
		local direction_index = direction_indexes[direction]
		if nearest_dist_direction < 0 then
			direction_index = ((direction_indexes[direction]+1) % 4)+1
		end
		text = text .. tostring(math.abs(nearest_dist_direction)) .. " " .. direction_strings[direction_index]
		if index == 1 then text = text .. " " end
	end

	minetest.chat_send_player(owner_name, text .. S(", located at x") ..
			("=%f, z=%f. "):format(pos.x + nearest_dist.x, pos.z + nearest_dist.z) ..
			S("This elevator here will start a new shaft/network."))
end


local function on_interact(pos, _, player)
	local meta = minetest.get_meta(pos)
	local legacy_formspec = meta:get_string("formspec")
	if not travelnet.is_falsey_string(legacy_formspec) then
		meta:set_string("formspec", "")
	end

	local player_name = player:get_player_name()
	travelnet.show_current_formspec(pos, meta, player_name)
end

minetest.register_node("travelnet:elevator", {
	description = S("Elevator"),
	drawtype = "mesh",
	mesh = "travelnet_elevator.obj",
	sunlight_propagates = true,
	paramtype = "light",
	paramtype2 = "facedir",
	wield_scale = { x=0.6, y=0.6, z=0.6 },

	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
	},

	collision_box = {
		type = "fixed",
		fixed = {

			{ 0.48, -0.5,-0.5,  0.5,  0.5, 0.5},
			{-0.5 , -0.5, 0.48, 0.48, 0.5, 0.5},
			{-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},

			--groundplate to stand on
			{ -0.5,-0.5,-0.5,0.5,-0.48, 0.5},
		},
	},

	tiles = travelnet.tiles_elevator,

	inventory_image = travelnet.elevator_inventory_image,
	groups = {
		elevator = 1
	},

	light_source = 10,

	after_place_node  = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext",       S("Elevator (unconfigured)"))
		meta:set_string("station_name",   "")
		meta:set_string("station_network","")
		meta:set_string("owner",          placer:get_player_name())

		minetest.set_node(vector.add(pos, { x=0, y=1, z=0 }), { name="travelnet:hidden_top" })
		travelnet.show_nearest_elevator(pos, placer:get_player_name(), minetest.dir_to_facedir(placer:get_look_dir()))
	end,

	on_rightclick = on_interact,
	on_punch = on_interact,

	can_dig = function(pos, player)
		return travelnet.can_dig(pos, player, "elevator")
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		travelnet.remove_box(pos, oldnode, oldmetadata, digger)
	end,

	-- TNT and overenthusiastic DMs do not destroy elevators either
	on_blast = function()
	end,

	-- taken from VanessaEs homedecor fridge
	on_place = function(itemstack, placer, pointed_thing)
		local node = minetest.get_node(vector.add(pointed_thing.above, { x=0, y=1, z=0 }))
		local def = minetest.registered_nodes[node.name]
		-- leftover top nodes can be removed by placing a new elevator underneath
		if (not def or not def.buildable_to) and node.name ~= "travelnet:hidden_top" then
			minetest.chat_send_player(
				placer:get_player_name(),
				S("Not enough vertical space to place the travelnet box!")
			)
			return
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,

	on_destruct = function(pos)
		minetest.remove_node(vector.add(pos, { x=0, y=1, z=0 }))
	end
})

minetest.register_craft({
	output = "travelnet:elevator",
	recipe = travelnet.elevator_recipe,
})
