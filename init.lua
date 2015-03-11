
          
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

 Version: 2.2 (with optional abm for self-healing)
    
 Please configure this mod in config.lua

 Changelog:
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


minetest.register_privilege("travelnet_attach", { description = "allows to attach travelnet boxes to travelnets of other players", give_to_singleplayer = false});
minetest.register_privilege("travelnet_remove", { description = "allows to dig travelnet boxes which belog to nets of other players", give_to_singleplayer = false});

travelnet = {};

travelnet.targets = {};


-- read the configuration
dofile(minetest.get_modpath("travelnet").."/config.lua"); -- the normal, default travelnet



-- TODO: save and restore ought to be library functions and not implemented in each individual mod!
-- called whenever a station is added or removed
travelnet.save_data = function()
   
   local data = minetest.serialize( travelnet.targets );
   local path = minetest.get_worldpath().."/mod_travelnet.data";

   local file = io.open( path, "w" );
   if( file ) then
      file:write( data );
      file:close();
   else
      print("[Mod travelnet] Error: Savefile '"..tostring( path ).."' could not be written.");
   end
end


travelnet.restore_data = function()

   local path = minetest.get_worldpath().."/mod_travelnet.data";
   
   local file = io.open( path, "r" );
   if( file ) then
      local data = file:read("*all");
      travelnet.targets = minetest.deserialize( data );
      file:close();
   else
      print("[Mod travelnet] Error: Savefile '"..tostring( path ).."' not found.");
   end
end




travelnet.update_formspec = function( pos, puncher_name )

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


      meta:set_string("infotext",       "Travelnet-box (unconfigured)");
      meta:set_string("station_name",   "");
      meta:set_string("station_network","");
      meta:set_string("owner",          "");
      -- request initinal data
      meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,7.6;9,0.9;station_name;Name of this station:;"..(station_name or "?").."]"..
                            "field[0.3,8.6;9,0.9;station_network;Assign to Network:;"..(station_network or "?").."]"..
                            "field[0.3,9.6;9,0.9;owner;Owned by:;"..(owner_name or "?").."]"..
                            "button_exit[6.3,8.2;1.7,0.7;station_set;Store]" );

      minetest.chat_send_player(puncher_name, "Error: Update failed! Resetting this box on the travelnet.");
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
      if( not( zeit) or zeit<100000 ) then
         zeit = os.time();
      end

      -- add this station
      travelnet.targets[ owner_name ][ station_network ][ station_name ] = {pos=pos, timestamp=zeit };

      minetest.chat_send_player(owner_name, "Station '"..station_name.."' has been reattached to the network '"..station_network.."'.");

   end


   -- add name of station + network + owner + update-button
   local formspec = "size[12,10]"..
                            "label[3.3,0.0;Travelnet-Box:]".."label[6.3,0.0;Punch box to update target list.]"..
                            "label[0.3,0.4;Name of this station:]".."label[6.3,0.4;"..(station_name or "?").."]"..
                            "label[0.3,0.8;Assigned to Network:]" .."label[6.3,0.8;"..(station_network or "?").."]"..
                            "label[0.3,1.2;Owned by:]"            .."label[6.3,1.2;"..(owner_name or "?").."]"..
                            "label[3.3,1.6;Click on target to travel there:]";
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
         if( travelnet.targets[ owner_name ][ station_network ][ k ].timestamp < vgl_timestamp ) then
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
      table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].timestamp < 
                                                 travelnet.targets[ owner_name ][ station_network ][ b ].timestamp  end);
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

   meta:set_string( "formspec", formspec );

   meta:set_string( "infotext", "Station '"..tostring( station_name ).."' on travelnet '"..tostring( station_network )..
                                "' (owned by "..tostring( owner_name )..") ready for usage. Right-click to travel, punch to update.");

   minetest.chat_send_player(puncher_name, "The target list of this box on the travelnet has been updated.");
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
         station_name = 'at '..tostring( pos.y )..'m';
      end
   end

   if( station_name == "" or not(station_name )) then
      minetest.chat_send_player(player_name, "Please provide a name for this station.");
      return;
   end

   if( network_name == "" or not( network_name )) then
      minetest.chat_send_player(player_name, "Please provide the name of the network this station ought to be connected to.");
      return;
   end

   if(     owner_name == nil or owner_name == '' or owner_name == player_name) then
      owner_name = player_name;

   elseif( is_elevator ) then -- elevator networks
      owner_name = player_name;

   elseif( not( travelnet.targets[ owner_name ] )
        or not( travelnet.targets[ owner_name ][ network_name ] )) then

      minetest.chat_send_player(player_name, "There is no network named "..tostring( network_name ).." owned by "..tostring( owner_name )..". Aborting.");
      return;

   elseif( not( minetest.check_player_privs(player_name, {travelnet_attach=true}))
       and not( travelnet.allow_attach( player_name, owner_name, network_name ))) then

        minetest.chat_send_player(player_name, "You do not have the travelnet_attach priv which is required to attach your box to the network of someone else. Aborting.");
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
         minetest.chat_send_player(player_name, "Error: A station named '"..station_name.."' already exists on this network. Please choose a diffrent name!");
         return;
      end

      anz = anz + 1;
   end

   -- we don't want too many stations in the same network because that would get confusing when displaying the targets
   if( anz+1 > travelnet.MAX_STATIONS_PER_NETWORK ) then
      minetest.chat_send_player(player_name, "Error: Network '"..network_name.."' already contains the maximum number (="
              ..(travelnet.MAX_STATIONS_PER_NETWORK)..") of allowed stations per network. Please choose a diffrent/new network name.");
      return;
   end
     
   -- add this station
   travelnet.targets[ owner_name ][ network_name ][ station_name ] = {pos=pos, timestamp=os.time() };

   -- do we have a new node to set up? (and are not just reading from a safefile?)
   if( meta ) then

      minetest.chat_send_player(player_name, "Station '"..station_name.."' has been added to the network '"
                                          ..network_name.."', which now consists of "..( anz+1 ).." station(s).");

      meta:set_string( "station_name",    station_name );
      meta:set_string( "station_network", network_name );
      meta:set_string( "owner",           owner_name );
      meta:set_int( "timestamp",       travelnet.targets[ owner_name ][ network_name ][ station_name ].timestamp);

      meta:set_string("formspec", 
                     "size[12,10]"..
                     "field[0.3,0.6;6,0.7;station_name;Station:;"..   meta:get_string("station_name").."]"..
                     "field[0.3,3.6;6,0.7;station_network;Network:;"..meta:get_string("station_network").."]" );

      -- display a list of all stations that can be reached from here
      travelnet.update_formspec( pos, player_name );

      -- save the updated network data in a savefile over server restart
      travelnet.save_data();
   end
end



-- allow doors to open
travelnet.open_close_door = function( pos, player, mode )

   local this_node = minetest.get_node( pos );
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
      if( mode==1 and ( door_node.name == 'travelnet:elevator_door_glass_closed'
                     or door_node.name == 'travelnet:elevator_door_steel_closed' 
                     -- handle doors that change their facedir
                     or ( door_node.param2 == this_node.param2
                      and door_node.name ~= 'travelnet:elevator_door_glass_open'
                      and door_node.name ~= 'travelnet:elevator_door_steel_open'))) then
         return;
      end
      -- do not open the doors if they are already open (works only on elevator-doors; not on doors in general)
      if( mode==2 and ( door_node.name == 'travelnet:elevator_door_glass_open'
                     or door_node.name == 'travelnet:elevator_door_steel_open'
                     -- handle doors that change their facedir
                     or ( door_node.param2 ~= this_node.param2 
                      and door_node.name ~= 'travelnet:elevator_door_glass_closed'
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
   local meta = minetest.get_meta(pos);

   local name = player:get_player_name();

   -- if the box has not been configured yet
   if( meta:get_string("station_network")=="" ) then

      travelnet.add_target( fields.station_name, fields.station_network, pos, name, meta, fields.owner_name );
      return;
   end

   if( fields.open_door ) then
      travelnet.open_close_door( pos, player, 0 );
      return;
   end


   if( not( fields.target )) then
      minetest.chat_send_player(name, "Please click on the target you want to travel to.");
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
         minetest.chat_send_player(name, "Error: There is something wrong with the configuration of this station. "..
                                      " DEBUG DATA: owner: "..(  owner_name or "?")..
                                      " station_name: "..(station_name or "?")..
                                      " station_network: "..(station_network or "?")..".");
         return
      end
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

      minetest.chat_send_player(name, "Station '"..( fields.target or "?").." does not exist (anymore?) on this network.");
      travelnet.update_formspec( pos, name );
      return;
   end


   if( not( travelnet.allow_travel( name, owner_name, station_network, station_name, fields.target ))) then
      return;
   end
   minetest.chat_send_player(name, "Initiating transfer to station '"..( fields.target or "?").."'.'");



   if( travelnet.travelnet_sound_enabled ) then
      minetest.sound_play("128590_7037-lq.mp3", {pos = pos, gain = 1.0, max_hear_distance = 10,})
   end
   if( travelnet.travelnet_effect_enabled ) then 
      minetest.add_entity( {x=pos.x,y=pos.y+0.5,z=pos.z}, "travelnet:effect"); -- it self-destructs after 20 turns
   end

   -- close the doors at the sending station
   travelnet.open_close_door( pos, player, 1 );

   -- transport the player to the target location
   local target_pos = travelnet.targets[ owner_name ][ station_network ][ fields.target ].pos;
   player:moveto( target_pos, false);

   if( travelnet.travelnet_sound_enabled ) then
      minetest.sound_play("travelnet_travel.wav", {pos = target_pos, gain = 1.0, max_hear_distance = 10,})
   end
   if( travelnet.travelnet_effect_enabled ) then 
      minetest.add_entity( {x=target_pos.x,y=target_pos.y+0.5,z=target_pos.z}, "travelnet:effect"); -- it self-destructs after 20 turns
   end


   -- check if the box has at the other end has been removed.
   local node2 = minetest.get_node(  target_pos );
   if( node2 ~= nil and node2.name ~= 'ignore' and node2.name ~= 'travelnet:travelnet' and node2.name ~= 'travelnet:elevator') then

      -- provide information necessary to identify the removed box
      local oldmetadata = { fields = { owner           = owner_name,
                                       station_name    = fields.target,
                                       station_network = station_network }};

      travelnet.remove_box( target_pos, nil, oldmetadata, player );

   -- do this only on servers where the function exists
   elseif( player.set_look_yaw ) then

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
       
      player:set_look_yaw( math.rad( yaw )); -- this is only supported in recent versions of MT
      player:set_look_pitch( math.rad( 0 )); -- this is only supported in recent versions of MT
   end

   travelnet.open_close_door( target_pos, player, 2 );
end


travelnet.remove_box = function( pos, oldnode, oldmetadata, digger )

   if( not( oldmetadata ) or oldmetadata=="nil" or not(oldmetadata.fields)) then
      minetest.chat_send_player( digger:get_player_name(), "Error: Could not find information about the station that is to be removed.");
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
       
      minetest.chat_send_player( digger:get_player_name(), "Error: Could not find the station that is to be removed.");
      return;
   end

   travelnet.targets[ owner_name ][ station_network ][ station_name ] = nil;
   
   -- inform the owner
   minetest.chat_send_player( owner_name, "Station '"..station_name.."' has been REMOVED from the network '"..station_network.."'.");
   if( digger ~= nil and owner_name ~= digger:get_player_name() ) then
      minetest.chat_send_player( digger:get_player_name(), "Station '"..station_name.."' has been REMOVED from the network '"..station_network.."'.");
   end

   -- save the updated network data in a savefile over server restart
   travelnet.save_data();
end



travelnet.can_dig = function( pos, player, description )

   if( not( player )) then
      return false;
   end
   local name          = player:get_player_name();

   -- players with that priv can dig regardless of owner
   if( minetest.check_player_privs(name, {travelnet_remove=true})
       or travelnet.allow_dig( player_name, owner_name, network_name )) then
      return true;
   end

   local meta          = minetest.get_meta( pos );
   local owner         = meta:get_string('owner');

   if( not( meta ) or not( owner) or owner=='') then
      minetest.chat_send_player(name, "This "..description.." has not been configured yet. Please set it up first to claim it. Afterwards you can remove it because you are then the owner.");
      return false;

   elseif( owner ~= name ) then
      minetest.chat_send_player(name, "This "..description.." belongs to "..tostring( meta:get_string('owner'))..". You can't remove it.");
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
       self.object:setyaw( self.object:getyaw()+1);
       self.anz_rotations = self.anz_rotations + 1;
       -- eventually self-destruct
       if( self.anz_rotations > 15 ) then
          self.object:remove();
       end
    end
  })
end


if( travelnet.travelnet_enabled ) then
   dofile(minetest.get_modpath("travelnet").."/travelnet.lua"); -- the travelnet node definition
end
if( travelnet.elevator_enabled ) then
   dofile(minetest.get_modpath("travelnet").."/elevator.lua");  -- allows up/down transfers only
end
if( travelnet.doors_enabled ) then
   dofile(minetest.get_modpath("travelnet").."/doors.lua");     -- doors that open and close automaticly when the travelnet or elevator is used
end

if( travelnet.abm_enabled ) then
   dofile(minetest.get_modpath("travelnet").."/restore_network_via_abm.lua"); -- restore travelnet data when players pass by broken networks
end

-- upon server start, read the savefile
travelnet.restore_data();

