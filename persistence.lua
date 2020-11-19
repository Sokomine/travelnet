local S = minetest.get_translator("travelnet")

local mod_data_path = minetest.get_worldpath().."/mod_travelnet.data"

-- called whenever a station is added or removed
travelnet.save_data = function()

   local data = minetest.serialize( travelnet.targets );

   local success = minetest.safe_file_write( mod_data_path, data );
   if( not success ) then
      print(S("[Mod travelnet] Error: Savefile '@1' could not be written.", mod_data_path));
   end
end


travelnet.restore_data = function()

   local file = io.open( mod_data_path, "r" );
   if( not file ) then
      print(S("[Mod travelnet] Error: Savefile '@1' not found.", mod_data_path));
      return;
   end

   local data = file:read("*all");
   travelnet.targets = minetest.deserialize( data );

   if( not travelnet.targets ) then
       local backup_file = mod_data_path..".bak"
       print(S("[Mod travelnet] Error: Savefile '@1' is damaged." .. " " ..
       "Saved the backup as '@2'.", mod_data_path, backup_file));

       minetest.safe_file_write( backup_file, data );
       travelnet.targets = {};
   end
   file:close();
end
