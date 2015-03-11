-- contains the node definition for a general travelnet that can be used by anyone
--   further travelnets can only be installed by the owner or by people with the travelnet_attach priv
--   digging of such a travelnet is limited to the owner and to people with the travelnet_remove priv (useful for admins to clean up)
-- (this can be overrided in config.lua)
-- Autor: Sokomine
minetest.register_node("travelnet:travelnet", {

    description = "Travelnet box",

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
    

    tiles = {
          
             "default_clay.png",  -- view from top
             "default_clay.png",  -- view from bottom
             "travelnet_travelnet_side.png", -- left side
             "travelnet_travelnet_side.png", -- right side
             "travelnet_travelnet_back.png", -- front view
             "travelnet_travelnet_front.png",  -- backward view
             },
    inventory_image = "travelnet_inv.png",

    groups = {cracky=1,choppy=1,snappy=1},

    light_source = 10,

    after_place_node  = function(pos, placer, itemstack)
	local meta = minetest.get_meta(pos);
        meta:set_string("infotext",       "Travelnet-box (unconfigured)");
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

    can_dig = function( pos, player )
                          return travelnet.can_dig( pos, player, 'travelnet box' )
    end,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
			  travelnet.remove_box( pos, oldnode, oldmetadata, digger )
    end,

    -- taken from VanessaEs homedecor fridge
    on_place = function(itemstack, placer, pointed_thing)

       local pos = pointed_thing.above;
       if( minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air" ) then

          minetest.chat_send_player( placer:get_player_name(), 'Not enough vertical space to place the travelnet box!' )
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
