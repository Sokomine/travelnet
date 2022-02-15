local travelnet_form_name = "travelnet:show"

local player_formspec_data = travelnet.player_formspec_data

-- minetest.chat_send_player is sometimes not so well visible
function travelnet.show_message(pos, player_name, title, message)
	if not pos or not player_name or not message then
		return
	end
	local formspec = travelnet.formspecs.error_message({
		title = title,
		message = message
	})
	travelnet.show_formspec(player_name, formspec)
end

-- show the player the formspec they would see when right-clicking the node;
-- needs to be simulated this way as calling on_rightclick would not do
function travelnet.show_current_formspec(pos, meta, player_name)
	player_formspec_data[player_name] = player_formspec_data[player_name] or {}
	player_formspec_data[player_name].pos = pos
	local node = minetest.get_node(pos)
	travelnet.show_formspec(player_name,
		travelnet.formspecs.current({
			station_network = meta:get_string("station_network"),
			station_name = meta:get_string("station_name"),
			owner_name = meta:get_string("owner"),
			is_elevator = travelnet.is_elevator(node.name)
		}, player_name))
end

-- a player clicked on something in the formspec hse was manually shown
-- (back from help page, moved travelnet up or down etc.)
function travelnet.form_input_handler(player, formname, fields)
	if formname ~= travelnet_form_name then return end
	if not player then return end

	local name = player:get_player_name()
	player_formspec_data[name] = player_formspec_data[name] or {}
	local pos = player_formspec_data[name].pos

	return travelnet.on_receive_fields(pos, nil, fields, player)
end

-- most formspecs the travelnet uses are stored in the travelnet node itself,
-- but some may require some "back"-button functionality (i.e. help page,
-- move up/down etc.)
minetest.register_on_player_receive_fields(travelnet.form_input_handler)


function travelnet.reset_formspec()
	minetest.log("warning",
		"[travelnet] the travelnet.reset_formspec method is deprecated. "..
		"Run meta:set_string('station_network', '') to reset the travelnet.")
end


function travelnet.edit_formspec(pos, meta, player_name)
	if not pos or not meta or not player_name then
		return
	end

	local node = minetest.get_node_or_nil(pos)
	if not node then return end
	if travelnet.is_elevator(node.name) then
		return travelnet.edit_formspec_elevator(pos, meta, player_name)
	end

	-- request changed data
	local formspec = travelnet.formspecs.edit_travelnet({
		owner_name      = meta:get_string("owner"),
		station_network = meta:get_string("station_network"),
		station_name    = meta:get_string("station_name")
	}, player_name)

	-- show the formspec manually
	travelnet.show_formspec(player_name, formspec)
end


function travelnet.edit_formspec_elevator(pos, meta, player_name)
	if not pos or not meta or not player_name then
		return
	end

	-- request changed data
	local formspec = travelnet.formspecs.edit_elevator(
		{ station_name = meta:get_string("station_name") },
		player_name
	)

	-- show the formspec manually
	travelnet.show_formspec(player_name, formspec)
end

function travelnet.show_formspec(player_name, formspec)
	if formspec and formspec ~= "" then
		minetest.show_formspec(player_name, travelnet_form_name, formspec)
		return true
	else
		minetest.show_formspec(player_name, "", "")
		return false
	end
end
