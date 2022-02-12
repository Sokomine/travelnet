local S = minetest.get_translator("travelnet")

return function (node_info, _, player)
	local owner_name      = node_info.props.owner
	local station_name    = node_info.props.station_name
	local station_network = node_info.props.station_network

	if not owner_name
	   or not station_name
	   or travelnet.is_falsey_string(station_network)
	then
		if node_info.props.is_elevator then
			return travelnet.actions.add_station(node_info, _, player)
		end
		return false, S("Update failed! Resetting this box on the travelnet.")
	end

	-- if the station got lost from the network for some reason (savefile corrupted?) then add it again
	if not travelnet.get_station(owner_name, station_network, station_name) then
		local network = travelnet.get_or_create_network(owner_name, station_network)

		local zeit = node_info.meta:get_int("timestamp")
		if not zeit or type(zeit) ~= "number" or zeit < 100000 then
			zeit = os.time()
		end

		-- add this station
		network[station_name] = {
			pos = node_info.pos,
			timestamp = zeit
		}

		minetest.chat_send_player(owner_name,
				S("Station '@1'" .. " " ..
					"has been reattached to the network '@2'.", station_name, station_network))
		travelnet.save_data()
	end
	return true, { formspec = travelnet.formspecs.primary }
end
