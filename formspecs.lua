local S = minetest.get_translator("travelnet")

local travelnet_form_name = "travelnet:show"

-- minetest.chat_send_player is sometimes not so well visible
function travelnet.show_message(pos, player_name, title, message)
	if not pos or not player_name or not message then
		return
	end
	local formspec = ([[
			size[8,3]
			label[3,0;%s]
			textlist[0,0.5;8,1.5;;%s;]
			button_exit[3.5,2.5;1.0,0.5;back;%s]
			button_exit[6.8,2.5;1.0,0.5;station_exit;%s]
			field[20,20;0.1,0.1;pos2str;Pos;%s]
		]]):format(
			minetest.formspec_escape(title or S("Error")),
			minetest.formspec_escape(message or "- nothing -"),
			S("Back"),
			S("Exit"),
			minetest.pos_to_string(pos)
		)
	minetest.show_formspec(player_name, travelnet_form_name, formspec)
end

-- show the player the formspec they would see when right-clicking the node;
-- needs to be simulated this way as calling on_rightclick would not do
function travelnet.show_current_formspec(pos, meta, player_name)
	if not pos or not meta or not player_name then
		return
	end
	-- we need to supply the position of the travelnet box
	local formspec = meta:get_string("formspec") ..
		("field[20,20;0.1,0.1;pos2str;Pos;%s]"):format(minetest.pos_to_string(pos))
	-- show the formspec manually
	minetest.show_formspec(player_name, travelnet_form_name, formspec)
end

-- a player clicked on something in the formspec hse was manually shown
-- (back from help page, moved travelnet up or down etc.)
function travelnet.form_input_handler(player, formname, fields)
	if formname ~= travelnet_form_name then return end
	if fields and fields.pos2str then
		local pos = minetest.string_to_pos(fields.pos2str)
		if not pos then
			return
		end

		-- back button leads back to the main menu
		if fields.back and fields.back ~= "" then
			return travelnet.show_current_formspec(pos,
					minetest.get_meta(pos), player:get_player_name())
		end
		return travelnet.on_receive_fields(pos, formname, fields, player)
	end
end

-- most formspecs the travelnet uses are stored in the travelnet node itself,
-- but some may require some "back"-button functionality (i.e. help page,
-- move up/down etc.)
minetest.register_on_player_receive_fields(travelnet.form_input_handler)


function travelnet.reset_formspec(meta)
	if not meta then return end

	meta:set_string("infotext",       S("Travelnet-box (unconfigured)"))
	meta:set_string("station_name",   "")
	meta:set_string("station_network","")
	meta:set_string("owner",          "")

	-- some players seem to be confused with entering network names at first; provide them
	-- with a default name
	local default_network = "net1"

	-- request initinal data
	meta:set_string("formspec",
			([[
				size[10,6.0]
				label[2.0,0.0;--> %s <--]
				button_exit[8.0,0.0;2.2,0.7;station_dig;%s]
				field[0.3,1.2;9,0.9;station_name;%s:;]
				label[0.3,1.5;%s]
				field[0.3,2.8;9,0.9;station_network;%s;%s]
				label[0.3,3.1;%s]
				field[0.3,4.4;9,0.9;owner;%s;]
				label[0.3,4.7;%s]
				button_exit[3.8,5.3;1.7,0.7;station_set;%s]
				button_exit[6.3,5.3;1.7,0.7;station_exit;%s]
			]]):format(
				S("Configure this travelnet station"),
				S("Remove station"),
				S("Name of this station"),
				S("How do you call this place here? Example: \"my first house\", \"mine\", \"shop\"..."),
				S("Assign to Network:"),
				default_network,
				S("You can have more than one network. If unsure, use \"@1\".", default_network),
				S("Owned by:"),
				S("Unless you know what you are doing, leave this empty."),
				S("Save"),
				S("Exit")
			)
	)
end


function travelnet.edit_formspec(pos, meta, player_name)
	if not pos or not meta or not player_name then
		return
	end

	local owner = meta:get_string("owner")
	-- TODO: check if player is owner or has privs
	local station_name = meta:get_string("station_name")
	local station_network = meta:get_string("station_network")
	local default_network = "net1"

	-- request changed data
	local formspec = ([[
		size[10,6.0]
		label[2.0,0.0;--> %s <--]
		button_exit[8.0,0.0;2.2,0.7;station_dig;%s]
		field[0.3,1.2;9,0.9;station_name;%s:;%s]
		label[0.3,1.5;%s]
		field[0.3,2.8;9,0.9;station_network;%s;%s]
		label[0.3,3.1;%s]
		field[0.3,4.4;9,0.9;owner;%s;%s]
		label[0.3,4.7;%s]
		button_exit[3.8,5.3;1.7,0.7;station_set;%s]
		button_exit[6.3,5.3;1.7,0.7;station_exit;%s]
		field[20,20;0.1,0.1;pos2str;Pos;%s]
	]]):format(
		S("Configure this travelnet station"),
		S("Remove station"),
		S("Name of this station"),
		station_name,
		S("How do you call this place here? Example: \"my first house\", \"mine\", \"shop\"..."),
		S("Assign to Network:"),
		station_network,
		S("You can have more than one network. If unsure, use \"@1\".", default_network),
		S("Owned by:"),
		owner,
		S("Unless you know what you are doing, leave this empty."),
		S("Save"),
		S("Exit"),
		minetest.pos_to_string(pos)
	)

	-- show the formspec manually
	minetest.show_formspec(player_name, travelnet_form_name, formspec)
end

