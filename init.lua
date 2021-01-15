

--[[
    Teleporter networks that allow players to choose a destination out of a list
    Copyright (C) 2013 Sokomine

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

--]]

-- integration test
if minetest.settings:get_bool("travelnet.enable_travelnet_integration_test") then
   dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/integration_test.lua")
end

-- Required to save the travelnet data properly in all cases
if not minetest.safe_file_write then
	error("[Mod travelnet] Your Minetest version is no longer supported. (version < 0.4.17)")
end

travelnet = {};

travelnet.targets = {};
travelnet.path = minetest.get_modpath(minetest.get_current_modname())

-- privs
dofile(travelnet.path.."/privs.lua");

-- read the configuration
dofile(travelnet.path.."/config.lua");

-- saving / reading
dofile(travelnet.path.."/persistence.lua");

-- common functions
dofile(travelnet.path.."/functions.lua");

-- formspec stuff
dofile(travelnet.path.."/formspecs.lua");

-- travelnet / elevator update
dofile(travelnet.path.."/update_formspec.lua");

-- add button
dofile(travelnet.path.."/add_target.lua");

-- receive fields handler
dofile(travelnet.path.."/on_receive_fields.lua");

-- invisible node to place inside top of travelnet box and elevator
minetest.register_node("travelnet:hidden_top", {
	drawtype = "nodebox",
	paramtype = "light",
	sunlight_propagates = true,
	pointable = false,
	diggable = false,
	drop = "",
	groups = {not_in_creative_inventory = 1},
	tiles = {"travelnet_blank.png"},
	node_box = {
		type = "fixed",
		fixed = { -0.5, 0.45,-0.5,0.5, 0.5, 0.5},
	},
	collision_box = {
		type = "fixed",
		fixed = { -0.5, 0.45,-0.5,0.5, 0.5, 0.5},
	},
})


if( travelnet.travelnet_effect_enabled ) then
	minetest.register_entity( 'travelnet:effect', {
		hp_max = 1,
		physical = false,
		weight = 5,
		collisionbox = {-0.4,-0.5,-0.4, 0.4,1.5,0.4},
		visual = "upright_sprite",
		visual_size = {x=1, y=2},
		textures = { "travelnet_flash.png" }, -- number of required textures depends on visual
		spritediv = {x=1, y=1},
		initial_sprite_basepos = {x=0, y=0},
		is_visible = true,
		makes_footstep_sound = false,
		automatic_rotate = true,

		anz_rotations = 0,

		on_step = function(self)
			-- this is supposed to be more flickering than smooth animation
			self.object:set_yaw( self.object:get_yaw()+1);
			self.anz_rotations = self.anz_rotations + 1;
			-- eventually self-destruct
			if self.anz_rotations > 15 then
				self.object:remove();
			end
		end
	})
end


if( travelnet.travelnet_enabled ) then
	-- register-functions for travelnet nodes
	dofile(travelnet.path.."/register_travelnet.lua");
	-- default travelnet registrations
	dofile(travelnet.path.."/travelnet.lua");
end
if( travelnet.elevator_enabled ) then
	dofile(travelnet.path.."/elevator.lua");  -- allows up/down transfers only
end
if( travelnet.doors_enabled ) then
	-- doors that open and close automaticly when the travelnet or elevator is used
	dofile(travelnet.path.."/doors.lua");
end

if( travelnet.enable_abm ) then
	-- restore travelnet data when players pass by broken networks
	dofile(travelnet.path.."/restore_network_via_abm.lua");
end

-- upon server start, read the savefile
travelnet.restore_data();
