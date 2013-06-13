
minetest.register_node("travelnet:elevator", {
    description = "Travelnet Elevator Bottom",

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

                { 0.48, -0.5,-0.5,  0.5,  0.5, 0.5},
                {-0.5 , -0.5, 0.48, 0.48, 0.5, 0.5}, 
                {-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},

                --groundplate to stand on
                { -0.5,-0.5,-0.5,0.5,-0.48, 0.5}, 
            },
    },
    

    tiles = {
          
             "travelnet_elevator_inside_floor.png",  -- view from top
             "default_stone.png",  -- view from bottom
	     "travelnet_elevator_inside_bottom.png", -- left side
	     "travelnet_elevator_inside_bottom.png", -- right side
	     "travelnet_elevator_inside_bottom.png",   -- front view
	     "travelnet_elevator_inside_bottom.png",  -- backward view
             },
    inventory_image = "travelnet_inv.png",

    groups = {cracky=1,choppy=1,snappy=1},


    light_source = 10,

    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.env:get_meta(pos);
        meta:set_string("infotext",       "Travelnet Elevator (unconfigured)");
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
       local p = {x=pos.x, y=pos.y+1, z=pos.z}
       local p2 = minetest.dir_to_facedir(placer:get_look_dir())
       minetest.env:add_node(p, {name="travelnet:elevator_top", paramtype2="facedir", param2=p2})
       return minetest.item_place(itemstack, placer, pointed_thing);
    end,

    on_destruct = function(pos)
            local p = {x=pos.x, y=pos.y+1, z=pos.z}
	    minetest.env:remove_node(p)
    end
})

minetest.register_node("travelnet:elevator_top", {
    description = "Travelnet Elevator Top",

    drawtype = "nodebox",
    sunlight_propagates = true,
    paramtype = 'light',
    paramtype2 = "facedir",

    selection_box = {
                type = "fixed",
                fixed = { 0, 0, 0,  0, 0, 0 }
--                fixed = { -0.5, -0.5, -0.5,  0.5, 0.5, 0.5 }
    },

    node_box = {
	    type = "fixed",
	    fixed = {

                { 0.48, -0.5,-0.5,  0.5,  0.5, 0.5},
                {-0.5 , -0.5, 0.48, 0.48, 0.5, 0.5}, 
                {-0.5,  -0.5,-0.5 ,-0.48, 0.5, 0.5},

                --top ceiling
                { -0.5, 0.48,-0.5,0.5, 0.5, 0.5}, 
            },
    },
    

    tiles = {
          
             "default_stone.png",  -- view from top
             "travelnet_elevator_inside_ceiling.png",  -- view from bottom
	     "travelnet_elevator_inside_top_control.png", -- left side
	     "travelnet_elevator_inside_top.png", -- right side
	     "travelnet_elevator_inside_top.png",   -- front view
	     "travelnet_elevator_inside_top.png",  -- backward view
             },
    inventory_image = "travelnet_inv.png",

    light_source = 10,

    groups = {cracky=1,choppy=1,snappy=1},
})

if( minetest.get_modpath("technic") ~= nil ) then
        minetest.register_craft({
                output = "travelnet:elevator",
		recipe = {
                        {"default:steel_ingot", "technic:motor", "default:steel_ingot", },
                	{"default:steel_ingot", "technic:control_logic_unit", "default:steel_ingot", },
                	{"default:steel_ingot", "moreores:copper_ingot", "default:steel_ingot", }
                }
        })
else
	minetest.register_craft({
	        output = "travelnet:elevator",
	        recipe = {
		        {"default:steel_ingot", "default_sandstone", "default:steel_ingot", },
			{"default:steel_ingot", "default_sandstone", "default:steel_ingot", },
			{"default:mese_crystal_fragment", "default:mese_crystal_fragment", "default:mese_crystal_fragment", }
		        }
	})
end


minetest.register_node("travelnet:elevator_door_steel_open", {
		description = "elevator door (open)",
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = {"default_stone.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
                -- larger than one node but slightly smaller than a half node so that wallmounted torches pose no problem
		node_box = {
			type = "fixed",
			fixed = {
				{-0.90, -0.5,  0.4, -0.49, 1.5,  0.5},
				{ 0.49, -0.5,  0.4,  0.9, 1.5,  0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.9, -0.5,  0.4,  0.9, 1.5,  0.5},
			},
		},
		drop = "travelnet:elevator_door_steel_closed",
                on_rightclick = function(pos, node, puncher)
                    minetest.env:add_node(pos, {name = "travelnet:elevator_door_steel_closed", param2 = node.param2})
                end,
})

minetest.register_node("travelnet:elevator_door_steel_closed", {
		description = "elevator door (closed)",
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = {"default_stone.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5,  -0.5,  0.4, -0.01, 1.5,  0.5},
				{ 0.01, -0.5,  0.4,  0.5,  1.5,  0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5,  0.4,  0.5, 1.5,  0.5},
			},
		},
                on_rightclick = function(pos, node, puncher)
                    minetest.env:add_node(pos, {name = "travelnet:elevator_door_steel_open", param2 = node.param2})
                end,
})




minetest.register_node("travelnet:elevator_door_glass_open", {
		description = "elevator door (open)",
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = {"travelnet_elevator_door_glass.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
                -- larger than one node but slightly smaller than a half node so that wallmounted torches pose no problem
		node_box = {
			type = "fixed",
			fixed = {
				{-0.99, -0.5,  0.4, -0.49, 1.5,  0.5},
				{ 0.49, -0.5,  0.4,  0.99, 1.5,  0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.9, -0.5,  0.4,  0.9, 1.5,  0.5},
			},
		},
		drop = "travelnet:elevator_door_glass_closed",
                on_rightclick = function(pos, node, puncher)
                    minetest.env:add_node(pos, {name = "travelnet:elevator_door_glass_closed", param2 = node.param2})
                end,
})

minetest.register_node("travelnet:elevator_door_glass_closed", {
		description = "elevator door (closed)",
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = {"travelnet_elevator_door_glass.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5,  -0.5,  0.4, -0.01, 1.5,  0.5},
				{ 0.01, -0.5,  0.4,  0.5,  1.5,  0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5,  0.4,  0.5, 1.5,  0.5},
			},
		},
                on_rightclick = function(pos, node, puncher)
                    minetest.env:add_node(pos, {name = "travelnet:elevator_door_glass_open", param2 = node.param2})
                end,
})


--      local old_node = minetest.env:get_node( pos );
--      minetest.env:add_node(pos, {name = "travelnet:elevator_door_glass_closed", param2 = old_node.param2})



