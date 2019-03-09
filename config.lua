
travelnet.MAX_STATIONS_PER_NETWORK = 24;

-- set this to true if you want a simulated beam effect
travelnet.travelnet_effect_enabled = false;
-- set this to true if you want a sound to be played when the travelnet is used
travelnet.travelnet_sound_enabled  = false;

-- if you set this to false, travelnets cannot be created
-- (this may be useful if you want nothing but the elevators on your server)
travelnet.travelnet_enabled        = true;
-- if you set travelnet.elevator_enabled to false, you will not be able to
-- craft, place or use elevators
travelnet.elevator_enabled         = true;
-- if you set this to false, doors will be disabled
travelnet.doors_enabled            = true;

-- starts an abm which re-adds travelnet stations to networks in case the savefile got lost
travelnet.abm_enabled              = false;

-- change these if you want other receipes for travelnet or elevator
travelnet.travelnet_recipe = {
                {"default:glass", "default:steel_ingot", "default:glass", },
                {"default:glass", "default:mese",        "default:glass", },
                {"default:glass", "default:steel_ingot", "default:glass", }
}
travelnet.elevator_recipe = {
	        {"default:steel_ingot", "default:glass", "default:steel_ingot", },
		{"default:steel_ingot", "",              "default:steel_ingot", },
		{"default:steel_ingot", "default:glass", "default:steel_ingot", }
}
travelnet.tiles_travelnet = {
		"travelnet_travelnet_front.png",  -- backward view
		"travelnet_travelnet_back.png", -- front view
		"travelnet_travelnet_side.png", -- sides :)
		"default_steel_block.png",  -- view from top
		"default_clay.png",  -- view from bottom
		}
travelnet.tiles_elevator = {
		"travelnet_elevator_front.png",
		"travelnet_elevator_inside_controls.png",
		"travelnet_elevator_sides_outside.png",
		"travelnet_elevator_inside_ceiling.png",
		"travelnet_elevator_inside_floor.png",
		"default_steel_block.png"
		}
travelnet.travelnet_inventory_image = "travelnet_inv.png"
travelnet.elevator_inventory_image  = "travelnet_elevator_inv.png"

if( minetest.registered_nodes["mcl_core:wood"]) then
	local w_texture = "default_wood.png^[transformR90"; -- "mcl_doors_door_spruce_lower.png";
	travelnet.travelnet_recipe = {
                {"mcl_stairs:slab_wood", "mcl_stairs:slab_wood", "mcl_stairs:slab_wood",},
		{"mesecons_torch:mesecon_torch_on", "mcl_chests:chest", "mesecons_torch:mesecon_torch_on"},
		{"mesecons_torch:mesecon_torch_on", "mcl_chests:chest", "mesecons_torch:mesecon_torch_on"},
--		  {"core:glass", "mcl_core:iron_ingot",           "mcl_core:glass", },
--                {"mcl_core:glass", "mesecons_torch:redstoneblock", "mcl_core:glass", },
--                {"mcl_core:glass", "mcl_core:iron_ingot",           "mcl_core:glass", }
	}
	travelnet.elevator_recipe = {
                {"mcl_stairs:slab_wood", "mcl_stairs:slab_wood", "mcl_stairs:slab_wood",},
		{"mesecons_torch:mesecon_torch_on", "", "mesecons_torch:mesecon_torch_on"},
		{"mesecons_torch:mesecon_torch_on", "", "mesecons_torch:mesecon_torch_on"},
--	        {"mcl_core:iron_ingot", "mcl_core:glass", "mcl_core:iron_ingot", },
--		{"mcl_core:iron_ingot", "",               "mcl_core:iron_ingot", },
--		{"mcl_core:iron_ingot", "mcl_core:glass", "mcl_core:iron_ingot", }
	}
	travelnet.tiles_travelnet = {
		w_texture,  -- backward view
		w_texture, -- front view
		w_texture, -- sides :)
		w_texture,  -- view from top
		w_texture,  -- view from bottom
	}
	travelnet.tiles_elevator = {
		"mcl_core_planks_big_oak.png^[transformR90", -- front
		"mcl_core_planks_big_oak.png^[transformR90", -- inside
		"mcl_core_planks_big_oak.png^[transformR90", -- sides outside
		"mcl_core_planks_big_oak.png^[transformR90", -- inside ceiling
		"mcl_core_planks_big_oak.png^[transformR90", -- inside floor
		"mcl_core_planks_big_oak.png^[transformR90", -- top
		}
	travelnet.travelnet_inventory_image = nil
	travelnet.elevator_inventory_image  = nil
end

-- if this function returns true, the player with the name player_name is
-- allowed to add a box to the network named network_name, which is owned
-- by the player owner_name;
-- if you want to allow *everybody* to attach stations to all nets, let the
-- function always return true;
-- if the function returns false, players with the travelnet_attach priv
-- can still add stations to that network 

travelnet.allow_attach = function( player_name, owner_name, network_name )
   return false;
end


-- if this returns true, a player named player_name can remove a travelnet station
-- from network_name (owned by owner_name) even though he is neither the owner nor
-- has the travelnet_remove priv
travelnet.allow_dig    = function( player_name, owner_name, network_name )
   return false;
end


-- if this function returns false, then player player_name will not be allowed to use
-- the travelnet station_name_start on networ network_name owned by owner_name to travel to
-- the station station_name_target on the same network;
-- if this function returns true, the player will be transfered to the target station;
-- you can use this code to i.e. charge the player money for the transfer or to limit
-- usage of stations to players in the same fraction on PvP servers
travelnet.allow_travel = function( player_name, owner_name, network_name, station_name_start, station_name_target )

   --minetest.chat_send_player( player_name, "Player "..tostring( player_name ).." tries to use station "..tostring( station_name_start )..
   --    " on network "..tostring( network_name ).." owned by "..tostring( owner_name ).." in order to travel to "..
   --    tostring( station_name_target )..".");

   return true;
end

travelnet.travelnet_sound_enabled = true
