local S = minetest.get_translator("travelnet")

-- called "on_punch" of travelnet and elevator
travelnet.update_formspec = function( pos, puncher_name, fields )
	local meta = minetest.get_meta(pos);

	local this_node   = minetest.get_node( pos );
	local is_elevator = false;

	if this_node ~= nil and this_node.name == 'travelnet:elevator' then
		is_elevator = true;
	end

	if not meta then
		return;
	end

	local owner_name      = meta:get_string( "owner" );
	local station_name    = meta:get_string( "station_name" );
	local station_network = meta:get_string( "station_network" );

	if(  not( owner_name )
		or not( station_name ) or station_network == ''
		or not( station_network )) then

		if is_elevator then
			travelnet.add_target( nil, nil, pos, puncher_name, meta, owner_name );
			return;
		end

		travelnet.reset_formspec( meta );
		travelnet.show_message( pos, puncher_name, "Error", S("Update failed! Resetting this box on the travelnet."));
		return;
	end

	-- if the station got lost from the network for some reason (savefile corrupted?) then add it again
	if(  not( travelnet.targets[ owner_name ] )
		or not( travelnet.targets[ owner_name ][ station_network ] )
		or not( travelnet.targets[ owner_name ][ station_network ][ station_name ] )) then

		-- first one by this player?
		if not travelnet.targets[owner_name] then
			travelnet.targets[owner_name ] = {};
		end

		-- first station on this network?
		if not travelnet.targets[ owner_name ][ station_network ] then
			travelnet.targets[owner_name ][ station_network ] = {};
		end


		local zeit = meta:get_int("timestamp");
		if not( zeit) or type(zeit)~="number" or zeit<100000 then
			zeit = os.time();
		end

		-- add this station
		travelnet.targets[ owner_name ][ station_network ][ station_name ] = {pos=pos, timestamp=zeit };

		minetest.chat_send_player(owner_name, S("Station '@1'" .." "..
			"has been reattached to the network '@2'.", station_name, station_network)
		);
		travelnet.save_data();
	end


	-- add name of station + network + owner + update-button
	local zusatzstr = "";
	local trheight = "10";

	local formspec = "size[12,"..trheight.."]"..
		"label[3.3,0.0;"..S("Travelnet-Box")..":]".."label[6.3,0.0;"..
		S("Punch box to update target list.").."]"..
		"label[0.3,0.4;"..S("Name of this station:").."]"..
		"label[6.3,0.4;"..minetest.formspec_escape(station_name or "?").."]"..
		"label[0.3,0.8;"..S("Assigned to Network:").."]" ..
		"label[6.3,0.8;"..minetest.formspec_escape(station_network or "?").."]"..
		"label[0.3,1.2;"..S("Owned by:").."]"..
		"label[6.3,1.2;"..minetest.formspec_escape(owner_name or "?").."]"..
		"label[3.3,1.6;"..S("Click on target to travel there:").."]"..
		zusatzstr;

	local x = 0;
	local y = 0;
	local i = 0;


	-- collect all station names in a table
	local stations = {};

	for k in pairs( travelnet.targets[ owner_name ][ station_network ] ) do
		table.insert( stations, k );
	end

	local ground_level = 1;
	if is_elevator then
		table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].pos.y >
		travelnet.targets[ owner_name ][ station_network ][ b ].pos.y  end);
		-- find ground level
		local vgl_timestamp = 999999999999;
		for index,k in ipairs( stations ) do
			if not travelnet.targets[ owner_name ][ station_network ][ k ].timestamp then
				travelnet.targets[ owner_name ][ station_network ][ k ].timestamp = os.time();
			end
			if travelnet.targets[ owner_name ][ station_network ][ k ].timestamp < vgl_timestamp then
				vgl_timestamp = travelnet.targets[ owner_name ][ station_network ][ k ].timestamp;
				ground_level  = index;
			end
		end

		for index,k in ipairs( stations ) do
			if( index == ground_level ) then
				travelnet.targets[ owner_name ][ station_network ][ k ].nr = 'G';
			else
				travelnet.targets[ owner_name ][ station_network ][ k ].nr = tostring( ground_level - index );
			end
		end
	else
		-- sort the table according to the timestamp (=time the station was configured)
		table.sort( stations, function(a,b)
			return travelnet.targets[ owner_name ][ station_network ][ a ].timestamp <
				travelnet.targets[ owner_name ][ station_network ][ b ].timestamp
		end);
	end

	-- does the player want to move this station one position up in the list?
	-- only the owner and players with the travelnet_attach priv can change the order of the list
	-- Note: With elevators, only the "G"(round) marking is actually moved
	if( fields
		and (fields.move_up or fields.move_down)
		and owner_name
		and owner_name ~= ""
		and ((owner_name == puncher_name)
		or (minetest.check_player_privs(puncher_name, {travelnet_attach=true})))
	) then

		local current_pos = -1;
		for index,k in ipairs( stations ) do
			if( k==station_name ) then
				current_pos = index;
			end
		end

		local swap_with_pos;
		if( fields.move_up ) then
			swap_with_pos = current_pos - 1;
		else
			swap_with_pos = current_pos + 1;
		end
		-- handle errors
		if(     swap_with_pos < 1) then
			travelnet.show_message( pos, puncher_name, "Info", S("This station is already the first one on the list."));
			return;
		elseif( swap_with_pos > #stations ) then
			travelnet.show_message( pos, puncher_name, "Info", S("This station is already the last one on the list."));
			return;
		else
			-- swap the actual data by which the stations are sorted
			local old_timestamp = travelnet.targets[ owner_name ][ station_network ][ stations[swap_with_pos]].timestamp;
			travelnet.targets[    owner_name ][ station_network ][ stations[swap_with_pos]].timestamp =
			travelnet.targets[ owner_name ][ station_network ][ stations[current_pos  ]].timestamp;
			travelnet.targets[    owner_name ][ station_network ][ stations[current_pos  ]].timestamp =
			old_timestamp;

			-- for elevators, only the "G"(round) marking is moved; no point in swapping stations
			if( not( is_elevator )) then
				-- actually swap the stations
				local old_val = stations[ swap_with_pos ];
				stations[ swap_with_pos ] = stations[ current_pos ];
				stations[ current_pos   ] = old_val;
			end

			-- store the changed order
			travelnet.save_data();
		end
	end

	-- if there are only 8 stations (plus this one), center them in the formspec
	if #stations < 10 then
		x = 4;
	end

	for _,k in ipairs(stations) do
		-- check if there is an elevator door in front that needs to be opened
		local open_door_cmd = false;
		if( k==station_name ) then
			open_door_cmd = true;
		end

		if( k ~= station_name or open_door_cmd) then
			i = i+1;

			-- new column
			if y==8 then
				x = x+4;
				y = 0;
			end

			if open_door_cmd then
				formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;open_door;<>]"..
					"label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
			elseif( is_elevator ) then
				formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;target;"..
					tostring( travelnet.targets[ owner_name ][ station_network ][ k ].nr ).."]"..
					"label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
			else
				formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";4,0.5;target;"..k.."]";
			end

			y = y+1;
		end
	end

	formspec = formspec..
		"label[8.0,1.6;"..S("Position in list:").."]"..
		"button_exit[11.3,0.0;1.0,0.5;station_exit;"..S("Exit").."]"..
		"button_exit[10.0,0.5;2.2,0.7;station_dig;"..S("Remove station").."]"..
		"button[9.6,1.6;1.4,0.5;move_up;"..S("move up").."]"..
		"button[10.9,1.6;1.4,0.5;move_down;"..S("move down").."]";

	meta:set_string( "formspec", formspec );

	meta:set_string( "infotext", S("Station '@1'".." "..
		"on travelnet '@2' (owned by @3)" .." "..
		"ready for usage. Right-click to travel, punch to update.",
		tostring(station_name), tostring(station_network), tostring(owner_name)));

	-- show the player the updated formspec
	travelnet.show_current_formspec( pos, meta, puncher_name );
end
