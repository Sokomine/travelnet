local S = minetest.get_translator("travelnet")

local player_formspec_data = travelnet.player_formspec_data

travelnet.formspecs = {}

function travelnet.formspecs.current(options, player_name)
	local current_form = player_formspec_data[player_name] and player_formspec_data[player_name].current_form
	if current_form then
		return current_form(options, player_name)
	end
	if travelnet.is_falsey_string(options.station_network) then
		-- request initinal data
		if options.is_elevator then
			return travelnet.formspecs.edit_elevator(options, player_name)
		else
			return travelnet.formspecs.edit_travelnet(options, player_name)
		end
	else
		return travelnet.formspecs.primary(options, player_name)
	end
end

function travelnet.formspecs.error_message(options)
	if not options then options = {} end
	return ([[
			size[8,3]
			label[3,0;%s]
			textarea[0.5,0.5;7,1.5;;%s;]
			button[3.5,2.5;1.0,0.5;back;%s]
			button[6.8,2.5;1.0,0.5;station_exit;%s]
		]]):format(
			minetest.formspec_escape(options.title or S("Error")),
			minetest.formspec_escape(options.message or "- nothing -"),
			S("Back"),
			S("Exit")
		)
end

function travelnet.formspecs.edit_travelnet(options)
	if not options then options = {} end
	-- some players seem to be confused with entering network names at first; provide them
	-- with a default name
	local default_network = "net1"

	return ([[
		size[10,6.0]
		label[2.0,0.0;--> %s <--]
		button[8.0,0.0;2.2,0.7;station_dig;%s]
		field[0.3,1.2;9,0.9;station_name;%s:;%s]
		label[0.3,1.5;%s]
		field[0.3,2.8;9,0.9;station_network;%s;%s]
		label[0.3,3.1;%s]
		field[0.3,4.4;9,0.9;owner;%s;%s]
		label[0.3,4.7;%s]
		button[3.8,5.3;1.7,0.7;station_set;%s]
		button[6.3,5.3;1.7,0.7;station_exit;%s]
	]]):format(
		S("Configure this travelnet station"),
		S("Remove station"),
		S("Name of this station"),
		minetest.formspec_escape(options.station_name or ""),
		S("What do you call this place here? Example: \"my first house\", \"mine\", \"shop\"..."),
		S("Assign to network:"),
		minetest.formspec_escape(
			travelnet.is_falsey_string(options.station_network)
				and default_network
				or options.station_network
		),
		S("You can have more than one network. If unsure, use \"@1\".", default_network),
		S("Owned by:"),
		minetest.formspec_escape(options.owner_name or ""),
		S("Unless you know what you are doing, leave this empty."),
		S("Save"),
		S("Exit")
	)
end

function travelnet.formspecs.edit_elevator(options)
	if not options then options = {} end
	return ([[
		size[10,6.0]
		label[2.0,0.0;--> %s <--]
		button[8.0,0.0;2.2,0.7;station_dig;%s]
		field[0.3,1.2;9,0.9;station_name;%s:;%s]
		button[3.8,5.3;1.7,0.7;station_set;%s]
		button[6.3,5.3;1.7,0.7;station_exit;%s]
	]]):format(
		S("Configure this elevator station"),
		S("Remove station"),
		S("Name of this station"),
		minetest.formspec_escape(options.station_name),
		S("Save"),
		S("Exit")
	)
end

function travelnet.formspecs.primary(options, player_name)
	if not options then options = {} end
	-- add name of station + network + owner + update-button
	local formspec = ([[
			size[12,%s]
			label[3.3,0.0;%s:]
			label[0.3,0.4;%s]
			label[6.3,0.4;%s]
			label[0.3,0.8;%s]
			label[6.3,0.8;%s]
			label[0.3,1.2;%s]
			label[6.3,1.2;%s]
			label[3.3,1.6;%s]
			button[11.3,0.0;1.0,0.5;station_exit;%s]
		]]):format(
			tostring(options.height or 10),
			S("Travelnet-Box"),
			S("Name of this station:"),
			minetest.formspec_escape(options.station_name or "?"),
			S("Assigned to Network:"),
			minetest.formspec_escape(options.station_network or "?"),
			S("Owned by:"),
			minetest.formspec_escape(options.owner_name or "?"),
			S("Click on target to travel there:"),
			S("Exit")
		)

	local x = 0
	local y = 0
	local i = 0

	-- collect all station names in a table
	local stations = travelnet.get_ordered_stations(options.owner_name, options.station_network, options.is_elevator)

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
	local page_number = options.page_number
	if not page_number then
		page_number = 1
		if paging then
			for number,k in ipairs(stations) do
				if k == options.station_name then
					page_number = math.ceil(number/page_size)
					break
				end
			end
		end
	end

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
		if k == options.station_name then
			formspec = formspec ..
				("button[%f,%f;1,0.5;open_door;<>]label[%f,%f;%s]")
						:format(x, y + 2.5, x + 0.9, y + 2.35, k)
		elseif options.is_elevator then
			local network = travelnet.get_or_create_network(options.owner_name, options.station_network)
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

	if player_name == options.owner_name
	or minetest.check_player_privs(player_name, { travelnet_attach = true })
	then
		formspec = formspec .. ([[
				label[8.0,1.6;%s]
				button[9.6,1.6;1.4,0.5;move_up;%s]
				button[10.9,1.6;1.4,0.5;move_down;%s]
			]]):format(
				S("Position in list:"),
				S("move up"),
				S("move down")
			)
	end

	if player_name == options.owner_name
	or minetest.check_player_privs(player_name, { travelnet_remove = true })
	or travelnet.allow_dig(player_name, options.owner_name, options.station_network, player_formspec_data[player_name].pos)
	then
		formspec = formspec .. ([[
				button[10.0,0.5;2.2,0.7;station_edit;%s]
			]]):format(
				S("Edit station")
			)
	end

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
