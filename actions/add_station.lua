local S = minetest.get_translator("travelnet")

return function (node_info, fields, player)

	local player_name = player:get_player_name()

	if not player_name then
		return false, S("The give player is not a player")
	end -- this should never happen, but just in case

	if not minetest.check_player_privs(player_name, { interact=true }) then
		return false, S("There is no player with interact privilege named '@1'. Aborting.", player_name)
	end

	local pos = node_info.pos
	local meta = node_info.meta
	local station_name = fields.station_name or node_info.props.station_name
	local station_network = fields.station_network or node_info.props.station_network
	local owner_name = fields.owner_name or node_info.props.owner_name

	-- if it is an elevator, determine the network name through x and z coordinates
	local is_elevator = node_info.props.is_elevator

	if is_elevator then
		station_network = travelnet.elevator_network(pos)
		if travelnet.is_falsey_string(station_name) then
			station_name = S("at @1 m", tostring(pos.y))
		end
	end

	if travelnet.is_falsey_string(station_name) then
		return false, S("Please provide a name for this station.")
	end

	if travelnet.is_falsey_string(station_network) then
		return false, S("Please provide the name of the network this station ought to be connected to.")
	end

	if travelnet.is_falsey_string(owner_name) or owner_name == player_name or is_elevator then -- elevator networks
		owner_name = player_name
	elseif	not minetest.check_player_privs(player_name, { travelnet_attach=true })
		and not travelnet.allow_attach(player_name, owner_name, station_network)
	then
		return false, S("You do not have the travelnet_attach priv which is required to attach your box to " ..
			"the network of someone else. Aborting.")
	end

	local network = travelnet.get_or_create_network(owner_name, station_network)

	-- lua doesn't allow efficient counting here
	local station_count = 1  -- start at one, assume the station about to be created already exists
	for existing_station_name in pairs(network) do
		if existing_station_name == station_name then
			return false, S("A station named '@1' already exists on this network. Please choose a different name!", station_name)
		end
		station_count = station_count+1
	end

	-- we don't want too many stations in the same network because that would get confusing when displaying the targets
	if travelnet.MAX_STATIONS_PER_NETWORK ~= 0 and station_count > travelnet.MAX_STATIONS_PER_NETWORK then
		return false, S("Network '@1', already contains the maximum number (@2) of allowed stations per network. " ..
			"Please choose a different/new network name.", station_network, travelnet.MAX_STATIONS_PER_NETWORK)
	end

	-- add this station
	local creation_timestamp = os.time()
	network[station_name] = {
		pos = pos,
		timestamp = creation_timestamp
	}

	-- do we have a new node to set up? (and are not just reading from a safefile?)
	if meta then
		minetest.chat_send_player(player_name,
				S("Station '@1'" .. " " ..
					"has been added to the network '@2'" ..
					", which now consists of @3 station(s).", station_name, station_network, station_count))

		meta:set_string("station_name",    station_name)
		meta:set_string("station_network", station_network)
		meta:set_string("owner",           owner_name)
		meta:set_int   ("timestamp",       creation_timestamp)

		meta:set_string("infotext",
				S("Station '@1'" .. " " ..
					"on travelnet '@2' (owned by @3)" .. " " ..
					"ready for usage.",
					tostring(station_name), tostring(station_network), tostring(owner_name)))

		-- save the updated network data in a savefile over server restart
		travelnet.save_data()

		return true, { formspec = travelnet.formspecs.primary, options = {
			station_name = station_name,
			station_network = station_network,
			owner_name = owner_name
		} }
	end
end
