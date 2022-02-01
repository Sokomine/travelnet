local S = minetest.get_translator("travelnet")

local function is_falsey_string(str)
	return not str or str == ""
end


function travelnet.primary_formspec(pos, puncher_name, fields, page_number)

	local meta = minetest.get_meta(pos)

	local node = minetest.get_node(pos)
	local is_elevator = travelnet.is_elevator(node.name)

	if not meta then
		return
	end

	local owner_name      = meta:get_string("owner")
	local station_name    = meta:get_string("station_name")
	local station_network = meta:get_string("station_network")

	if	   not owner_name
		or not station_name
		or is_falsey_string(station_network)
	then
		if is_elevator then
			travelnet.add_target(nil, nil, pos, puncher_name, meta, owner_name)
			return
		end

		travelnet.reset_formspec(meta)
		travelnet.show_message(pos, puncher_name, "Error", S("Update failed! Resetting this box on the travelnet."))
		return
	end

	-- if the station got lost from the network for some reason (savefile corrupted?) then add it again
	if not travelnet.get_station(owner_name, station_network, station_name) then

		local network = travelnet.get_or_create_network(owner_name, station_network)

		local zeit = meta:get_int("timestamp")
		if not zeit or type(zeit) ~= "number" or zeit < 100000 then
			zeit = os.time()
		end

		-- add this station
		network[station_name] = {
			pos = pos,
			timestamp = zeit
		}

		minetest.chat_send_player(owner_name,
				S("Station '@1'" .. " " ..
					"has been reattached to the network '@2'.", station_name, station_network))
		travelnet.save_data()
	end


	-- add name of station + network + owner + update-button

	local formspec = ([[
			size[12,10]
			label[3.3,0.0;%s:]
			label[6.3,0.0;%s]
			label[0.3,0.4;%s]
			label[6.3,0.4;%s]
			label[0.3,0.8;%s]
			label[6.3,0.8;%s]
			label[0.3,1.2;%s]
			label[6.3,1.2;%s]
			label[3.3,1.6;%s]
		]]):format(
			S("Travelnet-Box"),
			S("Punch box to update target list."),
			S("Name of this station:"),
			minetest.formspec_escape(station_name or "?"),
			S("Assigned to Network:"),
			minetest.formspec_escape(station_network or "?"),
			S("Owned by:"),
			minetest.formspec_escape(owner_name or "?"),
			S("Click on target to travel there:")
		)

	local x = 0
	local y = 0
	local i = 0

	-- collect all station names in a table
	local stations = {}
	local network = travelnet.targets[owner_name][station_network]

	for k in pairs(network) do
		table.insert(stations, k)
	end

	local ground_level = 1
	if is_elevator then
		table.sort(stations, function(a, b)
			return network[a].pos.y > network[b].pos.y
		end)

		-- find ground level
		local vgl_timestamp = 999999999999
		for index,k in ipairs(stations) do
			local station = network[k]
			if not station.timestamp then
				station.timestamp = os.time()
			end
			if station.timestamp < vgl_timestamp then
				vgl_timestamp = station.timestamp
				ground_level  = index
			end
		end

		for index,k in ipairs(stations) do
			local station = network[k]
			if index == ground_level then
				station.nr = "G"
			else
				station.nr = tostring(ground_level - index)
			end
		end
	else
		-- sort the table according to the timestamp (=time the station was configured)
		table.sort(stations, function(a, b)
			return network[a].timestamp < network[b].timestamp
		end)
	end

	-- does the player want to move this station one position up in the list?
	-- only the owner and players with the travelnet_attach priv can change the order of the list
	-- Note: With elevators, only the "G"(round) marking is actually moved
	if	    fields and (fields.move_up or fields.move_down)
		and not is_falsey_string(owner_name)
		and (
			   (owner_name == puncher_name)
			or (minetest.check_player_privs(puncher_name, { travelnet_attach=true }))
		)
	then

		local current_pos = -1
		for index, k in ipairs(stations) do
			if k == station_name then
				current_pos = index
				-- break??
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
			travelnet.show_message(pos, puncher_name, "Info", S("This station is already the first one on the list."))
			return
		elseif swap_with_pos > #stations then
			travelnet.show_message(pos, puncher_name, "Info", S("This station is already the last one on the list."))
			return
		else
			local current_station = stations[current_pos]
			local swap_with_station = stations[swap_with_pos]

			-- swap the actual data by which the stations are sorted
			local old_timestamp = network[swap_with_station].timestamp
			network[swap_with_station].timestamp = network[current_station].timestamp
			network[current_station].timestamp = old_timestamp

			-- for elevators, only the "G"(round) marking is moved; no point in swapping stations
			if not is_elevator then
				-- actually swap the stations
				stations[swap_with_pos] = current_station
				stations[current_pos]   = swap_with_station
			end

			-- store the changed order
			travelnet.save_data()
		end
	end

	-- if there are only 8 stations (plus this one), center them in the formspec
	if #stations < 10 then
		x = 4
	end
	local paging = (
			travelnet.MAX_STATIONS_PER_NETWORK == 0
			or travelnet.MAX_STATIONS_PER_NETWORK > 24
		) and (#stations > 24)

	local column_size = paging and 7 or 8
	local page_size = column_size*3
	local pages = math.ceil(#stations/page_size)
	if not page_number then
		page_number = 1
		if paging then
			for number,k in ipairs(stations) do
				if k == station_name then
					page_number = math.ceil(number/page_size)
					break
				end
			end
		end
	end

	-- for number,k in ipairs(stations) do
	for n=((page_number-1)*page_size)+1,(page_number*page_size) do
		local k = stations[n]
		if not k then break end
		i = i+1

		-- new column
		if y == column_size then
			x = x + 4
			y = 0
		end

		-- check if there is an elevator door in front that needs to be opened
		if k == station_name then
			formspec = formspec ..
				("button_exit[%f,%f;1,0.5;open_door;<>]label[%f,%f;%s]")
						:format(x, y + 2.5, x + 0.9, y + 2.35, k)
		elseif is_elevator then
			formspec = formspec ..
				("button_exit[%f,%f;1,0.5;target;%s]label[%f,%f;%s]")
						:format(x, y + 2.5, minetest.formspec_escape(tostring(network[k].nr)), x + 0.9, y + 2.35, k)
		else
			formspec = formspec ..
				("button_exit[%f,%f;4,0.5;target;%s]")
						:format(x, y + 2.5, minetest.formspec_escape(k))
		end

		y = y+1
	end

	formspec = formspec .. ([[
			label[8.0,1.6;%s]
			button_exit[11.3,0.0;1.0,0.5;station_exit;%s]
			button_exit[10.0,0.5;2.2,0.7;station_edit;%s]
			button[9.6,1.6;1.4,0.5;move_up;%s]
			button[10.9,1.6;1.4,0.5;move_down;%s]
		]]):format(
			S("Position in list:"),
			S("Exit"),
			S("Edit station"),
			S("move up"),
			S("move down")
		)
	if paging then
		if page_number > 2 then
			formspec = formspec .. ("button[0,9.2;2,1;first_page;%s]"):format(minetest.formspec_escape(S("<<")))
		end
		if page_number > 1 then
			formspec = formspec .. ("button[2,9.2;2,1;prev_page;%s]"):format(minetest.formspec_escape(S("<")))
		end
		formspec = formspec
			.. ("label[5,9.4;%s]"):format(minetest.formspec_escape(S("Page @1/@2", page_number, pages)))
			.. ("field[20,20;0.1,0.1;page_number;Page;%i]"):format(page_number)
			.. ("field[20,20;0.1,0.1;pos2str;Pos;%s]"):format(minetest.pos_to_string(pos))
		if page_number < pages then
			formspec = formspec .. ("button[8,9.2;2,1;next_page;%s]"):format(minetest.formspec_escape(S(">")))
		end
		if page_number < pages-1 then
			formspec = formspec .. ("button[10,9.2;2,1;last_page;%s]"):format(minetest.formspec_escape(S(">>")))
		end
	end

	return formspec
end

-- called "on_punch" of travelnet and elevator
function travelnet.update_formspec(pos, puncher_name, fields)

	local formspec = travelnet.primary_formspec(pos, puncher_name, fields)

	if not formspec then return end

	local meta = minetest.get_meta(pos)

	meta:set_string("formspec", formspec)

	local owner_name      = meta:get_string("owner")
	local station_name    = meta:get_string("station_name")
	local station_network = meta:get_string("station_network")

	meta:set_string("infotext",
			S("Station '@1'" .. " " ..
				"on travelnet '@2' (owned by @3)" .. " " ..
				"ready for usage. Right-click to travel, punch to update.",
				tostring(station_name), tostring(station_network), tostring(owner_name)))

	-- show the player the updated formspec
	travelnet.show_current_formspec(pos, meta, puncher_name)
end
