local S = minetest.get_translator("travelnet")

-- punching the travelnet updates its formspec and shows it to the player;
-- however, that would be very annoying when actually trying to dig the thing.
-- Thus, check if the player is wielding a tool that can dig nodes of the
-- group cracky
travelnet.check_if_trying_to_dig = function(puncher)
	-- if in doubt: show formspec
	if not puncher or not puncher:get_wielded_item() then
		return false;
	end
	-- show menu when in creative mode
	if creative and creative.is_enabled_for(puncher:get_player_name()) then
		return false;
	end
	local tool_capabilities = puncher:get_wielded_item():get_tool_capabilities();
	if not tool_capabilities or not tool_capabilities["groupcaps"] or not tool_capabilities["groupcaps"]["cracky"] then
		return false;
	end
	-- tools which can dig cracky items can start digging immediately
	return true;
end


-- allow doors to open
travelnet.open_close_door = function( pos, player, mode )
	local this_node = minetest.get_node_or_nil( pos );
	-- give up if the area is *still* not loaded
	if not this_node then
		return
	end
	local pos2 = {x=pos.x,y=pos.y,z=pos.z};

	if(     this_node.param2 == 0 ) then pos2 = {x=pos.x,y=pos.y,z=(pos.z-1)};
	elseif( this_node.param2 == 1 ) then pos2 = {x=(pos.x-1),y=pos.y,z=pos.z};
	elseif( this_node.param2 == 2 ) then pos2 = {x=pos.x,y=pos.y,z=(pos.z+1)};
	elseif( this_node.param2 == 3 ) then pos2 = {x=(pos.x+1),y=pos.y,z=pos.z};
	end

	local door_node = minetest.get_node(pos2);
	if door_node and door_node.name ~= 'ignore' and door_node.name ~= 'air' and
		minetest.registered_nodes[ door_node.name ] ~= nil and
		minetest.registered_nodes[ door_node.name ].on_rightclick ~= nil then

		-- at least for homedecor, same facedir would mean "door closed"
		-- do not close the elevator door if it is already closed
		if (mode==1 and ( string.sub( door_node.name, -7 ) == '_closed'
		-- handle doors that change their facedir
			or ( door_node.param2 == ((this_node.param2 + 2)%4)
			and door_node.name ~= 'travelnet:elevator_door_glass_open'
			and door_node.name ~= 'travelnet:elevator_door_tin_open'
			and door_node.name ~= 'travelnet:elevator_door_steel_open'))) then
				return;
		end

		-- do not open the doors if they are already open (works only on elevator-doors; not on doors in general)
		if( mode==2 and ( string.sub( door_node.name, -5 ) == '_open'
			-- handle doors that change their facedir
			or ( door_node.param2 ~= ((this_node.param2 + 2)%4)
			and door_node.name ~= 'travelnet:elevator_door_glass_closed'
			and door_node.name ~= 'travelnet:elevator_door_tin_closed'
			and door_node.name ~= 'travelnet:elevator_door_steel_closed'))) then
				return;
		end

		if mode == 2 then
			local playername = player:get_player_name()
			minetest.after(1, function()
				local pplayer = minetest.get_player_by_name(playername)
				if pplayer then
					minetest.registered_nodes[ door_node.name ].on_rightclick(pos2, door_node, pplayer);
				end
			end);
		else
			minetest.registered_nodes[ door_node.name ].on_rightclick(pos2, door_node, player);
		end
	end
end


travelnet.rotate_player = function( target_pos, player, tries )
	-- try later when the box is loaded
	local node2 = minetest.get_node_or_nil( target_pos );
	if node2 == nil then
		if tries < 30 then
			minetest.after( 0, travelnet.rotate_player, target_pos, player, tries+1 )
		end
		return
	end

	-- play sound at the target position as well
	if( travelnet.travelnet_sound_enabled ) then
		if ( node2.name == 'travelnet:elevator' ) then
			minetest.sound_play("travelnet_bell", {pos = target_pos, gain = 0.75, max_hear_distance = 10,});
		else
			minetest.sound_play("travelnet_travel", {pos = target_pos, gain = 0.75, max_hear_distance = 10,});
		end
	end

	-- do this only on servers where the function exists
	if player.set_look_horizontal then
	-- rotate the player so that he/she can walk straight out of the box
		local yaw    = 0;
		local param2 = node2.param2;
		if( param2==0 ) then
			yaw = 180;
		elseif param2==1 then
			yaw = 90;
		elseif param2==2 then
			yaw = 0;
		elseif param2==3 then
			yaw = 270;
		end

		player:set_look_horizontal( math.rad( yaw ));
		player:set_look_vertical( math.rad( 0 ));
	end

	travelnet.open_close_door( target_pos, player, 2 );
end


travelnet.remove_box = function(_, _, oldmetadata, digger )
	if not oldmetadata or oldmetadata=="nil" or not oldmetadata.fields then
	minetest.chat_send_player( digger:get_player_name(), S("Error")..": "..
		S("Could not find information about the station that is to be removed."));
		return;
	end

	local owner_name      = oldmetadata.fields[ "owner" ];
	local station_name    = oldmetadata.fields[ "station_name" ];
	local station_network = oldmetadata.fields[ "station_network" ];

	-- station is not known? then just remove it
	if(  not( owner_name )
		or not( station_name )
		or not( station_network )
		or not( travelnet.targets[ owner_name ] )
		or not( travelnet.targets[ owner_name ][ station_network ] )) then

		minetest.chat_send_player( digger:get_player_name(), S("Error")..": "..
		S("Could not find the station that is to be removed."));
		return;
	end

	travelnet.targets[ owner_name ][ station_network ][ station_name ] = nil;

	-- inform the owner
	minetest.chat_send_player( owner_name, S("Station '@1'" .." "..
		"has been REMOVED from the network '@2'.", station_name, station_network));
	if digger ~= nil and owner_name ~= digger:get_player_name() then
		minetest.chat_send_player( digger:get_player_name(), S("Station '@1'" .." "..
			"has been REMOVED from the network '@2'.", station_name, station_network));
	end

	-- save the updated network data in a savefile over server restart
	travelnet.save_data();
end



travelnet.can_dig = function()
	-- forbid digging of the travelnet
	return false;
end
