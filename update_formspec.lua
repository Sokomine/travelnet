local S = minetest.get_translator("travelnet")

function travelnet.primary_formspec(pos, puncher_name, _, page_number)
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
		or travelnet.is_falsey_string(station_network)
	then
		if is_elevator then
			travelnet.add_target(nil, nil, pos, puncher_name, meta, owner_name)
			return
		end
		travelnet.show_message(pos, puncher_name, "Error", S("Update failed! Resetting this box on the travelnet."))
		return
	end


	local network = travelnet.get_or_create_network(owner_name, station_network)
	-- if the station got lost from the network for some reason (savefile corrupted?) then add it again
	if not travelnet.get_station(owner_name, station_network, station_name) then

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
	local stations = travelnet.get_ordered_stations(owner_name, station_network, is_elevator)

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
				("button[%f,%f;1,0.5;open_door;<>]label[%f,%f;%s]")
						:format(x, y + 2.5, x + 0.9, y + 2.35, k)
		elseif is_elevator then
			formspec = formspec ..
				("button[%f,%f;1,0.5;target;%s]label[%f,%f;%s]")
						:format(x, y + 2.5, minetest.formspec_escape(tostring(network[k].nr)), x + 0.9, y + 2.35, k)
		else
			formspec = formspec ..
				("button[%f,%f;4,0.5;target;%s]")
						:format(x, y + 2.5, minetest.formspec_escape(k))
		end

		y = y+1
	end

	formspec = formspec .. ([[
			label[8.0,1.6;%s]
			button[11.3,0.0;1.0,0.5;station_exit;%s]
			button[10.0,0.5;2.2,0.7;station_edit;%s]
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
		if page_number < pages then
			formspec = formspec .. ("button[8,9.2;2,1;next_page;%s]"):format(minetest.formspec_escape(S(">")))
		end
		if page_number < pages-1 then
			formspec = formspec .. ("button[10,9.2;2,1;last_page;%s]"):format(minetest.formspec_escape(S(">>")))
		end
	end

	return formspec
end

function travelnet.update_formspec()
	minetest.log("warning",
		"[travelnet] the travelnet.update_formspec method is deprecated. "..
		"The formspec is now generated on each interaction.")
end
