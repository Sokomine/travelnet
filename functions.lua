local S = minetest.get_translator("travelnet")


local function string_endswith(str, ends)
	local len = #ends
	if str:sub(-len) == ends then
		return str:sub(1, -len-1)
	end
end

local function string_startswith(str, start)
	local len = #start
	if str:sub(1, len) == start then
		return str:sub(len+1)
	end
end

function travelnet.is_falsey_string(str)
	return not str or str == ""
end

function travelnet.node_description(pos)

	local node = minetest.get_node_or_nil(pos)
	if not node then return end

	local description

	if minetest.get_item_group(node.name, "travelnet") == 1 then
		description = "travelnet box"
	elseif minetest.get_item_group(node.name, "elevator") == 1 then
		description = "elevator"
	elseif node.name == "locked_travelnet:travelnet" then
		description = "locked travelnet"
	elseif node.name == "locked_travelnet:elevator" then
		description = "locked elevator"
	else
		description = nil
	end

	return description, node.name

end


function travelnet.find_nearest_elevator_network(pos, owner_name)
	local nearest_network = false
	local nearest_dist = false
	local nearest_dist_x
	local nearest_dist_z
	for target_network_name, network in pairs(travelnet.targets[owner_name]) do
		local station_name = next(network, nil)
		if station_name then
			local station = network[station_name]
			if station.nr and station.pos then
				local dist_x = station.pos.x - pos.x
				local dist_z = station.pos.z - pos.z
				local dist = math.ceil(math.sqrt(dist_x * dist_x + dist_z * dist_z))
				-- find the nearest one; store network_name and (minimal) distance
				if not nearest_dist or dist < nearest_dist then
					nearest_dist = dist
					nearest_dist_x = dist_x
					nearest_dist_z = dist_z
					nearest_network = target_network_name
				end
			end
		end
	end
	return nearest_network, {
		x = nearest_dist_x,
		z = nearest_dist_z,
	}
end

function travelnet.elevator_network(pos)
	return tostring(pos.x) .. "," .. tostring(pos.z)
end

function travelnet.is_elevator(node_name)
	return node_name == "travelnet:elevator"
end

function travelnet.is_travelnet_or_elevator(pos)
	local node = minetest.get_node(pos)
	local node_def = minetest.registered_nodes[node.name]
	return node_def and node_def.groups and (node_def.groups.travelnet or node_def.groups.elevator)
end

function travelnet.door_is_open(node, opposite_direction)
	return string.sub(node.name, -5) == "_open"
		-- handle doors that change their facedir
		or (
			node.param2 ~= opposite_direction
			and not (
				string_startswith(node.name, "travelnet:elevator_door")
				and string_endswith(node.name, "_closed")
			)
		)
end

function travelnet.door_is_closed(node, opposite_direction)
	return string.sub(node.name, -7) == "_closed"
		-- handle doors that change their facedir
		or (
			node.param2 == opposite_direction
			and not (
				string_startswith(node.name, "travelnet:elevator_door")
				and string_endswith(node.name, "_open")
			)
		)
end

function travelnet.param2_to_yaw(param2)
	if     param2 == 0 then
		return 180
	elseif param2 == 1 then
		return 90
	elseif param2 == 2 then
		return 0
	elseif param2 == 3 then
		return 270
	end
end

function travelnet.get_or_create_network(owner_name, network_name)
	if not travelnet.targets then
		travelnet.targets = {}
	end

	-- first one by this player?
	if not travelnet.targets[owner_name] then
		travelnet.targets[owner_name] = {}
	end

	local owners_targets = travelnet.targets[owner_name]

	-- first station on this network?
	if not owners_targets[network_name] then
		owners_targets[network_name] = {}
	end

	return owners_targets[network_name]
end

function travelnet.get_network(owner_name, network_name)
	if not travelnet.targets then return end

	local owners_targets = travelnet.targets[owner_name]
	if not owners_targets then return end

	return travelnet.targets[owner_name][network_name]
end

function travelnet.get_station(owner_name, station_network, station_name)

	local network = travelnet.get_network(owner_name, station_network)
	if not network then return end

	return network[station_name]
end

-- punching the travelnet updates its formspec and shows it to the player;
-- however, that would be very annoying when actually trying to dig the thing.
-- Thus, check if the player is wielding a tool that can dig nodes of the
-- group cracky
function travelnet.check_if_trying_to_dig(puncher)
	-- if in doubt: show formspec
	if not puncher or not puncher:get_wielded_item() then
		return false
	end
	-- show menu when in creative mode
	if creative and creative.is_enabled_for(puncher:get_player_name()) then
		return false
	end
	local tool_capabilities = puncher:get_wielded_item():get_tool_capabilities()
	if not tool_capabilities or not tool_capabilities["groupcaps"] or not tool_capabilities["groupcaps"]["cracky"] then
		return false
	end
	-- tools which can dig cracky items can start digging immediately
	return true
end


-- allow doors to open
function travelnet.open_close_door(pos, player, mode)
	local this_node = minetest.get_node_or_nil(pos)
	-- give up if the area is *still* not loaded
	if not this_node then
		return
	end

	local opposite_direction = (this_node.param2 + 2) % 4
	local door_pos = vector.add(pos, minetest.facedir_to_dir(opposite_direction))

	local door_node = minetest.get_node_or_nil(door_pos)

	if not door_node or door_node.name == "ignore" or door_node.name == "air"
			or not minetest.registered_nodes[door_node.name] then
		return
	end

	local right_click_action = minetest.registered_nodes[door_node.name].on_rightclick
	if not right_click_action then return end

	-- Map to old API in case anyone is using it externally
	if     mode == 0 then mode = "toggle"
	elseif mode == 1 then mode = "close"
	elseif mode == 2 then mode = "open"
	end

	-- at least for homedecor, same facedir would mean "door closed"
	-- do not close the elevator door if it is already closed
	if mode == "close" and travelnet.door_is_closed(door_node, opposite_direction) then
		return
	end

	-- do not open the doors if they are already open (works only on elevator-doors; not on doors in general)
	if mode == "open" and travelnet.door_is_open(door_node, opposite_direction) then
		return
	end

	if mode == "open" then
		local playername = player:get_player_name()
		minetest.after(1, function()
			-- Get the player again in case it doesn't exist anymore (logged out)
			local pplayer = minetest.get_player_by_name(playername)
			if pplayer then
				right_click_action(door_pos, door_node, pplayer)
			end
		end)
	else
		right_click_action(door_pos, door_node, player)
	end
end

travelnet.rotate_player = function(target_pos, player)
	local target_node = minetest.get_node_or_nil(target_pos)
	if target_node == nil then return end

	-- play sound at the target position as well
	if travelnet.travelnet_sound_enabled then
		local sound = "travelnet_travel"
		if travelnet.is_elevator(target_node.name) then
			sound = "travelnet_bell"
		end

		minetest.sound_play(sound, {
			pos = target_pos,
			gain = 0.75,
			max_hear_distance = 10
		})
	end

	-- do this only on servers where the function exists
	if player.set_look_horizontal then
		-- rotate the player so that they can walk straight out of the box
		local yaw = travelnet.param2_to_yaw(target_node.param2) or 0

		player:set_look_horizontal(math.rad(yaw))
		player:set_look_vertical(math.rad(0))
	end

	travelnet.open_close_door(target_pos, player, "open")
end


travelnet.remove_box = function(_, _, oldmetadata, digger)
	if not oldmetadata or oldmetadata == "nil" or not oldmetadata.fields then
		minetest.chat_send_player(digger:get_player_name(), S("Error") .. ": " ..
				S("Could not find information about the station that is to be removed."))
		return
	end

	local owner_name      = oldmetadata.fields["owner"]
	local station_name    = oldmetadata.fields["station_name"]
	local station_network = oldmetadata.fields["station_network"]

	-- station is not known? then just remove it
	if	not (owner_name and station_network and station_name)
		or not travelnet.get_station(owner_name, station_network, station_name)
	then
		minetest.chat_send_player(digger:get_player_name(), S("Error") .. ": " ..
				S("Could not find the station that is to be removed."))
		return
	end

	travelnet.targets[owner_name][station_network][station_name] = nil

	-- inform the owner
	minetest.chat_send_player(owner_name,
			S("Station '@1'" .. " " ..
				"has been REMOVED from the network '@2'.", station_name, station_network))

	if digger and owner_name ~= digger:get_player_name() then
		minetest.chat_send_player(digger:get_player_name(),
				S("Station '@1'" .. " " ..
					"has been REMOVED from the network '@2'.", station_name, station_network))
	end

	-- save the updated network data in a savefile over server restart
	travelnet.save_data()
end


-- privs of player are already checked by on_receive_fields before sending
-- the edit form, but we need to check again in case somebody is cheating
function travelnet.edit_box(pos, fields, meta, player_name)
	if not pos or not fields or not meta or not player_name then return end

	local owner_name	  = meta:get_string("owner")
	local station_network = meta:get_string("station_network")
	local station_name	= meta:get_string("station_name")
	local description, node_name  = travelnet.node_description(pos)

	if not description then
		minetest.chat_send_player(player_name, "Error: Unknown node.")
		return
	end

	if travelnet.is_elevator(node_name) then
		return travelnet.edit_elevator(pos, fields, meta, player_name)
	end

	if owner_name == fields.owner
		and station_network == fields.station_network
		and station_name == fields.station_name
	then
		return
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
		minetest.chat_send_player(player_name, error_message)
		return
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
		minetest.chat_send_player(player_name,
			S("This %s belongs to %s. You can't remove or edit it."):format(
				description,
				tostring(owner_name)
			)
		)
		return
	end

	-- abort if protected by another mod
	if minetest.is_protected(pos, player_name)
		and not minetest.check_player_privs(player_name, { protection_bypass = true })
	then
		minetest.record_protection_violation(pos, player_name)
		return
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
			minetest.chat_send_player(player_name,
				S('Station "@1" already exists on network "@2" of player "@3".',
					fields.station_name, fields.station_network, fields.owner))
			return
		end
		-- does the new network have space at all?
		if travelnet.MAX_STATIONS_PER_NETWORK ~= 0 and 1 + #network > travelnet.MAX_STATIONS_PER_NETWORK then
			travelnet.show_message(pos, player_name, S("Error"),
				S('Network "@1", already contains the maximum number (@2) of '
					.. 'allowed stations per network. Please choose a '
					.. 'different network name.', fields.station_network,
						travelnet.MAX_STATIONS_PER_NETWORK))
			return
		end
		-- get the old network
		local old_network = travelnet.get_network(owner_name, station_network)
		if not old_network then
			print("TRAVELNET: failed to get old network when re-owning "
				.. "travelnet/elevator at pos " .. minetest.pos_to_string(pos))
			return
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
	elseif station_network ~= fields.station_network then
		-- same owner but different network -> remove station from old network
		-- but only if there is space on the new network and no other station with that name
		-- get the new network
		network = travelnet.get_or_create_network(owner_name, fields.station_network)
		-- does a station with the new name already exist?
		if network[fields.station_name] then
			minetest.chat_send_player(player_name,
				S('Station "@1" already exists on network "@2".',
					fields.station_name, fields.station_network))
			return
		end
		-- does the new network have space at all?
		if travelnet.MAX_STATIONS_PER_NETWORK ~= 0 and 1 + #network > travelnet.MAX_STATIONS_PER_NETWORK then
			travelnet.show_message(pos, player_name, S("Error"),
				S('Network "@1", already contains the maximum number (@2) of '
					.. 'allowed stations per network. Please choose a '
					.. 'different network name.', fields.station_network,
						travelnet.MAX_STATIONS_PER_NETWORK))
			return
		end
		-- get the old network
		local old_network = travelnet.get_network(owner_name, station_network)
		if not old_network then
			print("TRAVELNET: failed to get old network when re-networking "
				.. "travelnet/elevator at pos " .. minetest.pos_to_string(pos))
			return
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
	else
		-- only name changed -> change name but keep timestamp to preserve order
		network = travelnet.get_network(owner_name, station_network)
		-- does a station with the new name already exist?
		if network[fields.station_name] then
			minetest.chat_send_player(player_name,
				S('Station "@1" already exists on network "@2".',
					fields.station_name, station_network))
			return
		end

		-- get the old station table
		local old_station = network[station_name]
		if not old_station then return end
		-- apply the old table to the new station
		network[fields.station_name] = old_station
		-- remove old station
		network[station_name] = nil
		-- update station name in node meta
		meta:set_string("station_name", fields.station_name)

		minetest.chat_send_player(player_name,
			S('Station "@1" has been renamed to "@2" on network "@3".',
				station_name, fields.station_name, station_network))
	end

	meta:set_string("formspec",
		([[
			size[12,10]
			field[0.3,0.6;6,0.7;station_name;%s;%s]
			field[0.3,3.6;6,0.7;station_network;%s;%s]
		]]):format(
			S("Station:"),
			minetest.formspec_escape(fields.station_name),
			S("Network:"),
			minetest.formspec_escape(fields.network_name)
	))

	-- update the formspec of this station
	travelnet.update_formspec(pos, player_name, nil)

	-- save the updated network data in a savefile over server restart
	travelnet.save_data()
end


function travelnet.edit_elevator(pos, fields, meta, player_name)
	if not pos or not fields or not meta or not player_name then return end

	local owner_name	  = meta:get_string("owner")
	local station_network = meta:get_string("station_network")
	local station_name	= meta:get_string("station_name")

	-- sanitize inputs
	if travelnet.is_falsey_string(fields.station_name) then
		fields.station_name = S("at @1 m", tostring(pos.y))
	end

	-- nothing changed?
	if station_name == fields.station_name then
		return
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
		minetest.chat_send_player(player_name,
			S("This %s belongs to %s. You can't remove or edit it."):format(
				"elevator",
				tostring(owner_name)
			)
		)
		return
	end

	-- abort if protected by another mod
	if minetest.is_protected(pos, player_name)
		and not minetest.check_player_privs(player_name, { protection_bypass = true })
	then
		minetest.record_protection_violation(pos, player_name)
		return
	end

	local network = travelnet.get_network(owner_name, station_network)
	-- does a station with the new name already exist?
	if network[fields.station_name] then
		minetest.chat_send_player(player_name,
			S('Station "@1" already exists on network "@2".',
				fields.station_name, station_network))
		return
	end

	-- get the old station table
	local old_station = network[station_name]
	if not old_station then return end
	-- apply the old table to the new station
	network[fields.station_name] = old_station
	-- remove old station
	network[station_name] = nil
	-- update station name in node meta
	meta:set_string("station_name", fields.station_name)

	minetest.chat_send_player(player_name,
		S('Station "@1" has been renamed to "@2" on network "@3".',
			station_name, fields.station_name, station_network))

	meta:set_string("formspec",
		([[
			size[12,10]
			field[0.3,0.6;6,0.7;station_name;%s;%s]
			field[0.3,3.6;6,0.7;station_network;%s;%s]
		]]):format(
			S("Station:"),
			minetest.formspec_escape(fields.station_name),
			S("Network:"),
			minetest.formspec_escape(fields.network_name)
	))

	-- update the formspec of this station
	travelnet.update_formspec(pos, player_name, nil)

	-- save the updated network data in a savefile over server restart
	travelnet.save_data()
end


travelnet.can_dig = function()
	-- forbid digging of the travelnet
	return false
end
