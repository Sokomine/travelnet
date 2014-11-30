-- Doors that are especially useful for travelnet elevators but can also be used in other situations.
-- All doors (not only these here) in front of a travelnet or elevator are opened automaticly when a player arrives
-- and are closed when a player departs from the travelnet or elevator.
-- Autor: Sokomine

minetest.register_node("travelnet:elevator_door_steel_open", {
		description = "elevator door (open)",
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = {"default_stone.png"},
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,not_in_creative_inventory=1},
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
                    minetest.add_node(pos, {name = "travelnet:elevator_door_steel_closed", param2 = node.param2})
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
                    minetest.add_node(pos, {name = "travelnet:elevator_door_steel_open", param2 = node.param2})
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
		groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,not_in_creative_inventory=1},
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
                    minetest.add_node(pos, {name = "travelnet:elevator_door_glass_closed", param2 = node.param2})
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
                    minetest.add_node(pos, {name = "travelnet:elevator_door_glass_open", param2 = node.param2})
                end,
})

minetest.register_craft({
	        output = "travelnet:elevator_door_glass_closed",
	        recipe = {
		        {"default:glass", "", "default:glass", },
			{"default:glass", "", "default:glass", },
			{"default:glass", "", "default:glass", }
		        }
	})

minetest.register_craft({
	        output = "travelnet:elevator_door_steel_closed",
	        recipe = {
		        {"default:steel_ingot", "", "default:steel_ingot", },
			{"default:steel_ingot", "", "default:steel_ingot", },
			{"default:steel_ingot", "", "default:steel_ingot", }
		        }
	})
--      local old_node = minetest.get_node( pos );
--      minetest.add_node(pos, {name = "travelnet:elevator_door_glass_closed", param2 = old_node.param2})



