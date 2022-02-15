local S = minetest.get_translator("travelnet")

local player_formspec_data = travelnet.player_formspec_data

local function validate_travelnet(pos, meta)
	local owner_name      = meta:get_string("owner")
	local station_network = meta:get_string("station_network")
	local station_name    = meta:get_string("station_name")

	-- if there is something wrong with the data
	if not owner_name or not station_network or not station_name then
		print(
			"ERROR: The travelnet at " .. minetest.pos_to_string(pos) .. " has a problem: " ..
			" DATA: owner: " .. (owner_name or "?") ..
			" station_name: " .. (station_name or "?") ..
			" station_network: " .. (station_network or "?") .. "."
		)
		return false, S("Error") .. ": " ..
				S("There is something wrong with the configuration of this station.") ..
					" DEBUG DATA: owner: " .. (owner_name or "?") ..
					" station_name: " .. (station_name or "?") ..
					" station_network: " .. (station_network or "?") .. "."
	end

	-- TODO: This check seems odd, re-think this. Don't get node twice, don't hard-code node names.
	local description = travelnet.node_description(pos)
	if not description then
		return false, "Error: Unknown node."
	end

	return true, {
		description = description,
		owner_name = owner_name,
		station_network = station_network,
		station_name = station_name
	}
end

local function decide_action(fields, props)
	-- the player wants to quit/exit the formspec; do not save/update anything
	if (fields.station_exit and fields.station_exit ~= "") or (fields.quit and fields.quit ~= "") then
		return travelnet.actions.end_input
	end

	-- back button leads back to the previous form
	if fields.back and fields.back ~= "" then
		return travelnet.actions.return_to_form
	end

	-- if paging is enabled and the player wants to change pages
	if (travelnet.MAX_STATIONS_PER_NETWORK == 0 or travelnet.MAX_STATIONS_PER_NETWORK > 24)
		and fields.page_number
		and (
			fields.next_page
			or fields.prev_page
			or fields.last_page
			or fields.first_page
		)
	then
		return travelnet.actions.navigate_page
	end

	-- the player wants to remove the station
	if fields.station_dig then
		return travelnet.actions.remove_station
	end

	-- the player wants to open the edit form
	if fields.station_edit then
		return travelnet.actions.edit_station
	end

	-- if the box has not been configured yet
	if travelnet.is_falsey_string(props.station_network) then
		return travelnet.actions.add_station
	end

	-- save pressed after editing
	if fields.station_set then
		return travelnet.actions.update_station
	end

	-- pressed the "open door" button
	if fields.open_door then
		return travelnet.actions.toggle_door
	end

	-- the owner or players with the travelnet_attach priv can move stations up or down in the list
	if fields.move_up or fields.move_down then
		return travelnet.actions.change_order
	end

	if not fields.target then
		return travelnet.actions.instruct_player
	end

	local network = travelnet.get_network(props.owner_name, props.station_network)
	if not network then
		return travelnet.actions.add_station
	end

	return travelnet.actions.transport_player
end

function travelnet.on_receive_fields(pos, _, fields, player)
	if not player then
		return
	end

	local name = player:get_player_name()
	player_formspec_data[name] = player_formspec_data[name] or {}
	if pos then
		player_formspec_data[name].pos = pos
	else
		pos = player_formspec_data[name].pos
	end

	local action_args = {
		pos = pos,
		props = {}
	}

	if not pos then
		travelnet.actions.end_input(action_args, fields or {}, player)
		travelnet.show_formspec(name, false)
		return
	end

	local node = minetest.get_node(pos)
	action_args.node = node

	local meta = minetest.get_meta(pos)
	action_args.meta = meta

	if not fields then
		travelnet.actions.end_input(action_args, {}, player)
		travelnet.show_formspec(name, false)
		return
	end

	-- Validate node's meta data
	local valid, props = validate_travelnet(pos, meta)
	props.is_elevator = travelnet.is_elevator(node.name)
	if not valid then
		minetest.chat_send_player(name, props)
		travelnet.actions.end_input(action_args, fields, player)
		travelnet.show_formspec(name, false)
		return
	end
	action_args.props = props

	-- Decide which action to run based on fields given
	local action = decide_action(fields, props)
	if not action then
		travelnet.actions.end_input(action_args, fields, player)
		travelnet.show_formspec(name, false)
		return
	end

	-- Perform the action
	local success, result = action(action_args, fields, player)

	-- Respond with a formspec
	if success then
		if result and result.formspec then
			if result.formspec ~= travelnet.formspecs.current then
				player_formspec_data[name].current_form = result.formspec
			end
			if result.options then
				for k,v in pairs(result.options) do
					props[k] = v
				end
			end
			travelnet.show_formspec(name, result.formspec(props, name))
		else
			travelnet.actions.end_input(action_args, fields, player)
			travelnet.show_formspec(name, false)
		end
	else
		travelnet.show_formspec(name, travelnet.formspecs.error_message({ message = result }))
	end
end
