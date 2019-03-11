

--[[
    Teleporter networks that allow players to choose a destination out of a list
    Copyright (C) 2013 Sokomine

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

 Version: 2.3 (click button to dig)

 Please configure this mod in config.lua

 Changelog:
 10.03.19 - Added the extra config buttons for locked_travelnet mod.
 09.03.19 - Several PRs merged (sound added, locale changed etc.)
            Version bumped to 2.3
 26.02.19 - Removing a travelnet can now be done by clicking on a button (no need to
            wield a diamond pick anymore)
 26.02.19 - Added compatibility with MineClone2
 22.09.18 - Move up/move down no longer close the formspec.
 22.09.18 - If in creative mode, wield a diamond pick to dig the station. This avoids
            conflicts with too fast punches.
 24.12.17 - Added support for localization through intllib.
            Added localization for German (de).
            Door opening/closing can now handle more general doors.
 17.07.17 - Added more detailled licence information.
            TNT and DungeonMasters ought to leave travelnets and elevators untouched now.
            Added function to register elevator doors.
            Added elevator doors made out of tin ingots.
            Provide information about the nearest elevator network when placing a new elevator. This
              ought to make it easier to find the right spot.
            Improved formspec.
 16.07.17 - Merged several PR from others (Typo, screenshot, documentation, mesecon support, bugfix).
            Added buttons to move stations up or down in the list, independent on when they where added.
            Fixed undeclared globals.
            Changed deprecated functions set_look_yaw/pitch to current functions.
 22.07.17 - Fixed bug with locked travelnets beeing removed from the network due to not beeing recognized.
 30.08.16 - If the station the traveller just travelled to no longer exists, the player is sent back to the
            station where he/she came from.
 30.08.16 - Attaching a travelnet box to a non-existant network of another player is possible (requested by OldCoder).
            Still requires the travelnet_attach-priv.
 05.10.14 - Added an optional abm so that the travelnet network can heal itshelf in case of loss of the savefile.
            If you want to use this, set
                  travelnet.enable_abm = true
            in config.lua and edit the interval in the abm to suit your needs.
 19.11.13 - moved doors and travelnet definition into an extra file
          - moved configuration to config.lua
 05.08.13 - fixed possible crash when the node in front of the travelnet is unknown
 26.06.13 - added inventory image for elevator (created by VanessaE)
 21.06.13 - bugfix: wielding an elevator while digging a door caused the elevator_top to be placed
          - leftover floating elevator_top nodes can be removed by placing a new travelnet:elevator underneath them and removing that afterwards
          - homedecor-doors are now opened and closed correctly as well
          - removed nodes that are not intended for manual use from creative inventory
          - improved naming of station levels for the elevator
 21.06.13 - elevator stations are sorted by height instead of date of creation as is the case with travelnet boxes
          - elevator stations are named automaticly
 20.06.13 - doors can be opened and closed from inside the travelnet box/elevator
          - the elevator can only move vertically; the network name is defined by its x and z coordinate
 13.06.13 - bugfix
          - elevator added (written by kpoppel) and placed into extra file
          - elevator doors added
          - groups changed to avoid accidental dig/drop on dig of node beneath
          - added new priv travelnet_remove for digging of boxes owned by other players
          - only the owner of a box or players with the travelnet_remove priv can now dig it
          - entering your own name as owner_name does no longer abort setup
 22.03.13 - added automatic detection if yaw can be set
          - beam effect is disabled by default
 20.03.13 - added inventory image provided by VanessaE
          - fixed bug that made it impossible to remove stations from the net
          - if the station a player beamed to no longer exists, the station will be removed automaticly
          - with the travelnet_attach priv, you can now attach your box to the nets of other players
          - in newer versions of Minetest, the players yaw is set so that he/she looks out of the receiving box
          - target list is now centered if there are less than 9 targets
--]]

-- Required to save the travelnet data properly in all cases
if not minetest.safe_file_write then
	error("[Mod travelnet] Your Minetest version is no longer supported. (version < 0.4.17)")
end

travelnet = {};

travelnet.targets = {};
travelnet.path = minetest.get_modpath(minetest.get_current_modname())


-- Intllib
local S = dofile(travelnet.path .. "/intllib.lua")
travelnet.S = S


minetest.register_privilege("travelnet_attach", { description = S("allows to attach travelnet boxes to travelnets of other players"), give_to_singleplayer = false});
minetest.register_privilege("travelnet_remove", { description = S("allows to dig travelnet boxes which belog to nets of other players"), give_to_singleplayer = false});

-- read the configuration
dofile(travelnet.path.."/config.lua"); -- the normal, default travelnet

travelnet.mod_data_path = minetest.get_worldpath().."/mod_travelnet.data"

-- TODO: save and restore ought to be library functions and not implemented in each individual mod!
-- called whenever a station is added or removed
travelnet.save_data = function()

   local data = minetest.serialize( travelnet.targets );

   local success = minetest.safe_file_write( travelnet.mod_data_path, data );
   if( not success ) then
      print(S("[Mod travelnet] Error: Savefile '%s' could not be written.")
         :format(travelnet.mod_data_path));
   end
end


travelnet.restore_data = function()
   
   local file = io.open( travelnet.mod_data_path, "r" );
   if( not file ) then
      print(S("[Mod travelnet] Error: Savefile '%s' not found.")
         :format(travelnet.mod_data_path));
      return;
   end

   local data = file:read("*all");
   travelnet.targets = minetest.deserialize( data );

   if( not travelnet.targets ) then
       local backup_file = travelnet.mod_data_path..".bak"
       print(S("[Mod travelnet] Error: Savefile '%s' is damaged. Saved the backup as '%s'.")
          :format(travelnet.mod_data_path, backup_file));

       minetest.safe_file_write( backup_file, data );
       travelnet.targets = {};
   end
   file:close();
end


-- punching the travelnet updates its formspec and shows it to the player;
-- however, that would be very annoying when actually trying to dig the thing.
-- Thus, check if the player is wielding a tool that can dig nodes of the
-- group cracky
travelnet.check_if_trying_to_dig = function( puncher, node )
	-- if in doubt: show formspec
	if( not( puncher) or not( puncher:get_wielded_item())) then
		return false;
	end
	-- show menu when in creative mode
        if(   creative
	  and creative.is_enabled_for(puncher:get_player_name())
--          and (not(puncher:get_wielded_item())
--                or puncher:get_wielded_item():get_name()~="default:pick_diamond")) then
		) then
		return false;
	end
	local tool_capabilities = puncher:get_wielded_item():get_tool_capabilities();
	if( not( tool_capabilities )
	 or not( tool_capabilities["groupcaps"])
	 or not( tool_capabilities["groupcaps"]["cracky"])) then
		return false;
	end
	-- tools which can dig cracky items can start digging immediately
	return true;
end

-- minetest.chat_send_player is sometimes not so well visible
travelnet.show_message = function( pos, player_name, title, message )
	if( not( pos ) or not( player_name ) or not( message )) then
		return;
	end
	local formspec = "size[8,3]"..
		"label[3,0;"..minetest.formspec_escape( title or "Error").."]"..
		"textlist[0,0.5;8,1.5;;"..minetest.formspec_escape( message or "- nothing -")..";]"..
		"button_exit[3.5,2.5;1.0,0.5;back;"..S("Back").."]"..
		"button_exit[6.8,2.5;1.0,0.5;station_exit;"..S("Exit").."]"..
		"field[20,20;0.1,0.1;pos2str;Pos;".. minetest.pos_to_string( pos ).."]";
	minetest.show_formspec(player_name, "travelnet:show", formspec);
end

-- show the player the formspec he would see when right-clicking the node;
-- needs to be simulated this way as calling on_rightclick would not do
travelnet.show_current_formspec = function( pos, meta, player_name )
	if( not( pos ) or not( meta ) or not( player_name )) then
		return;
	end
	-- we need to supply the position of the travelnet box
	formspec = meta:get_string("formspec")..
		"field[20,20;0.1,0.1;pos2str;Pos;".. minetest.pos_to_string( pos ).."]";
	-- show the formspec manually
	minetest.show_formspec(player_name, "travelnet:show", formspec);
end

-- a player clicked on something in the formspec he was manually shown
-- (back from help page, moved travelnet up or down etc.)
travelnet.form_input_handler = function( player, formname, fields)
        if(formname == "travelnet:show" and fields and fields.pos2str) then
		local pos = minetest.string_to_pos( fields.pos2str );
		if( locks and (fields.locks_config or fields.locks_authorize)) then
			return locks:lock_handle_input( pos, formname, fields, player )
		end
		-- back button leads back to the main menu
		if( fields.back and fields.back ~= "" ) then
			return travelnet.show_current_formspec( pos,
					minetest.get_meta( pos ), player:get_player_name());
		end
		return travelnet.on_receive_fields(pos, formname, fields, player);
        end
end

-- most formspecs the travelnet uses are stored in the travelnet node itself,
-- but some may require some "back"-button functionality (i.e. help page,
-- move up/down etc.)
minetest.register_on_player_receive_fields( travelnet.form_input_handler );



travelnet.reset_formspec = function( meta )
      if( not( meta )) then
         return;
      end
      meta:set_string("infotext",       S("Travelnet-box (unconfigured)"));
      meta:set_string("station_name",   "");
      meta:set_string("station_network","");
      meta:set_string("owner",          "");
      -- some players seem to be confused with entering network names at first; provide them
      -- with a default name
      if( not( station_network ) or station_network == "" ) then
         station_network = "net1";
      end
      -- request initinal data
      meta:set_string("formspec",
		"size[10,6.0]"..
		"label[2.0,0.0;--> "..S("Configure this travelnet station").." <--]"..
		"button_exit[8.0,0.0;2.2,0.7;station_dig;"..S("Remove station").."]"..
		"field[0.3,1.2;9,0.9;station_name;"..S("Name of this station")..":;"..
			minetest.formspec_escape(station_name or "").."]"..
		"label[0.3,1.5;"..S("How do you call this place here? Example: \"my first house\", \"mine\", \"shop\"...").."]"..

		"field[0.3,2.8;9,0.9;station_network;"..S("Assign to Network:")..";"..
			minetest.formspec_escape(station_network or "").."]"..
		"label[0.3,3.1;"..S("You can have more than one network. If unsure, use \"%s\""):format(tostring(station_network))..".]"..
		"field[0.3,4.4;9,0.9;owner;"..S("Owned by:")..";]"..
		"label[0.3,4.7;"..S("Unless you know what you are doing, leave this empty.").."]"..
		"button_exit[1.3,5.3;1.7,0.7;station_help_setup;"..S("Help").."]"..
		"button_exit[3.8,5.3;1.7,0.7;station_set;"..S("Save").."]"..
		"button_exit[6.3,5.3;1.7,0.7;station_exit;"..S("Exit").."]");
end


travelnet.update_formspec = function( pos, puncher_name, fields )
   local meta = minetest.get_meta(pos);

   local this_node   = minetest.get_node( pos );
   local is_elevator = false;

   if( this_node ~= nil and this_node.name == 'travelnet:elevator' ) then
      is_elevator = true;
   end

   if( not( meta )) then
      return;
   end

   local owner_name      = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( owner_name )
     or not( station_name ) or station_network == ''
     or not( station_network )) then


      if( is_elevator == true ) then
         travelnet.add_target( nil, nil, pos, puncher_name, meta, owner_name );
         return;
      end

--      minetest.chat_send_player(puncher_name, "DEBUG DATA: owner: "..(owner_name or "?")..
--                                                  " station_name: "..(station_name or "?")..
--                                               " station_network: "..(station_network or "?")..".");
-- minetest.chat_send_player(puncher_name, "data: "..minetest.serialize(  travelnet.targets ));


      travelnet.reset_formspec( meta );
      travelnet.show_message( pos, puncher_name, "Error", S("Update failed! Resetting this box on the travelnet."));
      return;
   end

   -- if the station got lost from the network for some reason (savefile corrupted?) then add it again
   if(  not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )
     or not( travelnet.targets[ owner_name ][ station_network ][ station_name ] )) then

      -- first one by this player?
      if( not( travelnet.targets[ owner_name ] )) then
         travelnet.targets[       owner_name ] = {};
      end

      -- first station on this network?
      if( not( travelnet.targets[ owner_name ][ station_network ] )) then
         travelnet.targets[       owner_name ][ station_network ] = {};
      end


      local zeit = meta:get_int("timestamp");
      if( not( zeit) or type(zeit)~="number" or zeit<100000 ) then
         zeit = os.time();
      end

      -- add this station
      travelnet.targets[ owner_name ][ station_network ][ station_name ] = {pos=pos, timestamp=zeit };

      minetest.chat_send_player(owner_name, S("Station '%s'"):format(station_name).." "..
		S(" has been reattached to the network '%s'."):format(station_network));
      travelnet.save_data();
   end


   -- add name of station + network + owner + update-button
   local zusatzstr = "";
   local trheight = "10";
   if( this_node and this_node.name=="locked_travelnet:travelnet" and locks) then
      zusatzstr = "field[0.3,11;6,0.7;locks_sent_lock_command;"..S("Locked travelnet. Type /help for help:")..";]"..
		  locks.get_authorize_button(10,"10.5")..
		  locks.get_config_button(11,"10.5")
      trheight = "11.5";
   end
   local formspec = "size[12,"..trheight.."]"..
                            "label[3.3,0.0;"..S("Travelnet-Box")..":]".."label[6.3,0.0;"..S("Punch box to update target list.").."]"..
                            "label[0.3,0.4;"..S("Name of this station:").."]".."label[6.3,0.4;"..minetest.formspec_escape(station_name or "?").."]"..
                            "label[0.3,0.8;"..S("Assigned to Network:").."]" .."label[6.3,0.8;"..minetest.formspec_escape(station_network or "?").."]"..
                            "label[0.3,1.2;"..S("Owned by:").."]"            .."label[6.3,1.2;"..minetest.formspec_escape(owner_name or "?").."]"..
                            "label[3.3,1.6;"..S("Click on target to travel there:").."]"..
			    zusatzstr;
--                            "button_exit[5.3,0.3;8,0.8;do_update;Punch box to update destination list. Click on target to travel there.]"..
   local x = 0;
   local y = 0;
   local i = 0;


   -- collect all station names in a table
   local stations = {};

   for k,v in pairs( travelnet.targets[ owner_name ][ station_network ] ) do
      table.insert( stations, k );
   end
   -- minetest.chat_send_player(puncher_name, "stations: "..minetest.serialize( stations ));

   local ground_level = 1;
   if( is_elevator ) then
      table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].pos.y >
                                                 travelnet.targets[ owner_name ][ station_network ][ b ].pos.y  end);
      -- find ground level
      local vgl_timestamp = 999999999999;
      for index,k in ipairs( stations ) do
         if( not( travelnet.targets[ owner_name ][ station_network ][ k ].timestamp )) then
            travelnet.targets[ owner_name ][ station_network ][ k ].timestamp = os.time();
         end
         if( travelnet.targets[ owner_name ][ station_network ][ k ].timestamp < vgl_timestamp ) then
            vgl_timestamp = travelnet.targets[ owner_name ][ station_network ][ k ].timestamp;
            ground_level  = index;
         end
      end
      for index,k in ipairs( stations ) do
         if( index == ground_level ) then
            travelnet.targets[ owner_name ][ station_network ][ k ].nr = S('G');
         else
            travelnet.targets[ owner_name ][ station_network ][ k ].nr = tostring( ground_level - index );
         end
      end

   else
      -- sort the table according to the timestamp (=time the station was configured)
      table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].timestamp <
                                                 travelnet.targets[ owner_name ][ station_network ][ b ].timestamp  end);
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

      local swap_with_pos = -1;
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
   if( #stations < 10 ) then
      x = 4;
   end

   for index,k in ipairs( stations ) do

      -- check if there is an elevator door in front that needs to be opened
      local open_door_cmd = false;
      if( k==station_name ) then
         open_door_cmd = true;
      end

      if( k ~= station_name or open_door_cmd) then
         i = i+1;

         -- new column
         if( y==8 ) then
            x = x+4;
            y = 0;
         end

         if( open_door_cmd ) then
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;open_door;<>]"..
                                  "label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
         elseif( is_elevator ) then
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;target;"..tostring( travelnet.targets[ owner_name ][ station_network ][ k ].nr ).."]"..
                                  "label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
         else
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";4,0.5;target;"..k.."]";
         end

--         if( is_elevator ) then
--            formspec = formspec ..' ('..tostring( travelnet.targets[ owner_name ][ station_network ][ k ].pos.y )..'m)';
--         end
--         formspec = formspec .. ']';

         y = y+1;
         --x = x+4;
      end
   end
   formspec = formspec..
         "label[8.0,1.6;"..S("Position in list:").."]"..
         "button_exit[11.3,0.0;1.0,0.5;station_exit;"..S("Exit").."]"..
         "button_exit[10.0,0.5;2.2,0.7;station_dig;"..S("Remove station").."]"..
         "button[9.6,1.6;1.4,0.5;move_up;"..S("move up").."]"..
         "button[10.9,1.6;1.4,0.5;move_down;"..S("move down").."]";

   meta:set_string( "formspec", formspec );

   meta:set_string( "infotext", S("Station '%s'"):format(tostring( station_name )).." "..
				S("on travelnet '%s'"):format(tostring( station_network )).." "..
                                S("(owned by %s)"):format(tostring( owner_name )).." "..
				S("ready for usage. Right-click to travel, punch to update."));

   -- show the player the updated formspec
   travelnet.show_current_formspec( pos, meta, puncher_name );
end



-- add a new target; meta is optional
travelnet.add_target = function( station_name, network_name, pos, player_name, meta, owner_name )

   -- if it is an elevator, determine the network name through x and z coordinates
   local this_node   = minetest.get_node( pos );
   local is_elevator = false;

   if( this_node.name == 'travelnet:elevator' ) then
--      owner_name   = '*'; -- the owner name is not relevant here
      is_elevator  = true;
      network_name = tostring( pos.x )..','..tostring( pos.z );
      if( not( station_name ) or station_name == '' ) then
         station_name = S('at %s m'):format(tostring( pos.y ));
      end
   end

   if( station_name == "" or not(station_name )) then
      travelnet.show_message( pos, player_name, S("Error"), S("Please provide a name for this station." ));
      return;
   end

   if( network_name == "" or not( network_name )) then
      travelnet.show_message( pos, player_name, S("Error"),
	S("Please provide the name of the network this station ought to be connected to."));
      return;
   end

   if(     owner_name == nil or owner_name == '' or owner_name == player_name) then
      owner_name = player_name;

   elseif( is_elevator ) then -- elevator networks
      owner_name = player_name;

   elseif( not( minetest.check_player_privs(player_name, {interact=true}))) then

      travelnet.show_message( pos, player_name, S("Error"),
	S("There is no player with interact privilege named '%s'. Aborting."):format(tostring( player_name )));
      return;

   elseif( not( minetest.check_player_privs(player_name, {travelnet_attach=true}))
       and not( travelnet.allow_attach( player_name, owner_name, network_name ))) then

      travelnet.show_message( pos, player_name, S("Error"),
	S("You do not have the travelnet_attach priv which is required to attach your box to "..
	"the network of someone else. Aborting."));
      return;
   end

   -- first one by this player?
   if( not( travelnet.targets[ owner_name ] )) then
      travelnet.targets[       owner_name ] = {};
   end

   -- first station on this network?
   if( not( travelnet.targets[ owner_name ][ network_name ] )) then
      travelnet.targets[       owner_name ][ network_name ] = {};
   end

   -- lua doesn't allow efficient counting here
   local anz = 0;
   for k,v in pairs( travelnet.targets[ owner_name ][ network_name ] ) do

      if( k == station_name ) then
         travelnet.show_message( pos, player_name, S("Error"),
	    S("A station named '%s' already exists on this network. Please choose a diffrent name!"):format(station_name));
         return;
      end

      anz = anz + 1;
   end

   -- we don't want too many stations in the same network because that would get confusing when displaying the targets
   if( anz+1 > travelnet.MAX_STATIONS_PER_NETWORK ) then
      travelnet.show_message( pos, player_name, S("Error"),
	S("Network '%s',"):format(network_name).." "..
	S("already contains the maximum number (=%s) of allowed stations per network. "..
	"Please choose a diffrent/new network name."):format(travelnet.MAX_STATIONS_PER_NETWORK));
      return;
   end

   -- add this station
   travelnet.targets[ owner_name ][ network_name ][ station_name ] = {pos=pos, timestamp=os.time() };

   -- do we have a new node to set up? (and are not just reading from a safefile?)
   if( meta ) then

      minetest.chat_send_player(player_name, S("Station '%s'"):format(station_name).." "..
		S("has been added to the network '%s'"):format(network_name)..
		S(", which now consists of %s station(s)."):format(anz+1));

      meta:set_string( "station_name",    station_name );
      meta:set_string( "station_network", network_name );
      meta:set_string( "owner",           owner_name );
      meta:set_int( "timestamp",       travelnet.targets[ owner_name ][ network_name ][ station_name ].timestamp);

      meta:set_string("formspec",
                     "size[12,10]"..
                     "field[0.3,0.6;6,0.7;station_name;"..S("Station:")..";"..   minetest.formspec_escape(meta:get_string("station_name")).."]"..
                     "field[0.3,3.6;6,0.7;station_network;"..S("Network:")..";"..minetest.formspec_escape(meta:get_string("station_network")).."]" );

      -- display a list of all stations that can be reached from here
      travelnet.update_formspec( pos, player_name, nil );

      -- save the updated network data in a savefile over server restart
      travelnet.save_data();
   end
end



-- allow doors to open
travelnet.open_close_door = function( pos, player, mode )

   local this_node = minetest.get_node_or_nil( pos );
   -- give up if the area is *still* not loaded
   if( this_node == nil ) then
      return
   end
   local pos2 = {x=pos.x,y=pos.y,z=pos.z};

   if(     this_node.param2 == 0 ) then pos2 = {x=pos.x,y=pos.y,z=(pos.z-1)};
   elseif( this_node.param2 == 1 ) then pos2 = {x=(pos.x-1),y=pos.y,z=pos.z};
   elseif( this_node.param2 == 2 ) then pos2 = {x=pos.x,y=pos.y,z=(pos.z+1)};
   elseif( this_node.param2 == 3 ) then pos2 = {x=(pos.x+1),y=pos.y,z=pos.z};
   end

   local door_node = minetest.get_node( pos2 );
   if( door_node ~= nil and door_node.name ~= 'ignore' and door_node.name ~= 'air' and minetest.registered_nodes[ door_node.name ] ~= nil and minetest.registered_nodes[ door_node.name ].on_rightclick ~= nil) then

      -- at least for homedecor, same facedir would mean "door closed"

      -- do not close the elevator door if it is already closed
      if( mode==1 and ( string.sub( door_node.name, -7 ) == '_closed'
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

      if( mode==2 ) then
         minetest.after( 1, minetest.registered_nodes[ door_node.name ].on_rightclick, pos2, door_node, player );
      else
         minetest.registered_nodes[ door_node.name ].on_rightclick(pos2, door_node, player);
      end
   end
end


travelnet.on_receive_fields = function(pos, formname, fields, player)
   if( not( pos )) then
      return;
   end
   local meta = minetest.get_meta(pos);

   local name = player:get_player_name();

   -- the player wants to quit/exit the formspec; do not save/update anything
   if( fields and fields.station_exit and fields.station_exit ~= "" ) then
      return;
   end

   -- show special locks buttons if needed
   if( locks and (fields.locks_config or fields.locks_authorize)) then
      return locks:lock_handle_input( pos, formname, fields, player )
   end

   -- show help text
   if( fields and fields.station_help_setup and fields.station_help_setup ~= "") then
      -- simulate right-click
      local node = minetest.get_node( pos );
      if( node and node.name and minetest.registered_nodes[ node.name ] ) then
         travelnet.show_message( pos, name, "--> Help <--",
-- TODO: actually add help page
		S("No help available yet."));
      end
      return;
   end

   -- the player wants to remove the station
   if( fields.station_dig ) then
      local owner = meta:get_string( "owner" );

      local node = minetest.get_node(pos)
      local description = "station"
      if( node and node.name and node.name == "travelnet:travelnet") then
         description = "travelnet box"
      elseif( node and node.name and node.name == "travelnet:elevator") then
         description = "elevator"
      elseif( node and node.name and node.name == "locked_travelnet:travelnet") then
         description = "locked travelnet"
      else
         minetest.chat_send_player(name, "Error: Unkown node.");
         return
      end
      -- players with travelnet_remove priv can dig the station
      if( not(minetest.check_player_privs(name, {travelnet_remove=true}))
       -- the function travelnet.allow_dig(..) may allow additional digging
       and not(travelnet.allow_dig( name, owner, network_name ))
       -- the owner can remove the station
       and owner ~= name
       -- stations without owner can be removed by anybody
       and owner ~= "") then
         minetest.chat_send_player(name, S("This %s belongs to %s. You can't remove it."):format(description, tostring( meta:get_string('owner'))));
         return
      end

      local pinv = player:get_inventory()
      if(not(pinv:room_for_item("main", node.name))) then
         minetest.chat_send_player(name, S("You do not have enough room in your inventory."));
         return
      end

      -- give the player the box
      pinv:add_item("main", node.name)
      -- remove the box from the data structure
      travelnet.remove_box( pos, nil, meta:to_table(), player );
      -- remove the node as such
      minetest.remove_node(pos)
      return;
   end




   -- if the box has not been configured yet
   if( meta:get_string("station_network")=="" ) then

      travelnet.add_target( fields.station_name, fields.station_network, pos, name, meta, fields.owner );
      return;
   end

   if( fields.open_door ) then
      travelnet.open_close_door( pos, player, 0 );
      return;
   end

   -- the owner or players with the travelnet_attach priv can move stations up or down in the list
   if( fields.move_up or fields.move_down) then
      travelnet.update_formspec( pos, name, fields );
      return;
   end

   if( not( fields.target )) then
      minetest.chat_send_player(name, S("Please click on the target you want to travel to."));
      return;
   end


   -- if there is something wrong with the data
   local owner_name      = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( owner_name  )
     or not( station_name )
     or not( station_network )
     or not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )) then


      if(     owner_name
          and station_name
          and station_network ) then
            travelnet.add_target( station_name, station_network, pos, owner_name, meta, owner_name );
      else
         minetest.chat_send_player(name, S("Error")..": "..
				S("There is something wrong with the configuration of this station.")..
                                      " DEBUG DATA: owner: "..(  owner_name or "?")..
                                      " station_name: "..(station_name or "?")..
                                      " station_network: "..(station_network or "?")..".");
         return
      end
   end

   if(  not( owner_name )
     or not( station_network )
     or not( travelnet.targets )
     or not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )) then
      minetest.chat_send_player(name, S("Error")..": "..
				S("This travelnet is lacking data and/or improperly configured."));
      print( "ERROR: The travelnet at "..minetest.pos_to_string( pos ).." has a problem: "..
                                      " DATA: owner: "..(  owner_name or "?")..
                                      " station_name: "..(station_name or "?")..
                                      " station_network: "..(station_network or "?")..".");
      return;
   end

   local this_node = minetest.get_node( pos );
   if( this_node ~= nil and this_node.name == 'travelnet:elevator' ) then
      for k,v in pairs( travelnet.targets[ owner_name ][ station_network ] ) do
         if( travelnet.targets[ owner_name ][ station_network ][ k ].nr  --..' ('..tostring( travelnet.targets[ owner_name ][ station_network ][ k ].pos.y )..'m)'
               == fields.target) then
            fields.target = k;
         end
      end
   end


   -- if the target station is gone
   if( not( travelnet.targets[ owner_name ][ station_network ][ fields.target ] )) then

      minetest.chat_send_player(name, S("Station '%s'"):format( fields.target or "?").." "..
			S("does not exist (anymore?) on this network."));
      travelnet.update_formspec( pos, name, nil );
      return;
   end


   if( not( travelnet.allow_travel( name, owner_name, station_network, station_name, fields.target ))) then
      return;
   end
   minetest.chat_send_player(name, S("Initiating transfer to station '%s'."):format( fields.target or "?"));



   if( travelnet.travelnet_sound_enabled ) then
      if ( this_node.name == 'travelnet:elevator' ) then
         minetest.sound_play("travelnet_bell", {pos = pos, gain = 0.75, max_hear_distance = 10,});
      else
         minetest.sound_play("travelnet_travel", {pos = pos, gain = 0.75, max_hear_distance = 10,});
      end
   end
   if( travelnet.travelnet_effect_enabled ) then
      minetest.add_entity( {x=pos.x,y=pos.y+0.5,z=pos.z}, "travelnet:effect"); -- it self-destructs after 20 turns
   end

   -- close the doors at the sending station
   travelnet.open_close_door( pos, player, 1 );

   -- transport the player to the target location
   local target_pos = travelnet.targets[ owner_name ][ station_network ][ fields.target ].pos;
   player:move_to( target_pos, false);

   if( travelnet.travelnet_effect_enabled ) then 
      minetest.add_entity( {x=target_pos.x,y=target_pos.y+0.5,z=target_pos.z}, "travelnet:effect"); -- it self-destructs after 20 turns
   end


   -- check if the box has at the other end has been removed.
   local node2 = minetest.get_node_or_nil(  target_pos );
   if( node2 ~= nil and node2.name ~= 'ignore' and node2.name ~= 'travelnet:travelnet' and node2.name ~= 'travelnet:elevator' and node2.name ~= "locked_travelnet:travelnet" and node2.name ~= "travelnet:travelnet_private") then

      -- provide information necessary to identify the removed box
      local oldmetadata = { fields = { owner           = owner_name,
                                       station_name    = fields.target,
                                       station_network = station_network }};

      travelnet.remove_box( target_pos, nil, oldmetadata, player );
      -- send the player back as there's no receiving travelnet
      player:move_to( pos, false );

   else
      travelnet.rotate_player( target_pos, player, 0 )
   end
end

travelnet.rotate_player = function( target_pos, player, tries )
   -- try later when the box is loaded
   local node2 = minetest.get_node_or_nil( target_pos );
   if( node2 == nil ) then
      if( tries < 30 ) then
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
   if( player.set_look_horizontal ) then
      -- rotate the player so that he/she can walk straight out of the box
      local yaw    = 0;
      local param2 = node2.param2;
      if( param2==0 ) then
         yaw = 180;
      elseif( param2==1 ) then
         yaw = 90;
      elseif( param2==2 ) then
         yaw = 0;
      elseif( param2==3 ) then
         yaw = 270;
      end

      player:set_look_horizontal( math.rad( yaw ));
      player:set_look_vertical( math.rad( 0 ));
   end

   travelnet.open_close_door( target_pos, player, 2 );
end


travelnet.remove_box = function( pos, oldnode, oldmetadata, digger )

   if( not( oldmetadata ) or oldmetadata=="nil" or not(oldmetadata.fields)) then
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
   minetest.chat_send_player( owner_name, S("Station '%s'"):format(station_name ).." "..
		S("has been REMOVED from the network '%s'."):format(station_network));
   if( digger ~= nil and owner_name ~= digger:get_player_name() ) then
      minetest.chat_send_player( digger:get_player_name(), S("Station '%s'"):format(station_name)..
		S("has been REMOVED from the network '%s'."):format(station_network));
   end

   -- save the updated network data in a savefile over server restart
   travelnet.save_data();
end



travelnet.can_dig = function( pos, player, description )
   -- forbid digging of the travelnet
   return false;
end

-- obsolete function
travelnet.can_dig_old = function( pos, player, description )
   if( not( player )) then
      return false;
   end
   local name          = player:get_player_name();
   local meta          = minetest.get_meta( pos );
   local owner         = meta:get_string('owner');
   local network_name  = meta:get_string( "station_network" );

   -- in creative mode, accidental digging could happen too easily when trying to update the net
   if(creative and creative.is_enabled_for(player:get_player_name())) then
     -- only a diamond pick can dig the travelnet
     if( not(player:get_wielded_item())
          or player:get_wielded_item():get_name()~="default:pick_diamond") then
        return false;
     end
   end

   -- players with that priv can dig regardless of owner
   if( minetest.check_player_privs(name, {travelnet_remove=true})
       or travelnet.allow_dig( name, owner, network_name )) then
      return true;
   end

   if( not( meta ) or not( owner) or owner=='') then
      minetest.chat_send_player(name, S("This %s has not been configured yet. Please set it up first to claim it. Afterwards you can remove it because you are then the owner."):format(description));
      return false;

   elseif( owner ~= name ) then
      minetest.chat_send_player(name, S("This %s belongs to %s. You can't remove it."):format(description, tostring( meta:get_string('owner'))));
      return false;
   end
   return true;
end





if( travelnet.travelnet_effect_enabled ) then
  minetest.register_entity( 'travelnet:effect', {

    hp_max = 1,
    physical = false,
    weight = 5,
    collisionbox = {-0.4,-0.5,-0.4, 0.4,1.5,0.4},
    visual = "upright_sprite",
    visual_size = {x=1, y=2},
--    mesh = "model",
    textures = { "travelnet_flash.png" }, -- number of required textures depends on visual
--    colors = {}, -- number of required colors depends on visual
    spritediv = {x=1, y=1},
    initial_sprite_basepos = {x=0, y=0},
    is_visible = true,
    makes_footstep_sound = false,
    automatic_rotate = true,

    anz_rotations = 0,

    on_step = function( self, dtime )
       -- this is supposed to be more flickering than smooth animation
       self.object:set_yaw( self.object:get_yaw()+1);
       self.anz_rotations = self.anz_rotations + 1;
       -- eventually self-destruct
       if( self.anz_rotations > 15 ) then
          self.object:remove();
       end
    end
  })
end


if( travelnet.travelnet_enabled ) then
   dofile(travelnet.path.."/travelnet.lua"); -- the travelnet node definition
end
if( travelnet.elevator_enabled ) then
   dofile(travelnet.path.."/elevator.lua");  -- allows up/down transfers only
end
if( travelnet.doors_enabled ) then
   dofile(travelnet.path.."/doors.lua");     -- doors that open and close automaticly when the travelnet or elevator is used
end

if( travelnet.abm_enabled ) then
   dofile(travelnet.path.."/restore_network_via_abm.lua"); -- restore travelnet data when players pass by broken networks
end

-- upon server start, read the savefile
travelnet.restore_data();
