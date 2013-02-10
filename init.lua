
local MAX_STATIONS_PER_NETWORK = 24;

travelnet = {};

travelnet.targets = {};

travelnet.get_targets = function()
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


      minetest.chat_send_player(puncher_name, "DEBUG DATA: owner: "..(owner_name or "?")..
                                                  " station_name: "..(station_name or "?")..
                                               " station_network: "..(station_network or "?")..".");
-- minetest.chat_send_player(puncher_name, "data: "..minetest.serialize(  travelnet.targets ));


      meta:set_string("infotext",       "Travel-box (unconfigured)");
      meta:set_string("station_name",   "");
      meta:set_string("station_network","");
      meta:set_string("owner",          "");
      -- request initinal data
      meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,3.6;6,0.7;station_name;Name of this station:;"..(station_name or "?").."]"..
                            "field[0.3,6.6;6,0.7;station_network;Assign to Network:;"..(station_network or "?").."]"..
                            "field[0.3,9.6;6,0.7;owner;Owned by:;"..(owner_name or "?").."]"..
                            "button_exit[6.3,3.2;1.7,0.7;station_set;Store]" );

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
                            "label[3.3,0.0;Travel-Box: Punch box to update target list.]"..
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

   minetest.chat_send_player(puncher_name, "The target list of this box on the travelnet has been updated.");
end



-- add a new target; meta is optional
travelnet.add_target = function( station_name, network_name, pos, player_name, meta )

   if( station_name == "" or not(station_name )) then
      minetest.chat_send_player(player_name, "Please provide a name for this station.");
      return;
   end

   if( network_name == "" or not( network_name )) then
      minetest.chat_send_player(player_name, "Please provide the name of the network this station ought to be connected to.");
      return;
   end


   -- first one by this player?
   if( not( travelnet.targets[ player_name ] )) then
      travelnet.targets[       player_name ] = {};
   end
 
   -- first station on this network?
   if( not( travelnet.targets[ player_name ][ network_name ] )) then
      travelnet.targets[       player_name ][ network_name ] = {};
   end

   -- lua doesn't allow efficient counting here
   local anz = 0;
   for k,v in pairs( travelnet.targets[ player_name ][ network_name ] ) do

      if( k == station_name ) then
         minetest.chat_send_player(player_name, "Error: A station named '"..station_name.."' already exists on this network. Please choose a diffrent name!");
         return;
      end

--      minetest.chat_send_player(name,"Checing station "..( k ).."..");
      anz = anz + 1;
   end

   -- we don't want too many stations in the same network because that would get confusing when displaying the targets
   if( anz+1 > MAX_STATIONS_PER_NETWORK ) then
      minetest.chat_send_player(player_name, "Error: Network '"..network_name.."' already contains the maximum number (="
              ..(MAX_STATIONS_PER_NETWORK)..") of allowed stations per network. Please choose a diffrent/new network name.");
      return;
   end
     
   -- add this station
   travelnet.targets[ player_name ][ network_name ][ station_name ] = {pos=pos, timestamp=os.time() };


   -- do we have a new node to set up? (and are not just reading from a safefile?)
   if( meta ) then

      minetest.chat_send_player(player_name, "Station '"..station_name.."' has been added to the network '"
                                          ..network_name.."', which now consists of "..( anz+1 ).." station(s).");

      meta:set_string( "station_name",    station_name );
      meta:set_string( "station_network", network_name );
      meta:set_string( "owner",           player_name );
      meta:set_int( "timestamp",       travelnet.targets[ player_name ][ network_name ][ station_name ].timestamp);

      meta:set_string("formspec", 
                     "size[12,10]"..
                     "field[0.3,0.6;6,0.7;station_name;Station:;"..   meta:get_string("station_name").."]"..
                     "field[0.3,3.6;6,0.7;station_network;Network:;"..meta:get_string("station_network").."]" );

      -- display a list of all stations that can be reached from here
      travelnet.update_formspec( pos, player_name );
   end
end


travelnet.on_receive_fields = function(pos, formname, fields, player)
   local meta = minetest.env:get_meta(pos);

   local name = player:get_player_name();

   -- if the box has not been configured yet
   if( meta:get_string("station_network")=="" ) then

      travelnet.add_target( fields.station_name, fields.station_network, pos, name, meta );
      return;
   end


   if( not( fields.target )) then
      minetest.chat_send_player(name, "Please click on the target you want to travel to.");
      return;
   end


   -- if there is something wrong with the data
   local player_name     = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( player_name ) 
     or not( station_name ) 
     or not( station_network )
     or not( travelnet.targets[ player_name ] )
     or not( travelnet.targets[ player_name ][ station_network ] )) then


      minetest.chat_send_player(puncher_name, "Error: There is something wrong with the configuration of this station. "..
                                             " DEBUG DATA: owner: "..( player_name or "?")..
                                                  " station_name: "..(station_name or "?")..
                                               " station_network: "..(station_network or "?")..".");
   end

   -- if the target station is gone
   if( not( travelnet.targets[ player_name ][ station_network ][ fields.target ] )) then

      minetest.chat_send_player(name, "Station '"..( fields.target or "?").." does not exist (anymore?) on this network.");
      travelnet.update_formspec( pos, name );
      return;
   end


   minetest.chat_send_player(name, "Initiating transfer to station '"..( fields.target or "?").."'.'");




   -- TODO
   --minetest.sound_play("teleporter_teleport", {pos = pos, gain = 1.0, max_hear_distance = 10,})
   -- transport the player to the target location
   player:moveto( travelnet.targets[ player_name ][ station_network ][ fields.target ].pos, false);
   --minetest.sound_play("teleporter_teleport", {pos = travelnet.targets[ player_name ][ station_network ][ fields.target ].pos, gain = 1.0, max_hear_distance = 10,})

end




minetest.register_node("travelnet:travelnet", {

    description = "Travel box",

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


                {-0.45,-0.5,-0.5,-0.5,1.5, 0.5},
                { 0.45,-0.5,-0.5, 0.5,1.5, 0.5},

                { -0.5,-0.5, 0.5,0.45,1.5, 0.45},

                --groundplate to stand on
                { -0.5,-0.5,-0.5,0.5,-0.45, 0.5}, 
                --roof
                { -0.5, 1.45,-0.5,0.5, 1.5, 0.5}, 

                -- control panel
                { -0.2, 0.6,  0.3, 0.2, 1.1,  0.5},

            },
    },
    

    tiles = {
          
             "default_clay.png",  -- view from top
             "default_clay.png",  -- view from bottom
             "moreblocks_glowglass.png", -- side
             "moreblocks_glowglass.png", -- side

             "default_brick.png", -- front view
             "default_wood.png",  -- backward view
--             "moreblocks_glowglass.png",
--             "moreblocks_glowglass.png",
--             "moreblocks_glowglass.png",
--             "moreblocks_glowglass.png"},
             },
--    inventory_image = minetest.inventorycube("travelnet_travelnet.png"),

    groups = {choppy=2,dig_immediate=2,attached_node=1},
    legacy_wallmounted = true,


    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.env:get_meta(pos);
        meta:set_string("infotext",       "Travel-box (unconfigured)");
        meta:set_string("station_name",   "");
        meta:set_string("station_network","");
        meta:set_string("owner",          placer:get_player_name() );
        -- request initinal data
        meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,0.6;6,0.7;station_name;Name of this station:;]"..
                            "field[0.3,3.6;6,0.7;station_network;Assign to Network:;]"..
                            "button_exit[6.3,3.2;1.7,0.7;station_set;Store]" );
    end,
    
    on_receive_fields = travelnet.on_receive_fields,
    on_punch          = function(pos, node, puncher)
                          travelnet.update_formspec(pos, puncher:get_player_name())
    end,
})



