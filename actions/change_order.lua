local S = minetest.get_translator("travelnet")

return function (node_info, fields, player)
	local player_name = player:get_player_name()

	-- does the player want to move this station one position up in the list?
	-- only the owner and players with the travelnet_attach priv can change the order of the list
	-- Note: With elevators, only the "G"(round) marking is actually moved
	if fields and (fields.move_up or fields.move_down)
		and not travelnet.is_falsey_string(node_info.props.owner_name)
		and (
			   (node_info.props.owner_name == player_name)
			or (minetest.check_player_privs(player_name, { travelnet_attach=true }))
		)
	then
		local network = travelnet.get_network(node_info.props.owner_name, node_info.props.station_network)

		if not network then
			return false, S("This station does not have a network.")
		end
		local stations = travelnet.get_ordered_stations(
			node_info.props.owner_name,
			node_info.props.station_network,
			node_info.props.is_elevator
		)

		local current_pos = -1
		for index, k in ipairs(stations) do
			if k == node_info.props.station_name then
				current_pos = index
				break
			end
		end

		local swap_with_pos
		if fields.move_up then
			swap_with_pos = current_pos-1
		else
			swap_with_pos = current_pos+1
		end

		-- handle errors
		if swap_with_pos < 1 then
			return false, S("This station is already the first one on the list.")
		elseif swap_with_pos > #stations then
			return false, S("This station is already the last one on the list.")
		else
			local current_station = stations[current_pos]
			local swap_with_station = stations[swap_with_pos]

			-- swap the actual data by which the stations are sorted
			local old_timestamp = network[swap_with_station].timestamp
			network[swap_with_station].timestamp = network[current_station].timestamp
			network[current_station].timestamp = old_timestamp

			-- for elevators, only the "G"(round) marking is moved; no point in swapping stations
			if not node_info.props.is_elevator then
				-- actually swap the stations
				stations[swap_with_pos] = current_station
				stations[current_pos]   = swap_with_station
			end

			-- store the changed order
			travelnet.save_data()
			return true, { formspec = travelnet.formspecs.primary }
		end
	end
	return false, S("This @1 belongs to @2. You can't edit it.",
			node_info.props.description,
			tostring(node_info.props.owner_name)
		)
end
