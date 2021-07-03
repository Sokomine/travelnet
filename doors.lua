-- Doors that are especially useful for travelnet elevators but can also be used in other situations.
-- All doors (not only these here) in front of a travelnet or elevator are opened automaticly when a player arrives
-- and are closed when a player departs from the travelnet or elevator.
-- Autor: Sokomine
local S = minetest.get_translator("travelnet")

function travelnet.register_door(node_base_name, def_tiles, material)
	local closed_door = node_base_name .. "_closed"
	local open_door = node_base_name .. "_open"

	minetest.register_node(open_door, {
		description = S("elevator door (open)"),
		drawtype = "nodebox",
		tiles = def_tiles,
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		-- only the closed variant is in creative inventory
		groups = {
			snappy = 2,
			choppy = 2,
			oddly_breakable_by_hand = 2,
			not_in_creative_inventory = 1
		},
		-- larger than one node but slightly smaller than a half node so
		-- that wallmounted torches pose no problem
		node_box = {
			type = "fixed",
			fixed = {
				{ -0.90, -0.5, 0.4, -0.49, 1.5, 0.5 },
				{  0.49, -0.5, 0.4,   0.9, 1.5, 0.5 },
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{ -0.9, -0.5, 0.4, 0.9, 1.5, 0.5 },
			},
		},
		drop = closed_door,
		on_rightclick = function(pos, node)
			minetest.add_node(pos, {
				name = closed_door,
				param2 = node.param2
			})
		end,
	})

	minetest.register_node(closed_door, {
		description = S("elevator door (closed)"),
		drawtype = "nodebox",
		tiles = def_tiles,
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = {
			snappy = 2,
			choppy = 2,
			oddly_breakable_by_hand = 2
		},
		node_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, 0.4, -0.01, 1.5, 0.5 },
				{ 0.01, -0.5, 0.4,   0.5, 1.5, 0.5 },
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, 0.4, 0.5, 1.5, 0.5 },
			},
		},
		on_rightclick = function(pos, node)
			minetest.add_node(pos, {
				name = open_door,
				param2 = node.param2
			})
		end,
	})

	-- add a craft receipe for the door
	minetest.register_craft({
		output = closed_door,
		recipe = {
			{ material, "", material },
			{ material, "", material },
			{ material, "", material }
		}
	})


	-- Make doors reacts to mesecons
	if minetest.get_modpath("mesecons") then
		local mesecons = {
			effector = {
				action_on = function(pos, node)
					minetest.add_node(pos, {
						name = open_door,
						param2 = node.param2
					})
				end,
				action_off = function(pos, node)
					minetest.add_node(pos, {
						name = closed_door,
						param2 = node.param2
					})
				end,
				rules = mesecon.rules.pplate
			}
		}

		minetest.override_item(closed_door, { mesecons=mesecons })
		minetest.override_item(open_door,   { mesecons=mesecons })
	end
end

-- actually register the doors
-- (but only if the materials for them exist)
if minetest.get_modpath("default") then
	travelnet.register_door("travelnet:elevator_door_steel", { "default_stone.png" },           "default:steel_ingot")
	travelnet.register_door("travelnet:elevator_door_glass", { "travelnet_elevator_door_glass.png" }, "default:glass")
	travelnet.register_door("travelnet:elevator_door_tin",   { "default_clay.png" },              "default:tin_ingot")
end
