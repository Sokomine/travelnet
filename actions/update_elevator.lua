local S = minetest.get_translator("travelnet")

return function (node_info, fields, player)
	local pos = node_info.pos
	local meta = node_info.meta
	local player_name = player:get_player_name()

	local owner_name      = node_info.props.owner_name
	local station_network = node_info.props.station_network
	local station_name	  = node_info.props.station_name
	local description     = node_info.props.description

	if not description then
		return false, S("Unknown node.")
	end

	if not pos or not fields or not meta or not player_name then
		return false, S("Invalid data or node.")
	end

	-- sanitize inputs
	if travelnet.is_falsey_string(fields.station_name) then
		fields.station_name = S("at @1 m", tostring(pos.y))
	end

	-- nothing changed?
	if station_name == fields.station_name then
		return true, { formspecs = "primary" }
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
				"elevator",
				tostring(owner_name)
			)
	end

	-- abort if protected by another mod
	if minetest.is_protected(pos, player_name)
		and not minetest.check_player_privs(player_name, { protection_bypass = true })
	then
		minetest.record_protection_violation(pos, player_name)
		return false, S("This %s belongs to %s. You can't edit it.",
				"elevator",
				tostring(owner_name)
			)
	end

	local network = travelnet.get_network(owner_name, station_network)
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

	meta:set_string("infotext",
			S("Station '@1'" .. " " ..
				"on travelnet '@2' (owned by @3)" .. " " ..
				"ready for usage.",
				tostring(fields.station_name), tostring(station_network), tostring(owner_name)))

	-- save the updated network data in a savefile over server restart
	travelnet.save_data()

	return true, { formspec = travelnet.formspecs.primary, options = {
		station_name = fields.station_name
	} }
end
