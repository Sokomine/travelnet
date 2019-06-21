-- contains the node definition for a general travelnet that can be used by anyone
--   further travelnets can only be installed by the owner or by people with the travelnet_attach priv
--   digging of such a travelnet is limited to the owner and to people with the travelnet_remove priv (useful for admins to clean up)
-- (this can be overrided in config.lua)
-- Author: Sokomine
local S = travelnet.S;

minetest.register_node("travelnet:travelnet", {

	description = S("Travelnet-Box"),

	drawtype = "mesh",
	mesh = "travelnet.obj",
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

	tiles = travelnet.tiles_travelnet,

	inventory_image = travelnet.travelnet_inventory_image,

	groups = {}, --cracky=1,choppy=1,snappy=1},

    light_source = 10,

    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.get_meta(pos);
	travelnet.reset_formspec( meta );
        meta:set_string("owner",          placer:get_player_name() );
    end,

    on_receive_fields = travelnet.on_receive_fields,
    on_punch          = function(pos, node, puncher)
                             travelnet.update_formspec(pos, puncher:get_player_name(), nil)
    end,

    can_dig = function( pos, player )
                          return travelnet.can_dig( pos, player, 'travelnet box' )
    end,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
			  travelnet.remove_box( pos, oldnode, oldmetadata, digger )
    end,

    -- TNT and overenthusiastic DMs do not destroy travelnets
    on_blast = function(pos, intensity)
    end,

    -- taken from VanessaEs homedecor fridge
    on_place = function(itemstack, placer, pointed_thing)

       local pos = pointed_thing.above;
       local def = minetest.registered_nodes[
             minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name]
       if not def or not def.buildable_to then

          minetest.chat_send_player( placer:get_player_name(), S('There is not enough vertical space to place the travelnet box!'))
          return;
       end
       return minetest.item_place(itemstack, placer, pointed_thing);
    end,

})

--[
minetest.register_craft({
        output = "travelnet:travelnet",
        recipe = travelnet.travelnet_recipe,
})
