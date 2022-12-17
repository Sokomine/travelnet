local S = minetest.get_translator("travelnet")

local mod_data_path = minetest.get_worldpath() .. "/mod_travelnet.data"

-- called whenever a station is added or removed
function travelnet.save_data()
	local data = minetest.write_json(travelnet.targets)

	local success = minetest.safe_file_write(mod_data_path, data)
	if not success then
		print(S("[Mod travelnet] Error: Savefile '@1' could not be written.", mod_data_path))
	end
end


function travelnet.restore_data()
	local file = io.open(mod_data_path, "r")
	if not file then
		print(S("[Mod travelnet] Error: Savefile '@1' not found.", mod_data_path))
		return
	end

	local data = file:read("*all")
	if data:sub(1, 1) == "{" then
		travelnet.targets = minetest.parse_json(data)
	else
		travelnet.targets = minetest.deserialize(data)
	end

	if not travelnet.targets then
		local backup_file = mod_data_path .. ".bak"
		print(S("[Mod travelnet] Error: Savefile '@1' is damaged." .. " " ..
				"Saved the backup as '@2'.", mod_data_path, backup_file))

		minetest.safe_file_write(backup_file, data)
		travelnet.targets = {}
	end
	file:close()
end

-- getter/setter for the legacy `travelnet.targets` table
-- use those methods to access the per-player data, direct table access is deprecated
-- and will be removed in the future

-- returns the player's travelnets
function travelnet.get_travelnets(playername, create)
	if not travelnet.targets[playername] and create then
		-- create a new entry
		travelnet.targets[playername] = {}
	end
	return travelnet.targets[playername]
end

-- saves the player's modified travelnets
function travelnet.set_travelnets(playername, travelnets)
	travelnet.targets[playername] = travelnets
	travelnet.save_data(playername)
end