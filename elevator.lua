-- This version of the travelnet box allows to move up or down only.
-- The network name is determined automaticly from the position (x/z coordinates).
-- >utor: Sokomine

minetest.register_node("travelnet:elevator", {
	description = "Elevator",
	drawtype = "mesh",
	mesh = "travelnet_elevator.obj",
	sunlight_propagates = true,
	paramtype = 'light',
	paramtype2 = "facedir",
	wield_scale = {x=0.6, y=0.6, z=0.6},

	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
	},

	collision_box = {
		type = "fixed",
		fixed = {

			{ 0.48, -0.5,-0.5,  0.5,  0.5, 0.5},
			{-0.5 , -0.5, 0.48, 0.48, 0.5, 0.5}, 
			{-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},

			--groundplate to stand on
			{ -0.5,-0.5,-0.5,0.5,-0.48, 0.5}, 
		},
	},

	tiles = {
		"travelnet_elevator_front.png",
		"travelnet_elevator_inside_controls.png",
		"travelnet_elevator_sides_outside.png",
		"travelnet_elevator_inside_ceiling.png",
		"travelnet_elevator_inside_floor.png",
		"default_steel_block.png"
	},
	inventory_image = "travelnet_elevator_inv.png",
	groups = {cracky=1,choppy=1,snappy=1},

    light_source = 10,

    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.get_meta(pos);
        meta:set_string("infotext",       "Elevator (unconfigured)");
        meta:set_string("station_name",   "");
        meta:set_string("station_network","");
        meta:set_string("owner",          placer:get_player_name() );
        -- request initinal data
        meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,5.6;6,0.7;station_name;Name of this station:;]"..
--                            "field[0.3,6.6;6,0.7;station_network;Assign to Network:;]"..
--                            "field[0.3,7.6;6,0.7;owner_name;(optional) owned by:;]"..
                            "button_exit[6.3,6.2;1.7,0.7;station_set;Store]" );

       local p = {x=pos.x, y=pos.y+1, z=pos.z}
       local p2 = minetest.dir_to_facedir(placer:get_look_dir())
       minetest.add_node(p, {name="travelnet:elevator_top", paramtype2="facedir", param2=p2})
    end,
    
    on_receive_fields = travelnet.on_receive_fields,
    on_punch          = function(pos, node, puncher)
                          travelnet.update_formspec(pos, puncher:get_player_name())
    end,

    can_dig = function( pos, player )
                          return travelnet.can_dig( pos, player, 'elevator' )
    end,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
			  travelnet.remove_box( pos, oldnode, oldmetadata, digger )
    end,

    -- taken from VanessaEs homedecor fridge
    on_place = function(itemstack, placer, pointed_thing)
       local pos  = pointed_thing.above;
       local node = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z});
       -- leftover elevator_top nodes can be removed by placing a new elevator underneath
       if( node ~= nil and node.name ~= "air" and node.name ~= 'travelnet:elevator_top') then
          minetest.chat_send_player( placer:get_player_name(), 'Not enough vertical space to place the travelnet box!' )
          return;
       end
       return minetest.item_place(itemstack, placer, pointed_thing);
    end,

    on_destruct = function(pos)
            local p = {x=pos.x, y=pos.y+1, z=pos.z}
	    minetest.remove_node(p)
    end
})

minetest.register_alias("travelnet:elevator_top", "air")

--if( minetest.get_modpath("technic") ~= nil ) then
--        minetest.register_craft({
--                output = "travelnet:elevator",
--		recipe = {
--                        {"default:steel_ingot", "technic:motor", "default:steel_ingot", },
--                	{"default:steel_ingot", "technic:control_logic_unit", "default:steel_ingot", },
--                	{"default:steel_ingot", "moreores:copper_ingot", "default:steel_ingot", }
--                }
--        })
--else
	minetest.register_craft({
	        output = "travelnet:elevator",
		recipe = travelnet.elevator_recipe,
	})
--end

