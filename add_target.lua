local S = minetest.get_translator("travelnet")


local function is_falsey_string(str)
	return not str or str == ""
end

-- add a new target; meta is optional
function travelnet.add_target(station_name, network_name, pos, player_name, meta, owner_name)

	if not player_name then return end -- this should never happen, but just in case

	if not minetest.check_player_privs(player_name, { interact=true }) then
		travelnet.show_message(pos, player_name, S("Error"),
				S("There is no player with interact privilege named '@1'. Aborting.", player_name))
		return
	end

	-- if it is an elevator, determine the network name through x and z coordinates
	local this_node   = minetest.get_node(pos)
	local is_elevator = travelnet.is_elevator(this_node.name)

	if is_elevator then
		network_name = travelnet.elevator_network(pos)
		if is_falsey_string(station_name) then
			station_name = S("at @1 m", tostring(pos.y))
		end
	end

	if is_falsey_string(station_name) then
		travelnet.show_message(pos, player_name, S("Error"), S("Please provide a name for this station."))
		return
	end

	if is_falsey_string(network_name) then
		travelnet.show_message(pos, player_name, S("Error"),
				S("Please provide the name of the network this station ought to be connected to."))
		return
	end

	if is_falsey_string(owner_name) or owner_name == player_name or is_elevator then -- elevator networks
		owner_name = player_name
	elseif	not minetest.check_player_privs(player_name, { travelnet_attach=true })
		and not travelnet.allow_attach(player_name, owner_name, network_name)
	then
		travelnet.show_message(pos, player_name, S("Error"),
				S("You do not have the travelnet_attach priv which is required to attach your box to " ..
					"the network of someone else. Aborting."))
		return
	end

	local network = travelnet.get_or_create_network(owner_name, network_name)

	-- lua doesn't allow efficient counting here
	local station_count = 1  -- start at one, assume the station about to be created already exists
	for existing_station_name in pairs(network) do
		if existing_station_name == station_name then
			travelnet.show_message(pos, player_name, S("Error"),
					S("A station named '@1' already exists on this network. Please choose a different name!", station_name))
			return
		end
		station_count = station_count+1
	end

	-- we don't want too many stations in the same network because that would get confusing when displaying the targets
	if station_count > travelnet.MAX_STATIONS_PER_NETWORK then
		travelnet.show_message(pos, player_name, S("Error"),
				S("Network '@1', already contains the maximum number (@2) of allowed stations per network. " ..
					"Please choose a different/new network name.", network_name, travelnet.MAX_STATIONS_PER_NETWORK))
		return
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
					", which now consists of @3 station(s).", station_name, network_name, station_count))

		meta:set_string("station_name",    station_name)
		meta:set_string("station_network", network_name)
		meta:set_string("owner",           owner_name)
		meta:set_int   ("timestamp",       creation_timestamp)

		meta:set_string("formspec",
				([[
					size[12,10]
					field[0.3,0.6;6,0.7;station_name;%s;%s]
					field[0.3,3.6;6,0.7;station_network;%s;%s]
				]]):format(
					S("Station:"),
					minetest.formspec_escape(station_name),
					S("Network:"),
					minetest.formspec_escape(network_name)
				))

		-- display a list of all stations that can be reached from here
		travelnet.update_formspec(pos, player_name, nil)

		-- save the updated network data in a savefile over server restart
		travelnet.save_data()
	end
end
