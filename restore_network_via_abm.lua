
minetest.register_abm({
        nodenames = {"travelnet:travelnet"},
        interval = 20,
        chance = 1,
        action = function(pos, node)
		local meta = minetest.get_meta( pos );

		local owner_name      = meta:get_string( "owner" );
		local station_name    = meta:get_string( "station_name" );
		local station_network = meta:get_string( "station_network" );

		if( owner_name and station_name and station_network 
		    and ( not( travelnet.targets )
		       or not( travelnet.targets[ owner_name ] )
		       or not( travelnet.targets[ owner_name ][ station_network ] )
		       or not( travelnet.targets[ owner_name ][ station_network ][ station_name ] ))) then

			travelnet.add_target( station_name, station_network, pos, owner_name, meta, owner_name );
			print( 'TRAVELNET: re-adding '..tostring( station_name )..' to '..tostring( station_network )..' owned by '..tostring( owner_name ));
		end
	end
})

