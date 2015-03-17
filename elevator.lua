-- This version of the travelnet box allows to move up or down only.
-- The network name is determined automaticly from the position (x/z coordinates).
-- Autor: Sokomine


local function punch_elevator(pos, node, puncher, pt)
	if not (pos and node and puncher and pt) then
		return
	end
	local pname = puncher:get_player_name()
	if not travelnet.update_formspec(pos, pname) then
		return
	end

	-- abort if the elevator is punched not on the frontside
	if minetest.dir_to_facedir(vector.subtract(pt.under, pt.above)) ~= node.param2 then
		return
	end
	local dir = puncher:get_look_dir()
	local dist = vector.new(dir)

	local plpos = puncher:getpos()
	plpos.y = plpos.y+1.625

	--if math.abs(pos.x-plpos.x) > 0.5

	local a,b,c,mpa,mpc
	b = "y"
	if node.param2 == 0 then
		a = "x"
		c = "z"
	elseif node.param2 == 1 then
		a = "z"
		c = "x"
		mpa = -1
	elseif node.param2 == 2 then
		a = "x"
		c = "z"
		mpc = -1
		mpa = -1
	elseif node.param2 == 3 then
		a = "z"
		c = "x"
		mpc = -1
	else
		return
	end

	mpa = mpa or 1
	mpc = mpc or 1
	local shpos = {[a]=pos[a], [b]=pos[b], [c]=pos[c]+0.48*mpc}

	dist[c] = shpos[c]-plpos[c]
	local m = dist[c]/dir[c]
	dist[a] = dist[a]*m
	dist[b] = dist[b]*m
	local tp = vector.subtract(vector.add(plpos, dist), shpos)
	tp[a] = tp[a]*mpa

	if tp[b] < 9/16
	or tp[b] > 11/16
	or tp[a] < -6/16
	or tp[a] > 1/16 then
		return
	end

	local direction
	if tp[a] > -2/16 then
		direction = "down"
	elseif tp[a] < -3/16 then
		direction = "up"
	else
		return
	end

	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")
	local network = meta:get_string("station_network")
	local targets = travelnet.targets[owner][network]
	local my,station,mistake
	if direction == "up" then
		-- search the next etage upwards
		for name,data in pairs(targets) do
			local y = data.pos.y
			if y > pos.y then
				if not my
				or my > y then
					my = y
					station = name
				end
			end
		end
		mistake = "highest"
	else
		-- search the next etage downwards
		for name,data in pairs(targets) do
			local y = data.pos.y
			if y < pos.y then
				if not my
				or my < y then
					my = y
					station = name
				end
			end
		end
		mistake = "lowest"
	end
	if not my then
		-- abort if no requested etage was found
		minetest.chat_send_player(pname, "you're already in the "..mistake.." etage")
		return
	end

	-- call the travelnet teleportation function
	local fields = {
		owner_name = owner,
		target = station,
		station_network = network,
		station_name = meta:get_string("station_name"),
	}
	travelnet.on_receive_fields(pos, _, fields, puncher)

	-- information for the player
	minetest.chat_send_player(pname, "you're now at "..station)
end


minetest.register_node("travelnet:elevator", {
    description = "Elevator",

    drawtype = "nodebox",
    sunlight_propagates = true,
    paramtype = 'light',
    paramtype2 = "facedir",

    selection_box = {
                type = "fixed",
                fixed = {
			-- walls
			{ 0.48, -0.5,-0.5,  0.5,  1.5, 0.5},
			{-0.5 , -0.5, 0.48, 0.48, 1.5, 0.5}, 
			{-0.5,  -0.5,-0.5 ,-0.48, 1.5, 0.5},

			-- ground and roof plates
			{ -0.5,-0.5,-0.5,0.5,-0.48, 0.5}, 
			{ -0.5, 1.48,-0.5,0.5, 1.5, 0.5}, 
		}
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
    inventory_image = "travelnet_elevator_inv.png",
    wield_image     = "travelnet_elevator_wield.png",

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
    on_punch = punch_elevator,

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

minetest.register_node("travelnet:elevator_top", {
    description = "Elevator Top",

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
	     "travelnet_elevator_inside_top.png^travelnet_elevator_arrows.png",  -- backward view
             },
    inventory_image = "travelnet_elevator_inv.png",
    wield_image     = "travelnet_elevator_wield.png",

    light_source = 10,

    groups = {cracky=1,choppy=1,snappy=1,not_in_creative_inventory=1},
})

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

