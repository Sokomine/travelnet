local S = minetest.get_translator("travelnet")

-- add a new target; meta is optional
function travelnet.add_target(station_name, network_name, pos, player_name, meta, owner_name)
	local node = minetest.get_node(pos)
	local is_elevator = travelnet.is_elevator(node.name)
	local success, result = travelnet.actions.add_station({
		pos = pos,
		node = node,
		meta = meta,
		props = {
			station_name = station_name,
			station_network = network_name,
			owner_name = owner_name,
			is_elevator = is_elevator
		},
	}, {}, minetest.get_player_by_name(player_name))
	if not success then
		travelnet.show_message(pos, player_name, S("Error"), result)
	end
end
