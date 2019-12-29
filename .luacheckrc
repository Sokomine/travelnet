unused_args = false

globals = {
	"travelnet"
}

read_globals = {
	-- Stdlib
	string = {fields = {"split"}},
	table = {fields = {"copy", "getn"}},

	-- mod deps
	"technic_cnc", "technic",
	"loot", "mesecon", "skybox",
	"xp_redo",

	-- Minetest
	"minetest",
	"vector", "ItemStack",
	"dump", "screwdriver",

	-- Deps
	"default", "creative", "locks", "intllib"
}
