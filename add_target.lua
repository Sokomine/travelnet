local S = minetest.get_translator("travelnet")


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
         station_name = S("at @1 m", tostring( pos.y ));
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
	S("There is no player with interact privilege named '@1'. Aborting.", tostring( player_name)));
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
   for k in pairs( travelnet.targets[ owner_name ][ network_name ] ) do

      if( k == station_name ) then
         travelnet.show_message( pos, player_name, S("Error"),
	    S("A station named '@1' already exists on this network. Please choose a different name!", station_name));
         return;
      end

      anz = anz + 1;
   end

   -- we don't want too many stations in the same network because that would get confusing when displaying the targets
   if( anz+1 > travelnet.MAX_STATIONS_PER_NETWORK ) then
      travelnet.show_message( pos, player_name, S("Error"),
	S("Network '@1', already contains the maximum number (@2) of allowed stations per network. "..
	"Please choose a different/new network name.", network_name, travelnet.MAX_STATIONS_PER_NETWORK));
      return;
   end

   -- add this station
   travelnet.targets[ owner_name ][ network_name ][ station_name ] = {pos=pos, timestamp=os.time() };

   -- do we have a new node to set up? (and are not just reading from a safefile?)
   if( meta ) then

      minetest.chat_send_player(player_name, S("Station '@1'" .." "..
		"has been added to the network '@2'" ..
		", which now consists of @3 station(s).", station_name, network_name, anz+1));

      meta:set_string( "station_name",    station_name );
      meta:set_string( "station_network", network_name );
      meta:set_string( "owner",           owner_name );
      meta:set_int( "timestamp",       travelnet.targets[ owner_name ][ network_name ][ station_name ].timestamp);

      meta:set_string("formspec",
                     "size[12,10]"..
                     "field[0.3,0.6;6,0.7;station_name;"..S("Station:")..";"..
										 minetest.formspec_escape(meta:get_string("station_name")).."]"..
                     "field[0.3,3.6;6,0.7;station_network;"..S("Network:")..";"..
										 minetest.formspec_escape(meta:get_string("station_network")).."]" );

      -- display a list of all stations that can be reached from here
      travelnet.update_formspec( pos, player_name, nil );

      -- save the updated network data in a savefile over server restart
      travelnet.save_data();
   end
end
