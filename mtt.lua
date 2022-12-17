-- simple smoketests and node registration verifications

mtt.emerge_area({x=0,y=0,z=0}, {x=32,y=32,z=32})

mtt.validate_nodenames(minetest.get_modpath("travelnet") .. "/test/nodenames.txt")

mtt.check_recipes("travelnet")
