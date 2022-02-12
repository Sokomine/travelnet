local S = minetest.get_translator("travelnet")

local player_formspec_data = travelnet.player_formspec_data

travelnet.actions = {}

function travelnet.actions.navigate_page(node_info, fields, _)
	local page = 1
	local network = travelnet.get_network(node_info.props.owner_name, node_info.props.station_network)
	local station_count = 0
	for _ in pairs(network) do
		station_count = station_count+1
	end
	local page_size = 7*3
	local pages = math.ceil(station_count/page_size)

	if fields.last_page then
		page = pages
	else
		local current_page = tonumber(fields.page_number)
		if current_page then
			if fields.next_page then
				page = math.min(current_page+1, pages)
			elseif fields.prev_page then
				page = math.max(current_page-1, 1)
			end
		end
	end
	return true, { formspec = travelnet.formspecs.primary, options = { page_number = page } }
end

function travelnet.actions.remove_station(node_info, _, player)
	local player_name = player:get_player_name()

	-- abort if protected by another mod
	if	minetest.is_protected(node_info.pos, player_name)
		and not minetest.check_player_privs(player_name, { protection_bypass = true })
	then
		minetest.record_protection_violation(node_info.pos, player_name)
		return false,
			S("This @1 belongs to @2. You can't remove it.", node_info.props.description, node_info.props.owner_name)
	end

	-- players with travelnet_remove priv can dig the station
	if
		not minetest.check_player_privs(player_name, { travelnet_remove = true })
		-- the function travelnet.allow_dig(..) may allow additional digging
		and not travelnet.allow_dig(player_name, node_info.props.owner_name, node_info.props.station_network, node_info.pos)
		-- the owner can remove the station
		and node_info.props.owner_name ~= player_name
		-- stations without owner can be removed/edited by anybody
		and node_info.props.owner_name ~= ""
	then
		return false,
			S("This @1 belongs to @2. You can't remove it.", node_info.props.description, node_info.props.owner_name)
	end

	-- remove station
	local player_inventory = player:get_inventory()
	if not player_inventory:room_for_item("main", node_info.node.name) then
		return false, S("You do not have enough room in your inventory.")
	end

	-- give the player the box
	player_inventory:add_item("main", node_info.node.name)
	-- remove the box from the data structure
	travelnet.remove_box(node_info.pos, nil, node_info.meta:to_table(), player)
	-- remove the node as such
	minetest.remove_node(node_info.pos)

	return true
end

function travelnet.actions.edit_station(node_info, _, player)
	local player_name = player:get_player_name()
	-- abort if protected by another mod
	if minetest.is_protected(node_info.pos, player_name)
	   and not minetest.check_player_privs(player_name, { protection_bypass=true })
	then
		minetest.record_protection_violation(node_info.pos, player_name)
		return false, S("This @1 belongs to @2. You can't edit it.",
				node_info.props.description,
				tostring(node_info.props.owner_name)
			)
	end

	return true, {
		formspec = node_info.props.is_elevator
			and travelnet.formspecs.edit_elevator
			or travelnet.formspecs.edit_travelnet
	}
end

function travelnet.actions.update_station(node_info, fields, player)
	if node_info.props.is_elevator then
		return travelnet.actions.update_elevator(node_info, fields, player)
	else
		return travelnet.actions.update_travelnet(node_info, fields, player)
	end
end

function travelnet.actions.toggle_door(node_info, _, player)
	travelnet.open_close_door(node_info.pos, player, "toggle")
	return true
end

function travelnet.actions.instruct_player(_, _, player)
	minetest.chat_send_player(player:get_player_name(), S("Please click on the target you want to travel to."))
	return true
end

function travelnet.actions.end_input(_, _, player)
	player_formspec_data[player:get_player_name()] = nil
	return true
end

function travelnet.actions.return_to_form()
	return true, { formspec = travelnet.formspecs.current }
end

travelnet.actions.repair_station   = dofile(travelnet.path .. "/actions/repair_station.lua")
travelnet.actions.change_order     = dofile(travelnet.path .. "/actions/change_order.lua")
travelnet.actions.add_station      = dofile(travelnet.path .. "/actions/add_station.lua")
travelnet.actions.transport_player = dofile(travelnet.path .. "/actions/transport_player.lua")
travelnet.actions.update_elevator  = dofile(travelnet.path .. "/actions/update_elevator.lua")
travelnet.actions.update_travelnet = dofile(travelnet.path .. "/actions/update_travelnet.lua")
