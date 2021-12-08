local S = minetest.get_translator("travelnet")


function travelnet.on_receive_fields(pos, _, fields, player)
	if not pos then
		return
	end

	local meta = minetest.get_meta(pos)
	local name = player:get_player_name()

	-- the player wants to quit/exit the formspec; do not save/update anything
	if fields and fields.station_exit and fields.station_exit ~= "" then
		return
	end

	local owner_name      = meta:get_string("owner")
	local station_network = meta:get_string("station_network")
	local station_name    = meta:get_string("station_name")

	-- if there is something wrong with the data
	if not owner_name or not station_network or not station_name then
		minetest.chat_send_player(name, S("Error") .. ": " ..
				S("There is something wrong with the configuration of this station.") ..
					" DEBUG DATA: owner: " .. (owner_name or "?") ..
					" station_name: " .. (station_name or "?") ..
					" station_network: " .. (station_network or "?") .. "."
		)
		print(
			"ERROR: The travelnet at " .. minetest.pos_to_string(pos) .. " has a problem: " ..
			" DATA: owner: " .. (owner_name or "?") ..
			" station_name: " .. (station_name or "?") ..
			" station_network: " .. (station_network or "?") .. "."
		)
		return
	end

	local node = minetest.get_node(pos)

	-- the player wants to remove the station
	if fields.station_dig or fields.station_edit then
		local description

		if node and minetest.get_item_group(node.name, "travelnet") == 1 then
			description = "travelnet box"
		elseif node and minetest.get_item_group(node.name, "elevator") == 1 then
			description = "elevator"
		elseif node and node.name == "locked_travelnet:travelnet" then
			description = "locked travelnet"
		elseif node and node.name == "locked_travelnet:elevator" then
			description = "locked elevator"
		else
			minetest.chat_send_player(name, "Error: Unknown node.")
			return
		end

		-- players with travelnet_remove priv can dig the station
		if	    not minetest.check_player_privs(name, { travelnet_remove=true })
			-- the function travelnet.allow_dig(..) may allow additional digging
			and not travelnet.allow_dig(name, owner_name, station_network, pos)
			-- the owner can remove the station
			and owner_name ~= name
			-- stations without owner can be removed by anybody
			and owner_name ~= ""
		then
			minetest.chat_send_player(name,
				S("This %s belongs to %s. You can't remove or edit it."):format(
					description,
					tostring(owner_name)
				)
			)
			return
		end

		-- abort if protected by another mod
		if	minetest.is_protected(pos, name)
			and not minetest.check_player_privs(name, { protection_bypass=true })
		then
			minetest.record_protection_violation(pos, name)
			return
		end

		if fields.station_dig then
			-- remove station
			local player_inventory = player:get_inventory()
			if not player_inventory:room_for_item("main", node.name) then
				minetest.chat_send_player(name, S("You do not have enough room in your inventory."))
				return
			end

			-- give the player the box
			player_inventory:add_item("main", node.name)
			-- remove the box from the data structure
			travelnet.remove_box(pos, nil, meta:to_table(), player)
			-- remove the node as such
			minetest.remove_node(pos)
		else
			-- edit station
			travelnet.edit_formspec(pos, meta, name)
		end
		return
	end


	-- if the box has not been configured yet
	if station_network == "" then
		travelnet.add_target(fields.station_name, fields.station_network, pos, name, meta, fields.owner)
		return
	end

	if fields.open_door then
		travelnet.open_close_door(pos, player, "toggle")
		return
	end

	-- the owner or players with the travelnet_attach priv can move stations up or down in the list
	if fields.move_up or fields.move_down then
		travelnet.update_formspec(pos, name, fields)
		return
	end

	if not fields.target then
		minetest.chat_send_player(name, S("Please click on the target you want to travel to."))
		return
	end

	local network = travelnet.get_network(owner_name, station_network)

	if not network then
		travelnet.add_target(station_name, station_network, pos, owner_name, meta, owner_name)
		return
	end

	if node ~= nil and travelnet.is_elevator(node.name) then
		for k,_ in pairs(network) do
			if network[k].nr == fields.target then
				fields.target = k
				-- break ??
			end
		end
	end

	local target_station = network[fields.target]

	-- if the target station is gone
	if not target_station then
		minetest.chat_send_player(name,
				S("Station '@1' does not exist (anymore?)" ..
					" " .. "on this network.", fields.target or "?")
		)
		travelnet.update_formspec(pos, name, nil)
		return
	end


	if not travelnet.allow_travel(name, owner_name, station_network, station_name, fields.target) then
		return
	end
	minetest.chat_send_player(name, S("Initiating transfer to station '@1'.", fields.target or "?"))

	if travelnet.travelnet_sound_enabled then
		if travelnet.is_elevator(node.name) then
			minetest.sound_play("travelnet_bell", {
				pos = pos,
				gain = 0.75,
				max_hear_distance = 10
			})
		else
			minetest.sound_play("travelnet_travel", {
				pos = pos,
				gain = 0.75,
				max_hear_distance = 10
			})
		end
	end

	if travelnet.travelnet_effect_enabled then
		minetest.add_entity(vector.add(pos, { x=0, y=0.5, z=0 }), "travelnet:effect")  -- it self-destructs after 20 turns
	end

	-- close the doors at the sending station
	travelnet.open_close_door(pos, player, "close")

	-- transport the player to the target location

	-- may be 0.0 for some versions of MT 5 player model
	local player_model_bottom = tonumber(minetest.settings:get("player_model_bottom")) or -.5
	local player_model_vec = vector.new(0, player_model_bottom, 0)
	local target_pos = target_station.pos

	local top_pos = vector.add(pos, { x=0, y=1, z=0 })
	local top_node = minetest.get_node(top_pos)
	if top_node.name ~= "travelnet:hidden_top" then
		local def = minetest.registered_nodes[top_node.name]
		if def and def.buildable_to then
			minetest.set_node(top_pos, { name="travelnet:hidden_top" })
		end
	end

	player:move_to(vector.add(target_pos, player_model_vec), false)

	-- check if the box has at the other end has been removed.
	local target_node = minetest.get_node_or_nil(target_pos)
	if target_node ~= nil then
		local target_node_def = minetest.registered_nodes[target_node.name]
		local has_travelnet_group = target_node_def.groups.travelnet or target_node_def.groups.elevator

		if not has_travelnet_group then
			-- provide information necessary to identify the removed box
			local oldmetadata = {
				fields = {
					owner           = owner_name,
					station_name    = fields.target,
					station_network = station_network
				}
			}

			travelnet.remove_box(target_pos, nil, oldmetadata, player)
			-- send the player back as there's no receiving travelnet
			player:move_to(pos, false)
		else
			travelnet.rotate_player(target_pos, player, 0)
		end
	end
end

