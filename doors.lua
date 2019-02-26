-- Doors that are especially useful for travelnet elevators but can also be used in other situations.
-- All doors (not only these here) in front of a travelnet or elevator are opened automaticly when a player arrives
-- and are closed when a player departs from the travelnet or elevator.
-- Autor: Sokomine
local S = travelnet.S;

travelnet.register_door = function( node_base_name, def_tiles, material )

	minetest.register_node( node_base_name.."_open", {
		description = S("elevator door (open)"),
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = def_tiles,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		-- only the closed variant is in creative inventory
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
		drop = node_base_name.."_closed",
                on_rightclick = function(pos, node, puncher)
                    minetest.add_node(pos, {name = node_base_name.."_closed", param2 = node.param2})
                end,
	})

	minetest.register_node(node_base_name.."_closed", {
		description = S("elevator door (closed)"),
		drawtype = "nodebox",
                -- top, bottom, side1, side2, inner, outer
		tiles = def_tiles,
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
                    minetest.add_node(pos, {name = node_base_name.."_open", param2 = node.param2})
                end,
	})

	-- add a craft receipe for the door
	minetest.register_craft({
	        output = node_base_name.."_closed",
	        recipe = {
		        {material, '', material },
			{material, '', material },
			{material, '', material }
		        }
	})


	-- Make doors reacts to mesecons
	if minetest.get_modpath("mesecons") then
		local mesecons = {effector = {
			action_on = function(pos, node)
			minetest.add_node(pos, {name = node_base_name.."_open", param2 = node.param2})
		end,
		action_off = function(pos, node)
			minetest.add_node(pos, {name = node_base_name.."_closed", param2 = node.param2})
		end,
		rules = mesecon.rules.pplate
	}}

	minetest.override_item( node_base_name.."_closed", { mesecons = mesecons })
	minetest.override_item( node_base_name.."_open", { mesecons = mesecons })
   end
end

-- actually register the doors
-- (but only if the materials for them exist)
if( minetest.registered_nodes["default:glass"]) then
   travelnet.register_door( "travelnet:elevator_door_steel", {"default_stone.png"}, "default:steel_ingot");
   travelnet.register_door( "travelnet:elevator_door_glass", {"travelnet_elevator_door_glass.png"}, "default:glass");
   travelnet.register_door( "travelnet:elevator_door_tin", {"default_clay.png"}, "default:tin_ingot");
end
