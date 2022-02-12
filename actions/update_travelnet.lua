local S = minetest.get_translator("travelnet")

return function (node_info, fields, player)
	local pos = node_info.pos
	local meta = node_info.meta
	local player_name = player:get_player_name()

	if not pos or not fields or not meta or not player_name then
		return false, S("Invalid data or node.")
	end

	local owner_name      = node_info.props.owner_name
	local station_network = node_info.props.station_network
	local station_name	  = node_info.props.station_name
	local description     = node_info.props.description

	local new_owner_name, new_station_network, new_station_name

	if not description then
		return false, S("Unknown node.")
	end

	if owner_name == fields.owner
		and station_network == fields.station_network
		and station_name == fields.station_name
	then
		return true, { formspec = travelnet.formspecs.primary }
	end

	-- sanitize inputs
	local error_message = ''
	if travelnet.is_falsey_string(fields.station_name) then
		error_message = S('Please provide a station name.')
	end
	if travelnet.is_falsey_string(fields.station_network) then
		error_message = error_message .. ' '
			..S('Please provide a network name.')
	end
	if travelnet.is_falsey_string(fields.owner) then
		error_message = error_message .. ' '
			..S('Please provide an owner.')
	end
	if '' ~= error_message then
		return false, error_message
	end

	-- players with travelnet_remove priv can dig the station
	if not minetest.check_player_privs(player_name, { travelnet_remove = true })
		-- the function travelnet.allow_dig(..) may allow additional digging
		and not travelnet.allow_dig(player_name, owner_name, station_network, pos)
		-- the owner can remove the station
		and owner_name ~= player_name
		-- stations without owner can be removed/edited by anybody
		and owner_name ~= ""
	then
		return false, S("This %s belongs to %s. You can't edit it.",
				description,
				tostring(owner_name)
			)
	end

	-- abort if protected by another mod
	if minetest.is_protected(pos, player_name)
		and not minetest.check_player_privs(player_name, { protection_bypass = true })
	then
		minetest.record_protection_violation(pos, player_name)
		return false, S("This @1 belongs to @2. You can't edit it.",
				description,
				tostring(owner_name)
			)
	end

	local network
	local timestamp = os.time()
	if owner_name ~= fields.owner then
		-- new owner -> remove station from old network then add to new owner
		-- but only if there is space on the network
		-- get the new network
		network = travelnet.get_or_create_network(fields.owner, fields.station_network)
		-- does a station with the new name already exist?
		if network[fields.station_name] then
			return false, S('Station "@1" already exists on network "@2" of player "@3".',
					fields.station_name, fields.station_network, fields.owner)
		end
		-- does the new network have space at all?
		if travelnet.MAX_STATIONS_PER_NETWORK ~= 0 and 1 + #network > travelnet.MAX_STATIONS_PER_NETWORK then
			return false,
				S('Network "@1", already contains the maximum number (@2) of '
					.. 'allowed stations per network. Please choose a '
					.. 'different network name.', fields.station_network,
						travelnet.MAX_STATIONS_PER_NETWORK)
		end
		-- get the old network
		local old_network = travelnet.get_network(owner_name, station_network)
		if not old_network then
			print("TRAVELNET: failed to get old network when re-owning "
				.. "travelnet/elevator at pos " .. minetest.pos_to_string(pos))
			return false, S("Station does not have network.")
		end
		-- remove old station from old network
		old_network[station_name] = nil
		-- add new station to new network
		network[fields.station_name] = { pos = pos, timestamp = timestamp }
		-- update meta
		meta:set_string("station_name",    fields.station_name)
		meta:set_string("station_network", fields.station_network)
		meta:set_string("owner",           fields.owner)
		meta:set_int   ("timestamp",       timestamp)

		minetest.chat_send_player(player_name,
			S('Station "@1" has been renamed to "@2", '
				.. 'moved from network "@3" to network "@4" '
				.. 'and from owner "@5" to owner "@6".',
				station_name, fields.station_name,
				station_network, fields.station_network,
				owner_name, fields.owner))

		new_owner_name = fields.owner
		new_station_network = fields.station_network
		new_station_name = fields.station_name
	elseif station_network ~= fields.station_network then
		-- same owner but different network -> remove station from old network
		-- but only if there is space on the new network and no other station with that name
		-- get the new network
		network = travelnet.get_or_create_network(owner_name, fields.station_network)
		-- does a station with the new name already exist?
		if network[fields.station_name] then
			return false, S('Station "@1" already exists on network "@2".',
					fields.station_name, fields.station_network)
		end
		-- does the new network have space at all?
		if travelnet.MAX_STATIONS_PER_NETWORK ~= 0 and 1 + #network > travelnet.MAX_STATIONS_PER_NETWORK then
			return false,
				S('Network "@1", already contains the maximum number (@2) of '
					.. 'allowed stations per network. Please choose a '
					.. 'different network name.', fields.station_network,
						travelnet.MAX_STATIONS_PER_NETWORK)
		end
		-- get the old network
		local old_network = travelnet.get_network(owner_name, station_network)
		if not old_network then
			print("TRAVELNET: failed to get old network when re-networking "
				.. "travelnet/elevator at pos " .. minetest.pos_to_string(pos))
			return false, S("Station does not have network.")
		end
		-- remove old station from old network
		old_network[station_name] = nil
		-- add new station to new network
		network[fields.station_name] = { pos = pos, timestamp = timestamp }
		-- update meta
		meta:set_string("station_name",    fields.station_name)
		meta:set_string("station_network", fields.station_network)
		meta:set_int   ("timestamp",       timestamp)

		minetest.chat_send_player(player_name,
			S('Station "@1" has been renamed to "@2" and moved '
				.. 'from network "@3" to network "@4".',
				station_name, fields.station_name,
				station_network, fields.station_network))

		new_station_network = fields.station_network
		new_station_name = fields.station_name
	else
		-- only name changed -> change name but keep timestamp to preserve order
		network = travelnet.get_network(owner_name, station_network)
		-- does a station with the new name already exist?
		if network[fields.station_name] then
			return false, S('Station "@1" already exists on network "@2".',
					fields.station_name, station_network)
		end

		-- get the old station table
		local old_station = network[station_name]
		if not old_station then
			return false, S("Station does exist.")
		end
		-- apply the old table to the new station
		network[fields.station_name] = old_station
		-- remove old station
		network[station_name] = nil
		-- update station name in node meta
		meta:set_string("station_name", fields.station_name)

		minetest.chat_send_player(player_name,
			S('Station "@1" has been renamed to "@2" on network "@3".',
				station_name, fields.station_name, station_network))

		new_station_name = fields.station_name
	end

	meta:set_string("infotext",
			S("Station '@1'" .. " " ..
				"on travelnet '@2' (owned by @3)" .. " " ..
				"ready for usage.",
				tostring(new_station_name or station_name),
				tostring(new_station_network or station_network),
				tostring(new_owner_name or owner_name)
			))

	-- save the updated network data in a savefile over server restart
	travelnet.save_data()

	return true, { formspec = travelnet.formspecs.primary, options = {
		station_name = new_station_name or station_name,
		station_network = new_station_network or station_network,
		owner_name = new_owner_name or owner_name
	} }
end
