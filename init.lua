
          
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

    
 Changelog:
 20.03.13 - added inventory image provided by VanessaE
          - fixed bug that made it impossible to remove stations from the net
          - if the station a player beamed to no longer exists, the station will be removed automaticly
          - with the travelnet_attach priv, you can now attach your box to the nets of other players
          - in newer versions of Minetest, the players yaw is set so that he/she looks out of the receiving box
          - target list is now centered if there are less than 9 targets
--]]

local MAX_STATIONS_PER_NETWORK = 24;

minetest.register_privilege("travelnet_attach", { description = "allows to attach travelnet boxes to travelnets of other players", give_to_singleplayer = false});

travelnet = {};

travelnet.targets = {};


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

   local meta = minetest.env:get_meta(pos);

   if( not( meta )) then
      return;
   end

   local owner_name      = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( owner_name ) 
     or not( station_name ) 
     or not( station_network )) then


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
    
   -- sort the table according to the timestamp (=time the station was configured)
   table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].timestamp < 
                                              travelnet.targets[ owner_name ][ station_network ][ b ].timestamp  end);

   -- if there are only 8 stations (plus this one), center them in the formspec
   if( #stations < 10 ) then
      x = 4;
   end

   for index,k in ipairs( stations ) do 

      if( k ~= station_name ) then 
         i = i+1;

         -- new column
         if( y==8 ) then
            x = x+4;
            y = 0;
         end

         formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";4,0.5;target;"..k.."]"
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

   if( station_name == "" or not(station_name )) then
      minetest.chat_send_player(player_name, "Please provide a name for this station.");
      return;
   end

   if( network_name == "" or not( network_name )) then
      minetest.chat_send_player(player_name, "Please provide the name of the network this station ought to be connected to.");
      return;
   end

   if(     owner_name == nil or owner_name == '' ) then
      owner_name = player_name;

   elseif( not( travelnet.targets[ owner_name ] )
        or not( travelnet.targets[ owner_name ][ network_name ] )) then

      minetest.chat_send_player(player_name, "There is no network named "..tostring( network_name ).." owned by "..tostring( owner_name )..". Aborting.");
      return;

   elseif( not( minetest.check_player_privs(player_name, {travelnet_attach=true}))) then

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
   if( anz+1 > MAX_STATIONS_PER_NETWORK ) then
      minetest.chat_send_player(player_name, "Error: Network '"..network_name.."' already contains the maximum number (="
              ..(MAX_STATIONS_PER_NETWORK)..") of allowed stations per network. Please choose a diffrent/new network name.");
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


travelnet.on_receive_fields = function(pos, formname, fields, player)
   local meta = minetest.env:get_meta(pos);

   local name = player:get_player_name();

   -- if the box has not been configured yet
   if( meta:get_string("station_network")=="" ) then

      travelnet.add_target( fields.station_name, fields.station_network, pos, name, meta, fields.owner_name );
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


      minetest.chat_send_player(puncher_name, "Error: There is something wrong with the configuration of this station. "..
                                             " DEBUG DATA: owner: "..(  owner_name or "?")..
                                                  " station_name: "..(station_name or "?")..
                                               " station_network: "..(station_network or "?")..".");
   end

   -- if the target station is gone
   if( not( travelnet.targets[ owner_name ][ station_network ][ fields.target ] )) then

      minetest.chat_send_player(name, "Station '"..( fields.target or "?").." does not exist (anymore?) on this network.");
      travelnet.update_formspec( pos, name );
      return;
   end


   minetest.chat_send_player(name, "Initiating transfer to station '"..( fields.target or "?").."'.'");




   -- TODO
   --minetest.sound_play("teleporter_teleport", {pos = pos, gain = 1.0, max_hear_distance = 10,})
   -- transport the player to the target location
   local target_pos = travelnet.targets[ owner_name ][ station_network ][ fields.target ].pos;
   player:moveto( target_pos, false);
   --minetest.sound_play("teleporter_teleport", {pos = travelnet.targets[ owner_name ][ station_network ][ fields.target ].pos, gain = 1.0, max_hear_distance = 10,})


   -- check if the box has at the other end has been removed
   local node2 = minetest.env:get_node(  target_pos );
   if( node2 ~= nil and node2.name ~= 'ignore' and node2.name ~= 'travelnet:travelnet' ) then

      -- provide information necessary to identify the removed box
      local oldmetadata = { fields = { owner           = owner_name,
                                       station_name    = fields.target,
                                       station_network = station_network }};

      travelnet.remove_box( target_pos, nil, oldmetadata, player );
   else

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
       
      player:set_look_yaw( yaw ); -- this is only supported in recent versions of MT
   end

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



minetest.register_node("travelnet:travelnet", {

    description = "Travelnet box",

    drawtype = "nodebox",
    sunlight_propagates = true,
    paramtype = 'light',
    paramtype2 = "facedir",

    selection_box = {
                type = "fixed",
                fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
    },

    node_box = {
	    type = "fixed",
	    fixed = {

                { 0.45, -0.5,-0.5,  0.5,  1.45, 0.5},
                {-0.5 , -0.5, 0.45, 0.45, 1.45, 0.5}, 
                {-0.5,  -0.5,-0.5 ,-0.45, 1.45, 0.5},

                --groundplate to stand on
                { -0.5,-0.5,-0.5,0.5,-0.45, 0.5}, 
                --roof
                { -0.5, 1.45,-0.5,0.5, 1.5, 0.5}, 

                -- control panel
--                { -0.2, 0.6,  0.3, 0.2, 1.1,  0.5},

            },
    },
    

    tiles = {
          
             "default_clay.png",  -- view from top
             "default_clay.png",  -- view from bottom
             "travelnet_travelnet_side.png", -- side
             "travelnet_travelnet_side.png", -- side

             "travelnet_travelnet_back.png", -- front view
             "travelnet_travelnet_front.png",  -- backward view
             },
    inventory_image = "travelnet_inv.png",

    groups = {choppy=2,dig_immediate=2,attached_node=1},

    light_source = 10,

    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.env:get_meta(pos);
        meta:set_string("infotext",       "Travelnet-box (unconfigured)");
        meta:set_string("station_name",   "");
        meta:set_string("station_network","");
        meta:set_string("owner",          placer:get_player_name() );
        -- request initinal data
        meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,5.6;6,0.7;station_name;Name of this station:;]"..
                            "field[0.3,6.6;6,0.7;station_network;Assign to Network:;]"..
                            "field[0.3,7.6;6,0.7;owner_name;(optional) owned by:;]"..
                            "button_exit[6.3,6.2;1.7,0.7;station_set;Store]" );
    end,
    
    on_receive_fields = travelnet.on_receive_fields,
    on_punch          = function(pos, node, puncher)
                          travelnet.update_formspec(pos, puncher:get_player_name())
    end,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
			  travelnet.remove_box( pos, oldnode, oldmetadata, digger )
    end,

    -- taken from VanessaEs homedecor fridge
    on_place = function(itemstack, placer, pointed_thing)

       local pos = pointed_thing.above;
       if( minetest.env:get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" ) then

          minetest.chat_send_player( placer:get_player_name(), 'Not enough vertical space to place the travelnet box!' )
          return;
       end
       return minetest.item_place(itemstack, placer, pointed_thing);
    end,

})


minetest.register_craft({
        output = "travelnet:travelnet",
        recipe = {
                {"default:glass", "default:steel_ingot", "default:glass", },
                {"default:glass", "default:mese",        "default:glass", },
                {"default:glass", "default:steel_ingot", "default:glass", }
        }
})


-- upon server start, read the savefile
travelnet.restore_data();

