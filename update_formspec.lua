local player_formspec_data = travelnet.player_formspec_data

function travelnet.primary_formspec(pos, puncher_name, _)

	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local is_elevator = travelnet.is_elevator(node.name)

	if not meta then
		return
	end

	local owner_name      = meta:get_string("owner")
	local station_name    = meta:get_string("station_name")
	local station_network = meta:get_string("station_network")
	local props = {
		station_name = station_name,
		station_network = station_network,
		owner_name = owner_name,
		is_elevator = is_elevator
	}

	local success, result = travelnet.actions.repair_station({
		pos = pos,
		node = node,
		meta = meta,
		props = props,
	}, {}, minetest.get_player_by_name(puncher_name))

	if success then
		if result and result.formspec then
			if result.options then
				for k,v in pairs(result.options) do
					props[k] = v
				end
			end
			travelnet.show_formspec(puncher_name, result.formspec(props, puncher_name))
		else
			player_formspec_data[puncher_name] = nil
			travelnet.show_formspec(puncher_name, false)
		end
	else
		travelnet.show_formspec(puncher_name, travelnet.formspecs.error_message({ message = result }))
	end
end

function travelnet.update_formspec()
	minetest.log("warning",
		"[travelnet] the travelnet.update_formspec method is deprecated. "..
		"The formspec is now generated on each interaction.")
end
